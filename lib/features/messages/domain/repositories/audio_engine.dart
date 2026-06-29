import 'dart:typed_data';

/// Puerto del motor de audio del hilo. Abstrae al plugin de reproducción
/// (just_audio en Android; en plataformas sin implementación las llamadas
/// lanzan y la UI degrada con aviso). Un engine = una fuente a la vez —
/// el modelo de mensajería: reproducir una nota pausa la anterior.
abstract interface class AudioEngine {
  /// Carga la fuente [url] (streaming de la URL firmada). Lanza si el
  /// formato/transporte no se pudo abrir.
  Future<void> setUrl(String url);

  /// Carga la fuente desde [bytes] ya en memoria (la copia local de la nota:
  /// cacheada al enviar / descargada una vez al recibir). [contentType] es la
  /// pista de formato (p. ej. `audio/ogg`). Reproducir el archivo COMPLETO —en
  /// vez de streamear la URL firmada— hace que el transporte reporte la duración
  /// de inmediato (la barra de progreso vive). Lanza si el formato no se pudo
  /// abrir; el llamador degrada al streaming de la URL.
  Future<void> setBytes(Uint8List bytes, String contentType);

  Future<void> play();

  Future<void> pause();

  /// Salta a [position] dentro de la fuente cargada (scrubbing de la barra).
  Future<void> seek(Duration position);

  /// Fija la velocidad de reproducción ([speed] 1.0 = normal). Se reasienta
  /// tras cargar una fuente nueva para que la velocidad elegida persista.
  Future<void> setSpeed(double speed);

  /// Reproduciendo o en pausa, según el transporte real.
  Stream<bool> get playingStream;

  /// Posición actual de reproducción.
  Stream<Duration> get positionStream;

  /// Duración total de la fuente cargada (`null` mientras se conoce).
  Stream<Duration?> get durationStream;

  /// Emite cuando la fuente llegó a su fin.
  Stream<void> get completedStream;

  Future<void> dispose();
}
