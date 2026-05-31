import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/domain/repositories/media_thumbnail_loader.dart';
import 'package:ataulfo/features/media/domain/failures/media_failure.dart';
import 'package:ataulfo/features/media/presentation/bloc/media_gallery_bloc.dart';
import 'package:ataulfo/features/media/presentation/pages/media_gallery_page.dart';
import 'package:ataulfo/features/media/presentation/widgets/media_thumbnail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_thumbnail_loader.dart';

class _MockBloc extends MockBloc<MediaGalleryEvent, MediaGalleryState>
    implements MediaGalleryBloc {}

/// Loader que siempre resuelve los mismos bytes — para verificar que la página
/// threadea SU loader hasta las miniaturas (no para testear la lógica de cache,
/// que vive en caching_media_thumbnail_loader_test).
class _BytesLoader implements MediaThumbnailLoader {
  const _BytesLoader(this._bytes);
  final Uint8List _bytes;
  @override
  Future<Uint8List?> load(MediaAsset asset) async => _bytes;
}

// PNG 1x1 transparente válido.
final _png1x1 = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

MediaAsset _asset(
  String ref, {
  String? previewUrl,
  String contentType = 'image/png',
}) => MediaAsset(
  ref: ref,
  previewUrl: previewUrl,
  filename: '$ref.png',
  contentType: contentType,
  size: 10,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  setUpAll(() {
    registerFallbackValue(const MediaGalleryLoadRequested());
  });

  late _MockBloc bloc;

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.state).thenReturn(const MediaGalleryInitial());
  });

  Widget host({MediaThumbnailLoader loader = const FakeThumbnailLoader()}) =>
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: BlocProvider<MediaGalleryBloc>.value(
          value: bloc,
          child: Scaffold(body: MediaGalleryPage(loader: loader)),
        ),
      );

  testWidgets('Loading muestra spinner con AppTokens.primary', (tester) async {
    when(() => bloc.state).thenReturn(const MediaGalleryLoading());
    await tester.pumpWidget(host());
    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.valueColor?.value, AppTokens.primary);
  });

  testWidgets('Loaded con N assets renderiza N miniaturas', (tester) async {
    when(() => bloc.state).thenReturn(
      MediaGalleryLoaded(
        items: <MediaAsset>[
          _asset('media/a', previewUrl: 'https://signed/a'),
          _asset('media/b', previewUrl: 'https://signed/b'),
        ],
        nextCursor: '',
      ),
    );
    await tester.pumpWidget(host());
    expect(find.byType(MediaThumbnail), findsNWidgets(2));
  });

  testWidgets('Loaded vacío muestra empty state (sin miniaturas)', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const MediaGalleryLoaded(items: <MediaAsset>[], nextCursor: ''),
    );
    await tester.pumpWidget(host());
    expect(find.byType(MediaThumbnail), findsNothing);
    expect(find.byKey(const Key('media_gallery.empty')), findsOneWidget);
  });

  testWidgets('Failed → mensaje + Reintentar dispara LoadRequested', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const MediaGalleryFailed(MediaNetworkFailure()));
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('media_gallery.error')), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    await tester.pump();
    verify(() => bloc.add(const MediaGalleryLoadRequested())).called(1);
  });

  // Wiring página↔miniatura: la página debe pasar SU loader a cada miniatura.
  // El comportamiento fino del loader (hit/miss/descarga) vive en
  // caching_media_thumbnail_loader_test; aquí sólo se verifica el cableado.
  testWidgets('loader que resuelve null ⇒ la miniatura cae a placeholder', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      MediaGalleryLoaded(
        items: <MediaAsset>[_asset('media/a', previewUrl: null)],
        nextCursor: '',
      ),
    );
    await tester.pumpWidget(host()); // loader por defecto: null
    await tester.pump(); // asienta el FutureBuilder de la miniatura

    expect(find.byType(Image), findsNothing);
    expect(
      find.byKey(const Key('media_thumbnail.placeholder.media/a')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'la página threadea su loader: bytes ⇒ la miniatura pinta Image',
    (tester) async {
      when(() => bloc.state).thenReturn(
        MediaGalleryLoaded(
          items: <MediaAsset>[
            _asset('media/a', previewUrl: 'https://signed/a'),
          ],
          nextCursor: '',
        ),
      );
      await tester.pumpWidget(host(loader: _BytesLoader(_png1x1)));
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(
        find.byKey(const Key('media_thumbnail.placeholder.media/a')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'LINCHPIN: onSelect recibe el ref BARE del asset, NUNCA la previewUrl',
    (tester) async {
      // Invariante arc-wide: la galería usada como picker devuelve la
      // identidad estable (`ref` BARE), jamás la URL firmada efímera.
      // Un asset con ref != previewUrl prueba que el ref gana aun cuando
      // hay una previewUrl presente.
      when(() => bloc.state).thenReturn(
        MediaGalleryLoaded(
          items: <MediaAsset>[
            _asset('media/abc', previewUrl: 'https://signed/abc'),
          ],
          nextCursor: '',
        ),
      );

      String? captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: BlocProvider<MediaGalleryBloc>.value(
            value: bloc,
            child: Scaffold(
              body: MediaGalleryPage(
                loader: const FakeThumbnailLoader(),
                // onSelect recibe el MediaAsset completo; el consumidor extrae
                // el ref BARE (identidad), nunca la previewUrl efímera.
                onSelect: (asset) => captured = asset.ref,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(MediaThumbnail));
      await tester.pump();

      // Aserción positiva (null-failing): si el tap no llega a la closure,
      // captured queda null y esta línea falla.
      expect(captured, 'media/abc');
      // Y explícitamente NO la previewUrl firmada.
      expect(captured, isNot('https://signed/abc'));
    },
  );

  testWidgets('sin onSelect (visor) el tap a la miniatura no lanza', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      MediaGalleryLoaded(
        items: <MediaAsset>[
          _asset('media/abc', previewUrl: 'https://signed/abc'),
        ],
        nextCursor: '',
      ),
    );
    // host() construye MediaGalleryPage() con onSelect == null.
    await tester.pumpWidget(host());
    await tester.tap(find.byType(MediaThumbnail));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('FAB de subida dispara MediaGalleryUploadRequested', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const MediaGalleryLoaded(items: <MediaAsset>[], nextCursor: ''),
    );
    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('media_gallery.upload_fab')));
    await tester.pump();
    verify(() => bloc.add(const MediaGalleryUploadRequested())).called(1);
  });

  testWidgets(
    'hasMore + scroll al fondo dispara MediaGalleryLoadMoreRequested',
    (tester) async {
      final items = List<MediaAsset>.generate(
        20,
        (i) => _asset('media/$i', previewUrl: null),
      );
      when(
        () => bloc.state,
      ).thenReturn(MediaGalleryLoaded(items: items, nextCursor: 'cur-1'));
      await tester.pumpWidget(host());
      await tester.drag(find.byType(GridView), const Offset(0, -2000));
      await tester.pump();
      verify(() => bloc.add(const MediaGalleryLoadMoreRequested())).called(1);
    },
  );

  testWidgets('isLoadingMore muestra indicador de paginación', (tester) async {
    when(() => bloc.state).thenReturn(
      MediaGalleryLoaded(
        items: <MediaAsset>[_asset('media/a', previewUrl: null)],
        nextCursor: 'cur-1',
        isLoadingMore: true,
      ),
    );
    await tester.pumpWidget(host());
    expect(
      find.byKey(const Key('media_gallery.load_more_indicator')),
      findsOneWidget,
    );
  });

  testWidgets('uploadError emite snackbar sin tumbar la lista', (tester) async {
    // Estado previo sin error, luego transición a uploadError → snackbar.
    whenListen(
      bloc,
      Stream<MediaGalleryState>.fromIterable(<MediaGalleryState>[
        MediaGalleryLoaded(
          items: <MediaAsset>[_asset('media/a', previewUrl: null)],
          nextCursor: '',
          uploadError: const MediaTooLargeFailure(),
        ),
      ]),
      initialState: MediaGalleryLoaded(
        items: <MediaAsset>[_asset('media/a', previewUrl: null)],
        nextCursor: '',
      ),
    );
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    // La lista sigue visible (no colapsó a un estado de error terminal).
    expect(find.byType(MediaThumbnail), findsOneWidget);
  });
}
