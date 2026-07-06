import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/domain/repositories/device_gallery_port.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/messages/presentation/bloc/attach_panel_cubit.dart';
import 'package:ataulfo/features/messages/presentation/widgets/attach_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carrete falso con N assets fijos, suficiente para pintar la grilla.
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

const List<DeviceMediaAsset> _assets = <DeviceMediaAsset>[
  DeviceMediaAsset(id: 'a1', filename: 'uno.jpg'),
  DeviceMediaAsset(id: 'a2', filename: 'dos.mp4', isVideo: true),
];

const AttachPanelMetrics _fixed = AttachPanelMetrics(
  expandable: false,
  reservedHeight: 152,
  initialFraction: 0,
  minFraction: 0,
  maxFraction: 0,
);

const AttachPanelMetrics _expandable = AttachPanelMetrics(
  expandable: true,
  reservedHeight: 315,
  initialFraction: 0.45,
  minFraction: 0.30,
  maxFraction: 0.95,
);

void main() {
  Widget host({
    required AttachPanelCubit cubit,
    required AttachPanelMetrics metrics,
    DeviceGalleryPort? gallery,
    double height = 700,
  }) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: RepositoryProvider<DeviceGalleryPort>.value(
      value: gallery ?? _FakeGallery(const <DeviceMediaAsset>[]),
      child: BlocProvider<AttachPanelCubit>.value(
        value: cubit,
        child: Scaffold(
          body: SizedBox(
            height: height,
            width: 400,
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: AttachPanel(metrics: metrics)),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('cerrado no pinta nada', (tester) async {
    final cubit = AttachPanelCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(host(cubit: cubit, metrics: _fixed));
    expect(find.byKey(const Key('attach_menu.document')), findsNothing);
  });

  testWidgets(
    'destinos sin galería: Documento y Medios, sin Cámara ni Galería',
    (tester) async {
      final cubit = AttachPanelCubit()
        ..open(showCamera: false, showGallery: false);
      addTearDown(cubit.close);
      await tester.pumpWidget(host(cubit: cubit, metrics: _fixed));
      await tester.pump();

      expect(find.byKey(const Key('attach_menu.document')), findsOneWidget);
      expect(find.byKey(const Key('attach_menu.media')), findsOneWidget);
      expect(find.byKey(const Key('attach_menu.camera')), findsNothing);
      expect(find.byKey(const Key('attach_menu.gallery')), findsNothing);
      // Sin carrete NO hay hoja expandible ni manija.
      expect(find.byType(DraggableScrollableSheet), findsNothing);
    },
  );

  testWidgets('tocar Documento emite AttachDocumentIntent y cierra el panel', (
    tester,
  ) async {
    final cubit = AttachPanelCubit()
      ..open(showCamera: false, showGallery: false);
    addTearDown(cubit.close);
    final intents = <AttachIntent>[];
    final sub = cubit.intents.listen(intents.add);
    addTearDown(sub.cancel);

    await tester.pumpWidget(host(cubit: cubit, metrics: _fixed));
    await tester.tap(find.byKey(const Key('attach_menu.document')));
    await tester.pump();

    expect(intents.single, isA<AttachDocumentIntent>());
    expect(cubit.state, isNull);
  });

  testWidgets('tocar Medios emite AttachMediaIntent', (tester) async {
    final cubit = AttachPanelCubit()
      ..open(showCamera: false, showGallery: false);
    addTearDown(cubit.close);
    final intents = <AttachIntent>[];
    final sub = cubit.intents.listen(intents.add);
    addTearDown(sub.cancel);

    await tester.pumpWidget(host(cubit: cubit, metrics: _fixed));
    await tester.tap(find.byKey(const Key('attach_menu.media')));
    await tester.pump();

    expect(intents.single, isA<AttachMediaIntent>());
  });

  testWidgets(
    'tocar Cámara cambia a la vista de cámara (swap, SIN ruta) con Foto/Video',
    (tester) async {
      final cubit = AttachPanelCubit()
        ..open(showCamera: true, showGallery: false);
      addTearDown(cubit.close);
      await tester.pumpWidget(host(cubit: cubit, metrics: _fixed));
      await tester.pump();

      expect(find.byKey(const Key('attach_menu.camera')), findsOneWidget);
      await tester.tap(find.byKey(const Key('attach_menu.camera')));
      await tester.pump();

      // Sin ruta: el mismo panel ahora muestra Foto/Video.
      expect(cubit.state?.view, AttachPanelView.camera);
      expect(find.byKey(const Key('attach_menu.camera.photo')), findsOneWidget);
      expect(find.byKey(const Key('attach_menu.camera.video')), findsOneWidget);
      // Los destinos de la fila anterior ya no están.
      expect(find.byKey(const Key('attach_menu.document')), findsNothing);
    },
  );

  testWidgets(
    'vista de cámara: Foto emite intención; volver regresa a destinos',
    (tester) async {
      final cubit = AttachPanelCubit()
        ..open(showCamera: true, showGallery: false);
      cubit.showCameraView();
      addTearDown(cubit.close);
      final intents = <AttachIntent>[];
      final sub = cubit.intents.listen(intents.add);
      addTearDown(sub.cancel);

      await tester.pumpWidget(host(cubit: cubit, metrics: _fixed));
      await tester.pump();

      // Volver a destinos.
      await tester.tap(find.byKey(const Key('attach_panel.camera_back')));
      await tester.pump();
      expect(cubit.state?.view, AttachPanelView.destinations);

      // De vuelta en cámara, Foto emite AttachPhotoIntent.
      cubit.showCameraView();
      await tester.pump();
      await tester.tap(find.byKey(const Key('attach_menu.camera.photo')));
      await tester.pump();
      expect(intents.single, isA<AttachPhotoIntent>());
    },
  );

  testWidgets(
    'con galería: panel expandible con grid; Adjuntar emite AttachGalleryIntent',
    (tester) async {
      final cubit = AttachPanelCubit()
        ..open(showCamera: false, showGallery: true);
      addTearDown(cubit.close);
      final intents = <AttachIntent>[];
      final sub = cubit.intents.listen(intents.add);
      addTearDown(sub.cancel);

      await tester.pumpWidget(
        host(
          cubit: cubit,
          metrics: _expandable,
          gallery: _FakeGallery(_assets),
        ),
      );
      await tester.pumpAndSettle();

      // Fila de íconos (con el carrete) + grilla del carrete, expandible. El
      // label distingue el carrete del CATÁLOGO de la org ("Medios"): son
      // destinos distintos y "Galería" a secas los confundía.
      expect(find.byKey(const Key('attach_menu.gallery')), findsOneWidget);
      expect(find.text('Fotos del dispositivo'), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(find.byKey(const Key('attach_gallery.grid')), findsOneWidget);
      expect(find.byKey(const Key('attach_gallery.item.a1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('attach_gallery.item.a1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('attach_gallery.confirm')));
      await tester.pump();

      expect(intents.single, isA<AttachGalleryIntent>());
      expect(
        (intents.single as AttachGalleryIntent).assets.map((a) => a.id),
        <String>['a1'],
      );
      expect(cubit.state, isNull);
    },
  );
}
