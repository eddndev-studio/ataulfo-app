import 'dart:typed_data';

/// Destino donde sembrar los bytes de una media ya en mano bajo su ref
/// definitiva (la copia local de un adjunto recién subido o de una nota de voz
/// recién grabada). Puerto consumer-defined: los hilos de agentes lo usan para
/// que la burbuja recién enviada se pinte/reproduzca desde disco sin depender
/// de una URL firmada que su wire no trae.
abstract interface class MediaByteSink {
  /// Persiste [bytes] bajo [ref]. Best-effort: no debe lanzar.
  Future<void> cache(String ref, Uint8List bytes);
}
