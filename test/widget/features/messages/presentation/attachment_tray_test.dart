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

  group('PendingAttachment ya subido (existingRef, sin bytes locales)', () {
    test('sizeBytes usa el override del servidor cuando no hay bytes', () {
      const att = PendingAttachment(
        filename: 'contrato.pdf',
        type: 'document',
        existingRef: 'tenant/org/media/abc.pdf',
        sizeBytesOverride: 2048,
      );
      expect(att.sizeBytes, 2048);
      expect(att.isAlreadyUploaded, isTrue);
      expect(att.isImage, isFalse);
    });

    test('sizeBytes cae a bytes.length cuando no hay override', () {
      final att = PendingAttachment(
        bytes: Uint8List(7),
        filename: 'a.png',
        type: 'image',
      );
      expect(att.sizeBytes, 7);
      expect(att.isAlreadyUploaded, isFalse);
    });

    test('sin bytes ni override, sizeBytes es 0', () {
      const att = PendingAttachment(filename: 'x.bin', type: 'document');
      expect(att.sizeBytes, 0);
    });

    test('isImage sigue saliendo del type, sin bytes', () {
      const att = PendingAttachment(
        filename: 'foto.png',
        type: 'image',
        existingRef: 'tenant/org/media/foto.png',
        previewUrl: 'https://signed.test/foto.png',
        sizeBytesOverride: 99,
      );
      expect(att.isImage, isTrue);
      expect(att.isAlreadyUploaded, isTrue);
    });
  });

  group('tarjeta de imagen sin bytes locales', () {
    testWidgets('con previewUrl intenta pintar la red (NetworkImage)', (
      tester,
    ) async {
      const url = 'https://signed.test/miniatura.png';
      await tester.pumpWidget(
        host(<PendingAttachment>[
          const PendingAttachment(
            filename: 'foto.png',
            type: 'image',
            existingRef: 'tenant/org/media/foto.png',
            previewUrl: url,
            sizeBytesOverride: 42,
          ),
        ]),
      );
      await tester.pump();
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const Key('composer.attachment_tray.item.0')),
          matching: find.byType(Image),
        ),
      );
      expect(image.image, isA<NetworkImage>());
      expect((image.image as NetworkImage).url, url);
    });

    testWidgets('si la URL falla, cae a la cara de archivo (errorBuilder)', (
      tester,
    ) async {
      // En tests Image.network falla siempre (sin red real): el fallback debe
      // ser la cara de archivo con nombre, no un hueco ni una excepción.
      await tester.pumpWidget(
        host(<PendingAttachment>[
          const PendingAttachment(
            filename: 'foto.png',
            type: 'image',
            existingRef: 'tenant/org/media/foto.png',
            previewUrl: 'https://invalid.test/falla.png',
            sizeBytesOverride: 42,
          ),
        ]),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('foto.png'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin previewUrl ni bytes, pinta la cara de archivo directo', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(<PendingAttachment>[
          const PendingAttachment(
            filename: 'foto.png',
            type: 'image',
            existingRef: 'tenant/org/media/foto.png',
            sizeBytesOverride: 42,
          ),
        ]),
      );
      await tester.pump();
      expect(find.text('foto.png'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('composer.attachment_tray.item.0')),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
    });
  });
}
