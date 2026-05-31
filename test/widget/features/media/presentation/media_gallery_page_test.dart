import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/domain/failures/media_failure.dart';
import 'package:ataulfo/features/media/presentation/bloc/media_gallery_bloc.dart';
import 'package:ataulfo/features/media/presentation/pages/media_gallery_page.dart';
import 'package:ataulfo/features/media/presentation/widgets/media_thumbnail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<MediaGalleryEvent, MediaGalleryState>
    implements MediaGalleryBloc {}

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

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<MediaGalleryBloc>.value(
      value: bloc,
      child: const Scaffold(body: MediaGalleryPage()),
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

  testWidgets('asset con previewUrl null renderiza placeholder, no excepción', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      MediaGalleryLoaded(
        items: <MediaAsset>[_asset('media/a', previewUrl: null)],
        nextCursor: '',
      ),
    );
    await tester.pumpWidget(host());
    // No Image.network cuando no hay URL; sí un placeholder con ícono.
    expect(find.byType(Image), findsNothing);
    expect(
      find.byKey(const Key('media_thumbnail.placeholder.media/a')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('asset con previewUrl renderiza Image (no placeholder)', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      MediaGalleryLoaded(
        items: <MediaAsset>[_asset('media/a', previewUrl: 'https://signed/a')],
        nextCursor: '',
      ),
    );
    await tester.pumpWidget(host());
    // Image.network falla por defecto en widget tests; basta con que el nodo
    // Image exista (su errorBuilder cae al mismo placeholder, sin crash).
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
              body: MediaGalleryPage(onSelect: (ref) => captured = ref),
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
