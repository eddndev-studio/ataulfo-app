import 'dart:typed_data';

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

/// Resolver fake: responde por ref y registra cada petición (ref + si llegó
/// el asset efímero del picker) para verificar el cableado sin disco ni red.
class _FakeResolver implements StepMediaThumbResolver {
  _FakeResolver(this._byRef);
  final Map<String, Uint8List?> _byRef;
  final List<({String ref, MediaAsset? asset})> requests =
      <({String ref, MediaAsset? asset})>[];

  @override
  Future<Uint8List?> load(String ref, {MediaAsset? asset}) async {
    requests.add((ref: ref, asset: asset));
    return _byRef[ref];
  }
}

MediaAsset _asset(
  String ref, {
  String contentType = 'image/png',
  String filename = 'foto.png',
  String alias = '',
}) => MediaAsset(
  ref: ref,
  previewUrl: 'https://signed.example/x?sig=efimera',
  filename: filename,
  alias: alias,
  contentType: contentType,
  size: 1,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required TextEditingController controller,
    required _FakeResolver resolver,
    MediaRefPicker? pickMediaRef,
    String? family = 'image',
    ValueChanged<MediaAsset>? onPicked,
    bool enabled = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StepMediaField(
          controller: controller,
          pickMediaRef: pickMediaRef,
          family: family,
          onPicked: onPicked ?? (_) {},
          enabled: enabled,
          thumbResolver: resolver,
        ),
      ),
    ),
  );

  group('StepMediaField — miniatura efímera', () {
    testWidgets(
      'ref hidratado (sin asset): resuelve por ref y pinta la miniatura; la '
      'cola del ref en monospace queda como texto',
      (tester) async {
        const ref = 'tenant/o/media/orig.png';
        final controller = TextEditingController(text: ref);
        addTearDown(controller.dispose);
        final resolver = _FakeResolver(<String, Uint8List?>{ref: _png1x1});

        await pump(tester, controller: controller, resolver: resolver);
        await tester.pumpAndSettle();

        // El resolver recibió el ref BARE, sin asset (nada elegido aún).
        expect(resolver.requests, hasLength(1));
        expect(resolver.requests.single.ref, ref);
        expect(resolver.requests.single.asset, isNull);

        expect(
          find.byKey(const ValueKey('app_media_thumb.image')),
          findsOneWidget,
        );
        // Sin nombre conocido, la cola del ref sigue siendo el texto (mono).
        final tail = tester.widget<Text>(find.text('orig.png'));
        expect(tail.style?.fontFamily, 'monospace');
      },
    );

    testWidgets(
      'ref hidratado sin bytes: glifo por familia del paso — fallback honesto',
      (tester) async {
        const ref = 'tenant/o/media/orig.ogg';
        final controller = TextEditingController(text: ref);
        addTearDown(controller.dispose);
        final resolver = _FakeResolver(<String, Uint8List?>{});

        await pump(
          tester,
          controller: controller,
          resolver: resolver,
          family: 'audio',
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('app_media_thumb.fallback')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.audiotrack_outlined), findsOneWidget);
      },
    );

    testWidgets('family null (paso documento) sin asset ⇒ glifo de documento', (
      tester,
    ) async {
      const ref = 'tenant/o/media/contrato.pdf';
      final controller = TextEditingController(text: ref);
      addTearDown(controller.dispose);
      final resolver = _FakeResolver(<String, Uint8List?>{});

      await pump(
        tester,
        controller: controller,
        resolver: resolver,
        family: null,
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
    });

    testWidgets(
      'al elegir del picker: el resolver recibe el ASSET efímero y el nombre '
      'legible reemplaza a la cola del ref',
      (tester) async {
        const ref = 'tenant/o/media/nueva.png';
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        final resolver = _FakeResolver(<String, Uint8List?>{ref: _png1x1});
        final asset = _asset(ref, filename: 'promo-julio.png');

        await pump(
          tester,
          controller: controller,
          resolver: resolver,
          pickMediaRef: (_, _) async => asset,
        );
        await tester.tap(find.byKey(const Key('step_edit.media_picker')));
        await tester.pumpAndSettle();

        // El asset del picker viaja al resolver: con él puede descargar y
        // cachear la miniatura aunque el ref nunca haya pasado por la galería.
        expect(resolver.requests, isNotEmpty);
        expect(resolver.requests.last.ref, ref);
        expect(resolver.requests.last.asset, asset);

        expect(
          find.byKey(const ValueKey('app_media_thumb.image')),
          findsOneWidget,
        );
        // Nombre legible del asset (no mono), y la cola del ref ya no es el texto.
        final name = tester.widget<Text>(find.text('promo-julio.png'));
        expect(name.style?.fontFamily, isNot('monospace'));
        expect(find.text('nueva.png'), findsNothing);
      },
    );

    testWidgets(
      'con asset elegido el glifo sale del contentType, no de la familia '
      '(paso documento puede llevar un audio)',
      (tester) async {
        const ref = 'tenant/o/media/nota.ogg';
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        final resolver = _FakeResolver(<String, Uint8List?>{});
        final asset = _asset(
          ref,
          contentType: 'audio/ogg',
          filename: 'nota.ogg',
        );

        await pump(
          tester,
          controller: controller,
          resolver: resolver,
          family: null,
          pickMediaRef: (_, _) async => asset,
        );
        await tester.tap(find.byKey(const Key('step_edit.media_picker')));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.audiotrack_outlined), findsOneWidget);
      },
    );

    testWidgets('conserva el contrato del chip: keys y "Cambiar" interactivo', (
      tester,
    ) async {
      const ref = 'tenant/o/media/orig.png';
      final controller = TextEditingController(text: ref);
      addTearDown(controller.dispose);
      final resolver = _FakeResolver(<String, Uint8List?>{});

      await pump(
        tester,
        controller: controller,
        resolver: resolver,
        pickMediaRef: (_, _) async => null,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('step_edit.media_selected')), findsOneWidget);
      expect(find.byKey(const Key('step_edit.media_change')), findsOneWidget);
      expect(find.byKey(const Key('step_edit.media_picker')), findsNothing);
    });
  });
}
