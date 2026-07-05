import 'dart:typed_data';

import 'media_file_picker.dart';

/// Un asset del carrete del dispositivo, SIN bytes: sólo la identidad y lo
/// que la grilla necesita pintar (nombre, si es video y su duración). Los
/// bytes se piden aparte y bajo demanda ([DeviceGalleryPort.thumbnailFor] /
/// [DeviceGalleryPort.bytesFor]) para no materializar el carrete completo en
/// memoria.
class DeviceMediaAsset {
  const DeviceMediaAsset({
    required this.id,
    required this.filename,
    this.isVideo = false,
    this.durationMs,
  });

  /// Identidad del asset en el almacén del dispositivo (MediaStore).
  final String id;

  /// Nombre de archivo con extensión real: de él se infiere el `type` de
  /// envío cuando el asset se adjunta.
  final String filename;

  /// El asset es un video (la grilla superpone duración e ícono).
  final bool isVideo;

  /// Duración en milisegundos, sólo para videos; `null` en fotos.
  final int? durationMs;
}

/// Puerto consumer-defined para el carrete REAL del teléfono (fotos/videos
/// del dispositivo, no la biblioteca de la organización). El dominio declara
/// el contrato; el adaptador concreto (sobre `photo_manager`) vive en `data/`.
///
/// Reusa [PickedMedia] en [bytesFor]: un asset elegido del carrete entra al
/// mismo camino de subida que cualquier archivo elegido con el picker.
abstract interface class DeviceGalleryPort {
  /// La plataforma expone un carrete accesible (incluye el permiso en
  /// runtime). Falso ⇒ la UI no ofrece el destino Galería.
  Future<bool> isSupported();

  /// Los assets más recientes del carrete (fotos y videos, más nuevo
  /// primero), hasta [limit]. Vacío si no hay acceso o no hay media.
  Future<List<DeviceMediaAsset>> recentMedia({int limit = 60});

  /// Miniatura cuadrada de [size] px del asset, o `null` si no se pudo
  /// generar (la grilla pinta un placeholder, nunca crashea).
  Future<Uint8List?> thumbnailFor(DeviceMediaAsset asset, {int size = 256});

  /// El archivo completo del asset como [PickedMedia] (bytes + nombre), o
  /// `null` si ya no está disponible.
  Future<PickedMedia?> bytesFor(DeviceMediaAsset asset);
}
