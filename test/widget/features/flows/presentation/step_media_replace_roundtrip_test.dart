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

/// Round-trip de REEMPLAZO de media en edición, a nivel de RUTA (no de fake).
///
/// Espejo del round-trip de creación pero en modo edit: un step multimedia
/// existente ya tiene su `mediaRef`. El sheet muestra "Cambiar", que hace
/// `ctx.push('/media/pick')`; la galería-picker devuelve el nuevo `ref` BARE
/// vía `context.pop(ref)`. Montamos AMBAS rutas con un repo FAKE cuya
/// `previewUrl != ref` para verificar que lo que viaja como `mediaRef` en el
/// `UpdateRequested` es el ref BARE, NUNCA la previewUrl efímera.
void main() {
  setUpAll(() {
    registerFallbackValue(
      const FlowStepsUpdateRequested(stepId: 's', content: 'x'),
    );
  });

  late _MockStepsBloc stepsBloc;
  late _MockMediaRepo mediaRepo;
  late _MockFilePicker filePicker;

  // El step en edición y su media original (URL-shaped, distinto del nuevo ref
  // BARE que la galería devolverá). Reemplazar este ref es el objeto del test.
  const imgStep = fdom.Step(
    id: 's-img',
    flowId: 'f1',
    type: fdom.StepType.image,
    order: 0,
    content: 'caption original',
    mediaRef: 'https://x/orig.png',
    metadataJson: '{}',
    delayMs: 0,
    jitterPct: 0,
    aiOnly: false,
  );

  // Asset conocido en la galería: el ref BARE canónico difiere de la
  // previewUrl firmada. Si el callback de selección devolviera la previewUrl,
  // la aserción de ref exacto fallaría — ése es el diente del test.
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
    ).thenReturn(const FlowStepsLoaded(<fdom.Step>[imgStep]));
    mediaRepo = _MockMediaRepo();
    when(
      () => mediaRepo.listAssets(cursor: any(named: 'cursor'), limit: null),
    ).thenAnswer(
      (_) async => MediaPage(assets: <MediaAsset>[asset], nextCursor: ''),
    );
    filePicker = _MockFilePicker();
  });

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
                                editing: imgStep,
                                pickMediaRef: (c) =>
                                    c.push<String>('/media/pick'),
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
          builder: (context, _) => BlocProvider<MediaGalleryBloc>(
            create: (_) =>
                MediaGalleryBloc(repo: mediaRepo, picker: filePicker)
                  ..add(const MediaGalleryLoadRequested()),
            child: Scaffold(
              appBar: AppBar(title: const Text('Elegir multimedia')),
              body: MediaGalleryPage(onSelect: (ref) => context.pop(ref)),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: AppDesignTheme.dark(), routerConfig: router),
    );
  }

  testWidgets(
    'editar: "Cambiar" → push(/media/pick) → tap miniatura → pop(ref BARE) → '
    'submit despacha UpdateRequested con el ref BARE (NO la previewUrl)',
    (tester) async {
      await pumpHost(tester);

      // Abrir el sheet en edición; el media ya está prefilled → "Cambiar".
      await tester.tap(find.byKey(const Key('host.open_sheet')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('step_edit.media_change')));
      await tester.pumpAndSettle();

      // La galería cargó (repo fake) y la miniatura es tappable.
      expect(find.byType(MediaThumbnail), findsOneWidget);
      await tester.tap(find.byType(MediaThumbnail));
      await tester.pumpAndSettle();

      // Volvimos al sheet con el nuevo ref aplicado: el chip sigue presente.
      expect(find.byKey(const Key('step_edit.media_selected')), findsOneWidget);

      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();

      final captured = verify(() => stepsBloc.add(captureAny())).captured;
      expect(captured, hasLength(1));
      final ev = captured.single as FlowStepsUpdateRequested;
      expect(ev.stepId, 's-img');
      // El ref BARE viaja al evento; explícitamente NO la previewUrl efímera.
      expect(ev.mediaRef, bareRef);
      expect(ev.mediaRef, isNot(signedUrl));
      // Only-changed: el caption no se tocó.
      expect(ev.content, isNull);
    },
  );
}
