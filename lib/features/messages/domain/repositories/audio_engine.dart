/// Puerto del motor de audio del hilo. Abstrae al plugin de reproducción
/// (just_audio en Android; en plataformas sin implementación las llamadas
/// lanzan y la UI degrada con aviso). Un engine = una fuente a la vez —
/// el modelo de mensajería: reproducir una nota pausa la anterior.
abstract interface class AudioEngine {
  /// Carga la fuente [url] (streaming de la URL firmada). Lanza si el
  /// formato/transporte no se pudo abrir.
  Future<void> setUrl(String url);

  Future<void> play();

  Future<void> pause();

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
