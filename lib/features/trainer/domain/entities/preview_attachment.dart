import 'package:flutter/foundation.dart';

/// Adjunto del playground: bytes EN MEMORIA del cliente hasta el send (el
/// demo no toca storage — el server los recibe base64 y los descarta con
/// la sesión). El MIME lo decide el sniff del servidor; aquí solo viaja
/// el nombre para los marcadores.
class PreviewAttachment {
  const PreviewAttachment({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  @override
  bool operator ==(Object other) =>
      other is PreviewAttachment &&
      other.name == name &&
      listEquals(other.bytes, bytes);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(bytes));
}
