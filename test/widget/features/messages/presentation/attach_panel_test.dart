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
/// Registra las aperturas de Ajustes (destino Galería bloqueado).
class _FakeGallery implements DeviceGalleryPort {
  _FakeGallery(this.assets);
  final List<DeviceMediaAsset> assets;
  int openSettingsCalls = 0;

  @override
  Future<DeviceGalleryAvailability> availability() async =>
      DeviceGalleryAvailability.available;

  @override
  Future<void> openSettings() async => openSettingsCalls++;

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
      // La transición se anima: se asienta antes de verificar el resultado.
      await tester.pumpAndSettle();

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
    'el cambio destinos↔cámara se ANIMA (ambas vistas conviven durante la '
    'transición) en vez de saltar de golpe',
    (tester) async {
      final cubit = AttachPanelCubit()
        ..open(showCamera: true, showGallery: false);
      addTearDown(cubit.close);
      await tester.pumpWidget(host(cubit: cubit, metrics: _fixed));
      await tester.pump();

      await tester.tap(find.byKey(const Key('attach_menu.camera')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // A media transición, la vista que entra Y la que sale están montadas.
      expect(find.byKey(const Key('attach_menu.camera.photo')), findsOneWidget);
      expect(find.byKey(const Key('attach_menu.document')), findsOneWidget);

      // Al asentarse queda sólo la vista de cámara.
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attach_menu.camera.photo')), findsOneWidget);
      expect(find.byKey(const Key('attach_menu.document')), findsNothing);
    },
  );

  testWidgets(
    'volver de Cámara restaura la fracción arrastrada de la hoja (no la '
    'resetea al tamaño inicial)',
    (tester) async {
      final cubit = AttachPanelCubit()
        ..open(showCamera: true, showGallery: true);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        host(
          cubit: cubit,
          metrics: _expandable,
          gallery: _FakeGallery(_assets),
        ),
      );
      await tester.pumpAndSettle();

      final initialTop = tester
          .getTopLeft(find.byKey(const Key('attach_panel.handle')))
          .dy;

      // Expandir al máximo con el gesto del destino Galería.
      await tester.tap(find.byKey(const Key('attach_menu.gallery')));
      await tester.pumpAndSettle();
      final expandedTop = tester
          .getTopLeft(find.byKey(const Key('attach_panel.handle')))
          .dy;
      expect(expandedTop, lessThan(initialTop - 100));

      // Ir a Cámara y volver: la hoja regresa a la fracción expandida.
      await tester.tap(find.byKey(const Key('attach_menu.camera')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('attach_panel.camera_back')));
      await tester.pumpAndSettle();

      final restoredTop = tester
          .getTopLeft(find.byKey(const Key('attach_panel.handle')))
          .dy;
      expect(
        (restoredTop - expandedTop).abs(),
        lessThan(24),
        reason: 'la hoja debe volver a donde el operador la dejó',
      );
    },
  );

  testWidgets(
    'la bandeja ya llevaba adjuntos: el picker sólo ofrece el CUPO RESTANTE '
    'del lote',
    (tester) async {
      // 9 en la bandeja ⇒ sólo cabe 1 más.
      final cubit = AttachPanelCubit()
        ..open(showCamera: false, showGallery: true, attachmentCount: 9);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        host(
          cubit: cubit,
          metrics: _expandable,
          gallery: _FakeGallery(_assets),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('attach_gallery.item.a1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attach_gallery.check.a1')), findsOneWidget);

      // El segundo excede 9+1: aviso y sin badge.
      await tester.tap(find.byKey(const Key('attach_gallery.item.a2')));
      await tester.pumpAndSettle();
      expect(find.text('Máximo 10 archivos por envío'), findsOneWidget);
      expect(find.byKey(const Key('attach_gallery.check.a2')), findsNothing);
      expect(find.text('Adjuntar (1)'), findsOneWidget);
    },
  );

  testWidgets(
    'galería BLOQUEADA (permiso denegado): el destino sigue visible y tocarlo '
    'explica el bloqueo con acción para abrir Ajustes',
    (tester) async {
      final gallery = _FakeGallery(const <DeviceMediaAsset>[]);
      final cubit = AttachPanelCubit()
        ..open(showCamera: false, showGallery: false, galleryBlocked: true);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        host(cubit: cubit, metrics: _fixed, gallery: gallery),
      );
      await tester.pump();

      // El destino NO desaparece; sin carrete accesible no hay hoja expandible.
      expect(find.byKey(const Key('attach_menu.gallery')), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsNothing);

      // Tocarlo explica el bloqueo y ofrece Ajustes; el panel no se cierra.
      await tester.tap(find.byKey(const Key('attach_menu.gallery')));
      await tester.pumpAndSettle();
      expect(
        find.text('Permite el acceso a tus fotos para adjuntar del carrete'),
        findsOneWidget,
      );
      expect(cubit.isOpen, isTrue);

      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();
      expect(gallery.openSettingsCalls, 1);
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
