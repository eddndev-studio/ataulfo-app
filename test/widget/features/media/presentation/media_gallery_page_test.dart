import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_choice_chip.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_empty_state.dart';
import 'package:ataulfo/core/design/widgets/app_error_state.dart';
import 'package:ataulfo/core/design/widgets/app_loading_indicator.dart';
import 'package:ataulfo/core/design/widgets/app_page_container.dart';
import 'package:ataulfo/core/design/widgets/app_search_field.dart';
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
    // El spinner de página es el primitivo canónico del kit.
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
  });

  testWidgets('el buscador usa el componente canónico con copy contextual', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const MediaGalleryLoaded(items: <MediaAsset>[], nextCursor: ''),
    );
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('media_gallery.search_field')), findsOneWidget);
    expect(find.byType(AppSearchField), findsOneWidget);
    final search = tester.widget<AppSearchField>(
      find.byKey(const Key('media_gallery.search_field')),
    );
    expect(search.hint, 'Buscar archivos por nombre…');
    expect(
      find.ancestor(
        of: find.byKey(const Key('media_gallery.search_field')),
        matching: find.byType(AppPrimaryPageContainer),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.search), findsOneWidget);
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

  testWidgets('el grid usa columnas responsivas (MaxCrossAxisExtent)', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      MediaGalleryLoaded(
        items: <MediaAsset>[_asset('media/a', previewUrl: 'https://signed/a')],
        nextCursor: '',
      ),
    );
    await tester.pumpWidget(host());

    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(
      grid.gridDelegate,
      isA<SliverGridDelegateWithMaxCrossAxisExtent>(),
      reason: 'columnas según ancho (desktop ancho ⇒ más columnas), no 3 fijas',
    );
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
    // La galería virgen usa el vacío rico canónico del kit (sin CTA: el FAB
    // de subida ya está en pantalla).
    expect(find.byType(AppEmptyState), findsOneWidget);
  });

  testWidgets('Failed → mensaje + Reintentar dispara LoadRequested', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const MediaGalleryFailed(MediaNetworkFailure()));
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('media_gallery.error')), findsOneWidget);
    // La card de error es el primitivo canónico del kit.
    expect(find.byType(AppErrorState), findsOneWidget);
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

  testWidgets('búsqueda: escribir despacha SearchChanged tras el debounce', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const MediaGalleryLoaded(items: <MediaAsset>[], nextCursor: ''),
    );
    await tester.pumpWidget(host());

    await tester.enterText(
      find.byKey(const Key('media_gallery.search_field')),
      'logo',
    );
    // Antes del debounce no se despacha.
    await tester.pump(const Duration(milliseconds: 100));
    verifyNever(() => bloc.add(const MediaGallerySearchChanged('logo')));
    // Tras el debounce, sí.
    await tester.pump(const Duration(milliseconds: 300));
    verify(() => bloc.add(const MediaGallerySearchChanged('logo'))).called(1);
  });

  testWidgets('búsqueda: limpiar despacha SearchChanged("") al instante', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const MediaGalleryLoaded(items: <MediaAsset>[], nextCursor: ''),
    );
    await tester.pumpWidget(host());

    await tester.enterText(
      find.byKey(const Key('media_gallery.search_field')),
      'logo',
    );
    await tester
        .pump(); // muestra el botón limpiar (cancela el debounce al tocar)
    await tester.tap(find.byKey(const Key('media_gallery.search_clear')));
    await tester.pump();

    verify(() => bloc.add(const MediaGallerySearchChanged(''))).called(1);
    // El término 'logo' nunca se despachó (debounce cancelado por el clear).
    verifyNever(() => bloc.add(const MediaGallerySearchChanged('logo')));
  });

  testWidgets('tabs de tipo: tap a una familia despacha TypeChanged', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const MediaGalleryLoaded(items: <MediaAsset>[], nextCursor: ''),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: BlocProvider<MediaGalleryBloc>.value(
          value: bloc,
          child: const Scaffold(
            body: MediaGalleryPage(
              loader: FakeThumbnailLoader(),
              showTypeTabs: true,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('media_gallery.type_chip.all')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('media_gallery.type_chip.image')));
    await tester.pump();
    verify(() => bloc.add(const MediaGalleryTypeChanged('image'))).called(1);
  });

  testWidgets('sin showTypeTabs no se renderizan las tabs', (tester) async {
    when(() => bloc.state).thenReturn(
      const MediaGalleryLoaded(items: <MediaAsset>[], nextCursor: ''),
    );
    await tester.pumpWidget(host()); // showTypeTabs por defecto false
    expect(find.byKey(const Key('media_gallery.type_chip.all')), findsNothing);
  });

  testWidgets('long-press a una miniatura (browse) dispara SelectionToggled', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      MediaGalleryLoaded(
        items: <MediaAsset>[_asset('media/a', previewUrl: null)],
        nextCursor: '',
      ),
    );
    await tester.pumpWidget(host()); // browse (sin onSelect)
    await tester.pump();

    await tester.longPress(find.byType(MediaThumbnail));
    await tester.pump();

    verify(
      () => bloc.add(const MediaGallerySelectionToggled('media/a')),
    ).called(1);
  });

  testWidgets('modo selección: barra con contador + check + limpiar', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      MediaGalleryLoaded(
        items: <MediaAsset>[_asset('media/a', previewUrl: null)],
        nextCursor: '',
        selectedRefs: const <String>{'media/a'},
      ),
    );
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('1 seleccionado'), findsOneWidget);
    expect(
      find.byIcon(Icons.check_circle),
      findsOneWidget,
    ); // overlay selección

    await tester.tap(find.byKey(const Key('media_gallery.selection_clear')));
    await tester.pump();
    verify(() => bloc.add(const MediaGallerySelectionCleared())).called(1);
  });

  testWidgets('el contador de selección sale del textTheme', (tester) async {
    when(() => bloc.state).thenReturn(
      MediaGalleryLoaded(
        items: <MediaAsset>[_asset('media/a', previewUrl: null)],
        nextCursor: '',
        selectedRefs: const <String>{'media/a'},
      ),
    );
    await tester.pumpWidget(host());
    await tester.pump();

    final context = tester.element(find.byType(MediaGalleryPage));
    final textTheme = Theme.of(context).textTheme;
    // Contador de la barra de selección = bodyMedium del theme con el
    // énfasis w600, no un TextStyle crudo con color calcado.
    final counter = tester.widget<Text>(find.text('1 seleccionado'));
    expect(
      counter.style,
      textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  });

  testWidgets('la copy de progreso de subida sale del textTheme', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const MediaGalleryLoaded(
        items: <MediaAsset>[],
        nextCursor: '',
        isUploading: true,
        uploadTotal: 3,
        uploadDone: 1,
      ),
    );
    await tester.pumpWidget(host());
    await tester.pump();

    final context = tester.element(find.byType(MediaGalleryPage));
    final textTheme = Theme.of(context).textTheme;
    // Copy de progreso de subida = bodyMedium del theme tal cual.
    final progress = tester.widget<Text>(find.text('Subiendo 1 de 3…'));
    expect(progress.style, textTheme.bodyMedium);
  });

  testWidgets('modo selección: borrar pide confirmación y despacha el lote', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      MediaGalleryLoaded(
        items: <MediaAsset>[_asset('media/a', previewUrl: null)],
        nextCursor: '',
        selectedRefs: const <String>{'media/a'},
      ),
    );
    await tester.pumpWidget(host());
    await tester.pump();

    await tester.tap(find.byKey(const Key('media_gallery.selection_delete')));
    await tester.pumpAndSettle();
    expect(find.text('¿Borrar 1 archivo?'), findsOneWidget);

    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();
    verify(
      () => bloc.add(const MediaGalleryDeleteSelectedRequested()),
    ).called(1);
  });

  testWidgets('subida en lote muestra el progreso "Subiendo N de M"', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const MediaGalleryLoaded(
        items: <MediaAsset>[],
        nextCursor: '',
        isUploading: true,
        uploadTotal: 3,
        uploadDone: 1,
      ),
    );
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.text('Subiendo 1 de 3…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
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
      // Suficientes filas para que el grid scrollee con CUALQUIER nº de
      // columnas (el delegate responsivo da más columnas en superficies anchas,
      // así que 20 ítems cabrían sin scroll en 800px de test).
      final items = List<MediaAsset>.generate(
        60,
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

  testWidgets('fallo de subida emite snackbar sin tumbar la lista', (
    tester,
  ) async {
    // Estado previo sin outcome, luego transición a un outcome con fallo →
    // snackbar singular (era un solo archivo).
    whenListen(
      bloc,
      Stream<MediaGalleryState>.fromIterable(<MediaGalleryState>[
        MediaGalleryLoaded(
          items: <MediaAsset>[_asset('media/a', previewUrl: null)],
          nextCursor: '',
          uploadOutcome: const MediaUploadOutcome(
            total: 1,
            failed: 1,
            lastError: MediaTooLargeFailure(),
          ),
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
    expect(find.text('No pudimos subir el archivo'), findsOneWidget);
    // La lista sigue visible (no colapsó a un estado de error terminal).
    expect(find.byType(MediaThumbnail), findsOneWidget);
  });

  testWidgets('fallo PARCIAL del lote: el snackbar dice cuántos fallaron', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream<MediaGalleryState>.fromIterable(<MediaGalleryState>[
        MediaGalleryLoaded(
          items: <MediaAsset>[_asset('media/a', previewUrl: null)],
          nextCursor: '',
          uploadOutcome: const MediaUploadOutcome(
            total: 5,
            failed: 2,
            lastError: MediaTooLargeFailure(),
          ),
        ),
      ]),
      initialState: MediaGalleryLoaded(
        items: <MediaAsset>[_asset('media/a', previewUrl: null)],
        nextCursor: '',
      ),
    );
    await tester.pumpWidget(host());
    await tester.pump();
    // Conteo real, no el copy singular que esconde el resto del lote.
    expect(find.text('No pudimos subir 2 de 5 archivos'), findsOneWidget);
  });

  testWidgets(
    'subida OCULTA por el filtro: aviso con "Ver todo" que limpia filtros',
    (tester) async {
      whenListen(
        bloc,
        Stream<MediaGalleryState>.fromIterable(<MediaGalleryState>[
          MediaGalleryLoaded(
            items: <MediaAsset>[_asset('media/a', previewUrl: null)],
            nextCursor: '',
            query: 'logo',
            uploadOutcome: const MediaUploadOutcome(
              total: 1,
              failed: 0,
              hiddenByFilter: true,
            ),
          ),
        ]),
        initialState: MediaGalleryLoaded(
          items: <MediaAsset>[_asset('media/a', previewUrl: null)],
          nextCursor: '',
          query: 'logo',
        ),
      );
      await tester.pumpWidget(host());
      await tester.pump();
      // Deja terminar la animación de entrada del snackbar antes de tocar.
      await tester.pump(const Duration(seconds: 1));

      // El archivo subió pero el filtro activo lo esconde: la UI lo dice en
      // vez de dejar que "desaparezca" en silencio.
      expect(
        find.text('Subido, pero oculto por el filtro activo'),
        findsOneWidget,
      );
      await tester.tap(find.text('Ver todo'));
      await tester.pump();
      verify(() => bloc.add(const MediaGalleryFiltersCleared())).called(1);
    },
  );

  testWidgets('el scrim de borrado en lote ofrece Cancelar', (tester) async {
    when(() => bloc.state).thenReturn(
      MediaGalleryLoaded(
        items: <MediaAsset>[_asset('media/a')],
        nextCursor: '',
        isDeleting: true,
        deleteTotal: 3,
        deleteDone: 1,
      ),
    );
    await tester.pumpWidget(host());

    await tester.tap(find.byKey(const Key('media_gallery.delete_cancel')));
    await tester.pump();
    verify(() => bloc.add(const MediaGalleryDeleteCancelRequested())).called(1);
  });

  group('picker multi-selección (onConfirmSelection)', () {
    Widget multiHost({
      required ValueChanged<List<MediaAsset>> onConfirm,
      Future<bool> Function(MediaAsset asset)? onOpenDetail,
    }) => MaterialApp(
      theme: AppDesignTheme.dark(),
      home: BlocProvider<MediaGalleryBloc>.value(
        value: bloc,
        child: Scaffold(
          body: MediaGalleryPage(
            loader: const FakeThumbnailLoader(),
            onConfirmSelection: onConfirm,
            onOpenDetail: onOpenDetail,
          ),
        ),
      ),
    );

    testWidgets('tap alterna selección y confirmar devuelve los assets', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        MediaGalleryLoaded(
          items: <MediaAsset>[_asset('media/a'), _asset('media/b')],
          nextCursor: '',
        ),
      );
      List<MediaAsset>? confirmed;
      await tester.pumpWidget(multiHost(onConfirm: (a) => confirmed = a));
      await tester.pump();

      // Sin selección no hay barra de confirmar.
      expect(
        find.byKey(const Key('media_gallery.multi_confirm')),
        findsNothing,
      );

      await tester.tap(find.byType(MediaThumbnail).at(0));
      await tester.pump();
      await tester.tap(find.byType(MediaThumbnail).at(1));
      await tester.pump();

      // Ambas miniaturas marcadas y la barra muestra el conteo.
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
      expect(find.text('2 seleccionados'), findsOneWidget);

      await tester.tap(find.byKey(const Key('media_gallery.multi_confirm')));
      await tester.pump();

      // Devuelve los MediaAsset completos en el orden en que se tocaron.
      expect(confirmed, isNotNull);
      expect(confirmed!.map((a) => a.ref).toList(), <String>[
        'media/a',
        'media/b',
      ]);
    });

    testWidgets('re-tap deselecciona y la barra desaparece al quedar vacía', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        MediaGalleryLoaded(
          items: <MediaAsset>[_asset('media/a')],
          nextCursor: '',
        ),
      );
      await tester.pumpWidget(multiHost(onConfirm: (_) {}));
      await tester.pump();

      await tester.tap(find.byType(MediaThumbnail));
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.tap(find.byType(MediaThumbnail));
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(
        find.byKey(const Key('media_gallery.multi_confirm')),
        findsNothing,
      );
    });

    testWidgets('long-press en multi-picker abre el detalle (preview)', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        MediaGalleryLoaded(
          items: <MediaAsset>[_asset('media/a')],
          nextCursor: '',
        ),
      );
      String? previewed;
      await tester.pumpWidget(
        multiHost(
          onConfirm: (_) {},
          onOpenDetail: (asset) async {
            previewed = asset.ref;
            return false;
          },
        ),
      );
      await tester.pump();

      await tester.longPress(find.byType(MediaThumbnail));
      await tester.pump();

      expect(previewed, 'media/a');
      // El long-press NO seleccionó (preview ≠ elegir).
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });
  });

  testWidgets(
    'picker single: long-press abre el detalle SIN seleccionar (preview)',
    (tester) async {
      when(() => bloc.state).thenReturn(
        MediaGalleryLoaded(
          items: <MediaAsset>[_asset('media/a')],
          nextCursor: '',
        ),
      );
      String? selected;
      String? previewed;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: BlocProvider<MediaGalleryBloc>.value(
            value: bloc,
            child: Scaffold(
              body: MediaGalleryPage(
                loader: const FakeThumbnailLoader(),
                onSelect: (asset) => selected = asset.ref,
                onOpenDetail: (asset) async {
                  previewed = asset.ref;
                  return false;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.byType(MediaThumbnail));
      await tester.pump();

      // Preview sin comprometer la selección: el tap sigue siendo elegir.
      expect(previewed, 'media/a');
      expect(selected, isNull);
    },
  );

  group('barrido UX galería', () {
    testWidgets('las tabs de tipo usan AppChoiceChip del design system', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const MediaGalleryLoaded(items: <MediaAsset>[], nextCursor: ''),
      );
      // Las tabs sólo se muestran en modo browse (showTypeTabs).
      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: BlocProvider<MediaGalleryBloc>.value(
            value: bloc,
            child: const Scaffold(
              body: MediaGalleryPage(
                loader: FakeThumbnailLoader(),
                showTypeTabs: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AppChoiceChip), findsNWidgets(5));
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('fallo de load-more muestra fila de error con Reintentar', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        MediaGalleryLoaded(
          items: <MediaAsset>[_asset('media/a')],
          nextCursor: 'cur-1',
          loadMoreError: const MediaNetworkFailure(),
        ),
      );
      await tester.pumpWidget(host());

      expect(find.text('No se pudo cargar más'), findsOneWidget);
      await tester.ensureVisible(find.text('Reintentar'));
      await tester.tap(find.text('Reintentar'));
      await tester.pump();

      verify(() => bloc.add(const MediaGalleryLoadMoreRequested())).called(1);
    });

    testWidgets('overlay de borrado en lote muestra el progreso X de Y', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        MediaGalleryLoaded(
          items: <MediaAsset>[_asset('media/a')],
          nextCursor: '',
          isDeleting: true,
          deleteTotal: 3,
          deleteDone: 1,
        ),
      );
      await tester.pumpWidget(host());

      expect(find.text('Borrando 1 de 3…'), findsOneWidget);
    });

    testWidgets(
      'vacío FILTRADO ofrece limpiar filtros (no el copy de galería virgen)',
      (tester) async {
        when(() => bloc.state).thenReturn(
          const MediaGalleryLoaded(
            items: <MediaAsset>[],
            nextCursor: '',
            query: 'zzz',
          ),
        );
        await tester.pumpWidget(host());

        expect(find.text('Sin resultados para esta búsqueda'), findsOneWidget);
        expect(
          find.text('Todavía no hay archivos en la galería'),
          findsNothing,
        );

        await tester.tap(find.text('Limpiar filtros'));
        await tester.pump();
        // UN solo evento (una recarga), no un evento por filtro.
        verify(() => bloc.add(const MediaGalleryFiltersCleared())).called(1);
      },
    );

    testWidgets('confirmación de borrado en lote usa AppButton.danger', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        MediaGalleryLoaded(
          items: <MediaAsset>[_asset('media/a')],
          nextCursor: '',
          selectedRefs: const <String>{'media/a'},
        ),
      );
      await tester.pumpWidget(host());

      await tester.tap(find.byKey(const Key('media_gallery.selection_delete')));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppButton, 'Borrar'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Cancelar'), findsOneWidget);
    });
  });
}
