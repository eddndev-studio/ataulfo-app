import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/flows/domain/entities/step.dart' as fdom;
import 'package:ataulfo/features/flows/presentation/widgets/step_row.dart';
import 'package:ataulfo/features/flows/presentation/widgets/step_media_field.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// PNG 1x1 transparente válido — bytes reales para que el camino de imagen no
// caiga al errorBuilder por datos corruptos.
final _png1x1 = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Resolver fake por ref: la card resuelve SOLO con el ref BARE (no hay asset
/// efímero en la lista de pasos), así que registra qué asset le llegó para
/// asegurar que sea null.
class _FakeResolver implements StepMediaThumbResolver {
  _FakeResolver(this._byRef);
  final Map<String, Uint8List?> _byRef;
  final List<MediaAsset?> assets = <MediaAsset?>[];

  @override
  Future<Uint8List?> load(String ref, {MediaAsset? asset}) async {
    assets.add(asset);
    return _byRef[ref];
  }
}

fdom.Step _step(
  fdom.StepType type, {
  String mediaRef = '',
  String content = '',
}) => fdom.Step(
  id: 's1',
  flowId: 'f1',
  type: type,
  order: 0,
  content: content,
  mediaRef: mediaRef,
  metadataJson: '{}',
  delayMs: 1000,
  jitterPct: 0,
  aiOnly: false,
);

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    fdom.Step step,
    _FakeResolver resolver, {
    String? resolvedMediaName,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppDesignTheme.dark(),
      home: Scaffold(
        body: StepRow(
          step: step,
          onTap: () {},
          resolvedMediaName: resolvedMediaName,
          thumbResolver: resolver,
        ),
      ),
    ),
  );

  group('StepRow — miniatura del paso multimedia', () {
    testWidgets(
      'paso IMAGE con bytes cacheados: miniatura junto al resumen, resuelta '
      'SOLO por el ref BARE',
      (tester) async {
        const ref = 'tenant/o/media/promo.png';
        final resolver = _FakeResolver(<String, Uint8List?>{ref: _png1x1});

        await pumpCard(
          tester,
          _step(fdom.StepType.image, mediaRef: ref),
          resolver,
          resolvedMediaName: 'Promo de julio',
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('app_media_thumb.image')),
          findsOneWidget,
        );
        // La lista no tiene asset efímero: el resolver trabaja con el ref solo.
        expect(resolver.assets, everyElement(isNull));
        // El resumen textual sigue: el nombre EN VIVO del catálogo.
        expect(find.text('Promo de julio'), findsOneWidget);
      },
    );

    testWidgets(
      'paso VIDEO sin bytes en cache: glifo de video (el poster sólo existe '
      'cuando la galería ya lo cacheó)',
      (tester) async {
        const ref = 'tenant/o/media/clip.mp4';
        final resolver = _FakeResolver(<String, Uint8List?>{});

        await pumpCard(
          tester,
          _step(fdom.StepType.video, mediaRef: ref),
          resolver,
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('app_media_thumb.fallback')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
      },
    );

    testWidgets('glifo por tipo: PTT cae a audio y DOCUMENT a documento', (
      tester,
    ) async {
      final resolver = _FakeResolver(<String, Uint8List?>{});

      await pumpCard(
        tester,
        _step(fdom.StepType.ptt, mediaRef: 'tenant/o/media/nota.ogg'),
        resolver,
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.audiotrack_outlined), findsOneWidget);

      await pumpCard(
        tester,
        _step(fdom.StepType.document, mediaRef: 'tenant/o/media/c.pdf'),
        resolver,
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
    });

    testWidgets('paso TEXT no monta miniatura alguna', (tester) async {
      final resolver = _FakeResolver(<String, Uint8List?>{});

      await pumpCard(
        tester,
        _step(fdom.StepType.text, content: 'Hola'),
        resolver,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('app_media_thumb.image')), findsNothing);
      expect(
        find.byKey(const ValueKey('app_media_thumb.fallback')),
        findsNothing,
      );
      expect(resolver.assets, isEmpty);
    });

    testWidgets('multimedia SIN mediaRef: fallback textual, sin miniatura', (
      tester,
    ) async {
      final resolver = _FakeResolver(<String, Uint8List?>{});

      await pumpCard(tester, _step(fdom.StepType.image), resolver);
      await tester.pumpAndSettle();

      expect(find.text('Sin media asignada'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('app_media_thumb.fallback')),
        findsNothing,
      );
    });
  });
}
