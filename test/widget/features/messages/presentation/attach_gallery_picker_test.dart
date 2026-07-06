import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/domain/repositories/device_gallery_port.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/messages/domain/attachment_intake.dart';
import 'package:ataulfo/features/messages/presentation/widgets/attach_gallery_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carrete falso: N assets fijos, miniaturas triviales. Suficiente para pintar
/// la grilla y ejercer selección/estado vacío sin plataforma.
class _FakeGallery implements DeviceGalleryPort {
  _FakeGallery(this.assets);

  final List<DeviceMediaAsset> assets;

  @override
  Future<DeviceGalleryAvailability> availability() async =>
      DeviceGalleryAvailability.available;

  @override
  Future<void> openSettings() async {}

  @override
  Future<List<DeviceMediaAsset>> recentMedia({
    int limit = 60,
    int page = 0,
  }) async => assets.take(limit).toList(growable: false);

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

/// Carrete falso PAGINADO: sirve [assets] por páginas de `limit` y registra
/// qué páginas se pidieron, para validar el scroll infinito del picker.
class _PagedGallery implements DeviceGalleryPort {
  _PagedGallery(this.assets);

  final List<DeviceMediaAsset> assets;
  final List<int> pagesRequested = <int>[];

  @override
  Future<DeviceGalleryAvailability> availability() async =>
      DeviceGalleryAvailability.available;

  @override
  Future<void> openSettings() async {}

  @override
  Future<List<DeviceMediaAsset>> recentMedia({
    int limit = 60,
    int page = 0,
  }) async {
    pagesRequested.add(page);
    return assets.skip(page * limit).take(limit).toList(growable: false);
  }

  @override
  Future<Uint8List?> thumbnailFor(DeviceMediaAsset asset, {int size = 256}) =>
      Future<Uint8List?>.value();

  @override
  Future<PickedMedia?> bytesFor(DeviceMediaAsset asset) async => PickedMedia(
    bytes: Uint8List.fromList(<int>[1]),
    filename: asset.filename,
  );
}

void main() {
  Widget host(
    DeviceGalleryPort gallery, {
    void Function(List<DeviceMediaAsset>)? onConfirm,
    int? maxSelection,
    int? limit,
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
            maxSelection: maxSelection ?? kMaxAttachmentsPerBatch,
            limit: limit ?? 120,
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

  testWidgets(
    'tocar una miniatura MÁS ALLÁ del tope avisa con SnackBar y no la '
    'selecciona',
    (tester) async {
      await tester.pumpWidget(
        host(_FakeGallery(_threeAssets), maxSelection: 2),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('attach_gallery.item.a1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('attach_gallery.item.a2')));
      await tester.pumpAndSettle();
      expect(find.text('Máximo 10 archivos por envío'), findsNothing);

      // El tercero ya no cabe: aviso visible, sin badge y el contador se queda.
      await tester.tap(find.byKey(const Key('attach_gallery.item.a3')));
      await tester.pumpAndSettle();
      expect(find.text('Máximo 10 archivos por envío'), findsOneWidget);
      expect(find.byKey(const Key('attach_gallery.check.a3')), findsNothing);
      expect(find.text('Adjuntar (2)'), findsOneWidget);
    },
  );

  testWidgets(
    'cada miniatura expone semántica de botón con etiqueta y selección',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(_FakeGallery(_threeAssets)));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byKey(const Key('attach_gallery.item.a1'))),
        isSemantics(label: 'Foto uno.jpg', isButton: true, isSelected: false),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('attach_gallery.item.a2'))),
        isSemantics(label: 'Video dos.mp4', isButton: true),
      );

      await tester.tap(find.byKey(const Key('attach_gallery.item.a1')));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(const Key('attach_gallery.item.a1'))),
        isSemantics(isSelected: true),
      );
      handle.dispose();
    },
  );

  testWidgets(
    'mantener presionada una miniatura abre una previsualización de solo '
    'lectura, sin alterar la selección',
    (tester) async {
      await tester.pumpWidget(host(_FakeGallery(_threeAssets)));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const Key('attach_gallery.item.a2')));
      await tester.pumpAndSettle();

      // Se abre la previsualización (video: con su señal de duración) y NO
      // se seleccionó nada.
      expect(find.byKey(const Key('attach_gallery.preview')), findsOneWidget);
      expect(find.byKey(const Key('attach_gallery.check.a2')), findsNothing);
      expect(find.byKey(const Key('attach_gallery.confirm')), findsNothing);

      // Tocar fuera la cierra y el picker sigue intacto.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attach_gallery.preview')), findsNothing);
      expect(find.byKey(const Key('attach_gallery.grid')), findsOneWidget);
    },
  );

  testWidgets('carrete vacío muestra "Sin fotos recientes" y no confirma', (
    tester,
  ) async {
    await tester.pumpWidget(host(_FakeGallery(const <DeviceMediaAsset>[])));
    await tester.pumpAndSettle();

    expect(find.text('Sin fotos recientes'), findsOneWidget);
    expect(find.byKey(const Key('attach_gallery.grid')), findsNothing);
    expect(find.byKey(const Key('attach_gallery.confirm')), findsNothing);
  });

  testWidgets(
    'scrollear cerca del final carga la siguiente página del carrete y la '
    'última página agota la paginación',
    (tester) async {
      final gallery = _PagedGallery(<DeviceMediaAsset>[
        for (var i = 1; i <= 24; i++)
          DeviceMediaAsset(id: 'a$i', filename: 'f$i.jpg'),
      ]);
      await tester.pumpWidget(host(gallery, limit: 15));
      await tester.pumpAndSettle();

      // Primera página visible; la segunda aún no se pidió.
      expect(find.byKey(const Key('attach_gallery.item.a1')), findsOneWidget);
      expect(gallery.pagesRequested, <int>[0]);

      // Scrollear hasta cerca del final pide la página 1 y aparecen los
      // assets viejos.
      await tester.drag(
        find.byKey(const Key('attach_gallery.grid')),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(gallery.pagesRequested, <int>[0, 1]);
      await tester.scrollUntilVisible(
        find.byKey(const Key('attach_gallery.item.a24')),
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('attach_gallery.grid')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.byKey(const Key('attach_gallery.item.a24')), findsOneWidget);

      // La página 1 vino corta (9 < 15): agotado, más scroll no pide otra.
      await tester.drag(
        find.byKey(const Key('attach_gallery.grid')),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(gallery.pagesRequested, <int>[0, 1]);
    },
  );
}
