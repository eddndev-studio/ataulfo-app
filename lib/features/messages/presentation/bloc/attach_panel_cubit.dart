import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../media/domain/repositories/device_gallery_port.dart';

/// Vista visible dentro del panel de adjuntar: la fila de destinos, o la
/// sub-elección de cámara (foto/video). Ambas viven en el MISMO panel; pasar
/// de una a otra es un swap de contenido, nunca una ruta nueva.
enum AttachPanelView { destinations, camera }

/// Estado del panel de adjuntar ABIERTO: qué vista se muestra y qué destinos
/// ofrecer. El soporte de cámara/carrete lo resuelve el llamador (composer)
/// con `isSupported()` ANTES de abrir, así el panel nunca pinta un destino
/// muerto. Panel cerrado ⇒ estado `null`.
class AttachPanelState {
  const AttachPanelState({
    required this.view,
    required this.showCamera,
    required this.showGallery,
  });

  final AttachPanelView view;
  final bool showCamera;
  final bool showGallery;

  AttachPanelState _withView(AttachPanelView next) => AttachPanelState(
    view: next,
    showCamera: showCamera,
    showGallery: showGallery,
  );

  @override
  bool operator ==(Object other) =>
      other is AttachPanelState &&
      other.view == view &&
      other.showCamera == showCamera &&
      other.showGallery == showGallery;

  @override
  int get hashCode => Object.hash(view, showCamera, showGallery);
}

/// Intención elegida en el panel. El panel sólo DECIDE; ejecutar el flujo
/// (elegir archivos, capturar con la cámara, materializar el carrete) queda en
/// el composer, dueño de la bandeja de adjuntos y de las dependencias.
sealed class AttachIntent {
  const AttachIntent();
}

/// Elegir archivos del dispositivo (el picker múltiple de siempre).
class AttachDocumentIntent extends AttachIntent {
  const AttachDocumentIntent();
}

/// Elegir un asset ya subido del catálogo de media de la organización.
class AttachMediaIntent extends AttachIntent {
  const AttachMediaIntent();
}

/// Capturar una foto con la cámara.
class AttachPhotoIntent extends AttachIntent {
  const AttachPhotoIntent();
}

/// Grabar un video con la cámara.
class AttachVideoIntent extends AttachIntent {
  const AttachVideoIntent();
}

/// Confirmar una selección del carrete, en orden de tap. Los bytes NO viajan
/// aquí: el composer los pide bajo demanda con [DeviceGalleryPort.bytesFor].
class AttachGalleryIntent extends AttachIntent {
  const AttachGalleryIntent(this.assets);

  final List<DeviceMediaAsset> assets;
}

/// Estado de UI del panel de adjuntar del hilo (estilo WhatsApp): el panel
/// vive DENTRO del layout de la página (no es ruta) e intercambia lugar con el
/// teclado. Este cubit guarda SÓLO el estado visible —abierto/cerrado y qué
/// vista— y publica la intención elegida por un canal aparte [intents], que el
/// composer consume para ejecutar el flujo con sus propias dependencias. La
/// separación mantiene al cubit como estado puro y al composer como único
/// dueño de la bandeja de adjuntos.
class AttachPanelCubit extends Cubit<AttachPanelState?> {
  AttachPanelCubit() : super(null);

  final StreamController<AttachIntent> _intents =
      StreamController<AttachIntent>.broadcast();

  /// Intención elegida en el panel. Se emite justo cuando el panel se cierra
  /// (elegir un destino confirma y cierra de una).
  Stream<AttachIntent> get intents => _intents.stream;

  bool get isOpen => state != null;

  /// Abre el panel en la vista de destinos con los flags de soporte ya
  /// resueltos por el llamador.
  void open({required bool showCamera, required bool showGallery}) => emit(
    AttachPanelState(
      view: AttachPanelView.destinations,
      showCamera: showCamera,
      showGallery: showGallery,
    ),
  );

  /// Cambia a la sub-elección de cámara (foto/video) dentro del mismo panel.
  /// No-op con el panel cerrado.
  void showCameraView() {
    final current = state;
    if (current != null) emit(current._withView(AttachPanelView.camera));
  }

  /// Vuelve a la fila de destinos desde la vista de cámara. No-op con el panel
  /// cerrado.
  void showDestinations() {
    final current = state;
    if (current != null) emit(current._withView(AttachPanelView.destinations));
  }

  /// Cierra el panel (back, tocar el clip de nuevo, o enfocar el campo).
  void dismiss() => emit(null);

  void chooseDocument() => _choose(const AttachDocumentIntent());
  void chooseMedia() => _choose(const AttachMediaIntent());
  void choosePhoto() => _choose(const AttachPhotoIntent());
  void chooseVideo() => _choose(const AttachVideoIntent());
  void confirmGallery(List<DeviceMediaAsset> assets) =>
      _choose(AttachGalleryIntent(assets));

  /// Publica la intención y cierra el panel de una: el destino ya se eligió.
  void _choose(AttachIntent intent) {
    _intents.add(intent);
    emit(null);
  }

  @override
  Future<void> close() {
    _intents.close();
    return super.close();
  }
}
