import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/flows/domain/entities/step.dart' as fdom;
import 'package:ataulfo/features/flows/presentation/bloc/flow_steps_bloc.dart';
import 'package:ataulfo/features/flows/presentation/widgets/step_edit_sheet.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:ataulfo/features/media/presentation/bloc/media_gallery_bloc.dart';
import 'package:ataulfo/features/media/presentation/pages/media_gallery_page.dart';
import 'package:ataulfo/features/media/presentation/widgets/media_thumbnail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockStepsBloc extends MockBloc<FlowStepsEvent, FlowStepsState>
    implements FlowStepsBloc {}

class _MockMediaRepo extends Mock implements MediaRepository {}

class _MockFilePicker extends Mock implements MediaFilePicker {}

/// Round-trip de selección de media a nivel de RUTA, no de fake.
///
/// El seam que un `pickMediaRef` fake esconde es el push→pop real: el sheet
/// hace `ctx.push('/media/pick')` y la galería-picker devuelve el `ref` BARE
/// vía `context.pop(ref)`. Aquí montamos AMBAS rutas con un `GoRouter` y un
/// repo FAKE cuya `previewUrl != ref`, para verificar que lo que vuelve —y se
/// despacha como `mediaRef`— es el ref BARE, NUNCA la previewUrl efímera.
void main() {
  setUpAll(() {
    registerFallbackValue(
      const FlowStepsAddRequested(
        content: '',
        delayMs: 0,
        jitterPct: 0,
        aiOnly: false,
      ),
    );
  });

  late _MockStepsBloc stepsBloc;
  late _MockMediaRepo mediaRepo;
  late _MockFilePicker filePicker;

  // Asset conocido: el ref BARE canónico difiere de la previewUrl firmada.
  // Si el callback de selección devolviera la previewUrl, las aserciones
  // de ref exacto fallarían — ése es el diente del test.
  const bareRef = 'tenant/org1/media/zzz999.png';
  const signedUrl = 'https://signed.example/zzz999?sig=ephemeral';
  final asset = MediaAsset(
    ref: bareRef,
    previewUrl: signedUrl,
    filename: 'zzz999.png',
    contentType: 'image/png',
    size: 42,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    stepsBloc = _MockStepsBloc();
    when(
      () => stepsBloc.state,
    ).thenReturn(const FlowStepsLoaded(<fdom.Step>[]));
    mediaRepo = _MockMediaRepo();
    when(
      () => mediaRepo.listAssets(
        cursor: any(named: 'cursor'),
        limit: null,
        type: any(named: 'type'),
      ),
    ).thenAnswer(
      (_) async => MediaPage(assets: <MediaAsset>[asset], nextCursor: ''),
    );
    filePicker = _MockFilePicker();
  });

  // El host monta un GoRouter con dos rutas: la host abre el StepEditSheet
  // (vía showModalBottomSheet, igual que la app real) con el callback REAL
  // `ctx.push('/media/pick')`, y `/media/pick` monta la galería-picker con
  // EXACTAMENTE el mismo `onSelect: (ref) => context.pop(ref)` que la ruta
  // real. Así el valor que vuelve al sheet es el que la galería emite por
  // `onSelect`, no un valor calculado por una vía lateral: el test captura
  // tanto una regresión de cableado como una de "la galería emite previewUrl".
  Future<void> pumpHost(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/host',
      routes: <RouteBase>[
        GoRoute(
          path: '/host',
          builder: (_, _) => BlocProvider<FlowStepsBloc>.value(
            value: stepsBloc,
            child: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    key: const Key('host.open_sheet'),
                    onPressed: () {
                      final bloc = ctx.read<FlowStepsBloc>();
                      showModalBottomSheet<void>(
                        context: ctx,
                        isScrollControlled: true,
                        builder: (sheetCtx) =>
                            BlocProvider<FlowStepsBloc>.value(
                              value: bloc,
                              child: StepEditSheet(
                                pickMediaRef: (c, family) => c.push<MediaAsset>(
                                  family == null
                                      ? '/media/pick'
                                      : '/media/pick?type=$family',
                                ),
                              ),
                            ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/media/pick',
          builder: (context, state) {
            final type = state.uri.queryParameters['type'];
            return BlocProvider<MediaGalleryBloc>(
              create: (_) => MediaGalleryBloc(
                repo: mediaRepo,
                picker: filePicker,
                type: type,
              )..add(const MediaGalleryLoadRequested()),
              child: Scaffold(
                appBar: AppBar(title: const Text('Elegir multimedia')),
                body: MediaGalleryPage(onSelect: (asset) => context.pop(asset)),
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: AppDesignTheme.dark(), routerConfig: router),
    );
  }

  testWidgets(
    'push(/media/pick) → tap miniatura → pop(ref BARE) → submit despacha '
    'AddRequested con el ref BARE (NO la previewUrl)',
    (tester) async {
      await pumpHost(tester);

      // Abrir el sheet, elegir IMAGE, abrir el picker.
      await tester.tap(find.byKey(const Key('host.open_sheet')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('step_edit.type.image')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('step_edit.media_picker')));
      await tester.pumpAndSettle();

      // La galería se cargó FILTRADA por la familia del paso (IMAGE): el sheet
      // pasó family='image' y la ruta lo propagó como ?type=image al bloc.
      verify(
        () => mediaRepo.listAssets(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          type: 'image',
        ),
      ).called(greaterThanOrEqualTo(1));

      // La galería cargó (repo fake) y la miniatura es tappable.
      expect(find.byType(MediaThumbnail), findsOneWidget);
      await tester.tap(find.byType(MediaThumbnail));
      await tester.pumpAndSettle();

      // Volvimos al sheet con el ref aplicado: hay chip seleccionado.
      expect(find.byKey(const Key('step_edit.media_selected')), findsOneWidget);

      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();

      final captured = verify(() => stepsBloc.add(captureAny())).captured;
      expect(captured, hasLength(1));
      final ev = captured.single as FlowStepsAddRequested;
      expect(ev.type, fdom.StepType.image);
      // El ref BARE viaja al evento; explícitamente NO la previewUrl efímera.
      expect(ev.mediaRef, bareRef);
      expect(ev.mediaRef, isNot(signedUrl));
      expect(ev.content, '');
    },
  );
}
