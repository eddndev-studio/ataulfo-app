import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/domain/repositories/device_gallery_port.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/messages/presentation/widgets/attach_gallery_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carrete falso: N assets fijos, miniaturas triviales. Suficiente para pintar
/// la grilla y ejercer selección/estado vacío sin plataforma.
class _FakeGallery implements DeviceGalleryPort {
  _FakeGallery(this.assets);

  final List<DeviceMediaAsset> assets;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<List<DeviceMediaAsset>> recentMedia({int limit = 60}) async =>
      assets.take(limit).toList(growable: false);

  @override
  Future<Uint8List?> thumbnailFor(DeviceMediaAsset asset, {int size = 256}) =>
      Future<Uint8List?>.value();

  @override
  Future<PickedMedia?> bytesFor(DeviceMediaAsset asset) async => PickedMedia(
    bytes: Uint8List.fromList(<int>[1]),
    filename: asset.filename,
  );
}

const List<DeviceMediaAsset> _threeAssets = <DeviceMediaAsset>[
  DeviceMediaAsset(id: 'a1', filename: 'uno.jpg'),
  DeviceMediaAsset(id: 'a2', filename: 'dos.mp4', isVideo: true),
  DeviceMediaAsset(id: 'a3', filename: 'tres.png'),
];

void main() {
  Widget host(
    DeviceGalleryPort gallery, {
    void Function(List<DeviceMediaAsset>)? onConfirm,
  }) {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    return MaterialApp(
      theme: AppDesignTheme.dark(),
      home: Scaffold(
        body: SizedBox(
          height: 600,
          width: 400,
          child: AttachGalleryPicker(
            gallery: gallery,
            scrollController: controller,
            onConfirm: onConfirm ?? (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets(
    'la selección lleva badge numerado en ORDEN DE TAP y confirma en ese orden',
    (tester) async {
      List<DeviceMediaAsset>? confirmed;
      await tester.pumpWidget(
        host(_FakeGallery(_threeAssets), onConfirm: (a) => confirmed = a),
      );
      await tester.pumpAndSettle();

      // Sin selección no hay badges ni botón de confirmar.
      expect(find.byKey(const Key('attach_gallery.check.a2')), findsNothing);
      expect(find.byKey(const Key('attach_gallery.confirm')), findsNothing);

      // Tap a2 (queda #1), luego a1 (queda #2).
      await tester.tap(find.byKey(const Key('attach_gallery.item.a2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('attach_gallery.item.a1')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('attach_gallery.check.a2')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('attach_gallery.check.a1')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(find.text('Adjuntar (2)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('attach_gallery.confirm')));
      await tester.pump();
      expect(confirmed?.map((a) => a.id), <String>['a2', 'a1']);
    },
  );

  testWidgets('destocar una miniatura la quita de la selección', (
    tester,
  ) async {
    await tester.pumpWidget(host(_FakeGallery(_threeAssets)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('attach_gallery.item.a1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attach_gallery.check.a1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('attach_gallery.item.a1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attach_gallery.check.a1')), findsNothing);
    expect(find.byKey(const Key('attach_gallery.confirm')), findsNothing);
  });

  testWidgets('carrete vacío muestra "Sin fotos recientes" y no confirma', (
    tester,
  ) async {
    await tester.pumpWidget(host(_FakeGallery(const <DeviceMediaAsset>[])));
    await tester.pumpAndSettle();

    expect(find.text('Sin fotos recientes'), findsOneWidget);
    expect(find.byKey(const Key('attach_gallery.grid')), findsNothing);
    expect(find.byKey(const Key('attach_gallery.confirm')), findsNothing);
  });
}
