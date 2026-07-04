import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/messages/presentation/widgets/attachment_tray.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Un PNG 1x1 mínimo válido para que Image.memory decodifique sin fallar.
  final pngBytes = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, //
    0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4,
    0x89, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae,
    0x42, 0x60, 0x82,
  ]);

  Widget host(
    List<PendingAttachment> items, {
    void Function(int)? onRemove,
    bool uploading = false,
    int uploadedCount = 0,
  }) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(
      body: AttachmentTray(
        items: items,
        onRemove: onRemove ?? (_) {},
        uploading: uploading,
        uploadedCount: uploadedCount,
      ),
    ),
  );

  PendingAttachment img(String name) =>
      PendingAttachment(bytes: pngBytes, filename: name, type: 'image');

  PendingAttachment doc(String name, {int size = 2048}) => PendingAttachment(
    bytes: Uint8List(size),
    filename: name,
    type: 'document',
  );

  testWidgets('una imagen se muestra como miniatura (Image)', (tester) async {
    await tester.pumpWidget(host(<PendingAttachment>[img('foto.png')]));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('composer.attachment_tray.item.0')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
  });

  testWidgets('un documento muestra nombre y peso (sin miniatura)', (
    tester,
  ) async {
    await tester.pumpWidget(host(<PendingAttachment>[doc('contrato.pdf')]));
    await tester.pump();
    expect(find.text('contrato.pdf'), findsOneWidget);
    expect(find.textContaining('KB'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('composer.attachment_tray.item.0')),
        matching: find.byType(Image),
      ),
      findsNothing,
    );
  });

  testWidgets('quitar un ítem invoca onRemove con su índice', (tester) async {
    int? removed;
    await tester.pumpWidget(
      host(
        <PendingAttachment>[img('a.png'), doc('b.pdf')],
        onRemove: (i) {
          removed = i;
        },
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('composer.attachment_tray.item.1.remove')),
    );
    expect(removed, 1);
  });

  testWidgets('el contador refleja la cantidad de adjuntos', (tester) async {
    await tester.pumpWidget(
      host(<PendingAttachment>[img('a.png'), img('b.png'), doc('c.pdf')]),
    );
    await tester.pump();
    expect(find.textContaining('3'), findsWidgets);
  });

  testWidgets('subiendo: muestra progreso n/total y oculta el quitar', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        <PendingAttachment>[img('a.png'), doc('b.pdf')],
        uploading: true,
        uploadedCount: 1,
      ),
    );
    await tester.pump();
    expect(find.textContaining('1/2'), findsOneWidget);
    expect(
      find.byKey(const Key('composer.attachment_tray.item.0.remove')),
      findsNothing,
    );
  });
}
