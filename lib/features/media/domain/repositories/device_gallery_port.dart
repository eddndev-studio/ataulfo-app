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

/// Qué tan accesible es el carrete del dispositivo:
///
/// - [available]: hay acceso (total o limitado); la UI ofrece la grilla.
/// - [denied]: la plataforma TIENE carrete pero el permiso está denegado; la
///   UI muestra el destino BLOQUEADO con la vía a Ajustes (nunca lo esconde
///   en silencio).
/// - [unsupported]: no hay carrete en esta plataforma (escritorio/web); la
///   UI no ofrece el destino.
enum DeviceGalleryAvailability { available, denied, unsupported }

/// Puerto consumer-defined para el carrete REAL del teléfono (fotos/videos
/// del dispositivo, no la biblioteca de la organización). El dominio declara
/// el contrato; el adaptador concreto (sobre `photo_manager`) vive en `data/`.
///
/// Reusa [PickedMedia] en [bytesFor]: un asset elegido del carrete entra al
/// mismo camino de subida que cualquier archivo elegido con el picker.
abstract interface class DeviceGalleryPort {
  /// Disponibilidad del carrete (incluye pedir el permiso en runtime cuando
  /// aplica). Distingue permiso denegado de plataforma sin carrete.
  Future<DeviceGalleryAvailability> availability();

  /// Abre los ajustes del sistema para que el usuario conceda el permiso de
  /// fotos (vía de rescate cuando [availability] es `denied`). Best-effort:
  /// nunca lanza.
  Future<void> openSettings();

  /// Una página de los assets más recientes del carrete (fotos y videos, más
  /// nuevo primero): la página [page] (0-based) de [limit] elementos. Una
  /// página corta (menos de [limit]) señala el final del carrete. Vacío si no
  /// hay acceso o no hay media.
  Future<List<DeviceMediaAsset>> recentMedia({int limit = 60, int page = 0});

  /// Miniatura cuadrada de [size] px del asset, o `null` si no se pudo
  /// generar (la grilla pinta un placeholder, nunca crashea).
  Future<Uint8List?> thumbnailFor(DeviceMediaAsset asset, {int size = 256});

  /// El archivo completo del asset como [PickedMedia] (bytes + nombre), o
  /// `null` si ya no está disponible.
  Future<PickedMedia?> bytesFor(DeviceMediaAsset asset);
}
