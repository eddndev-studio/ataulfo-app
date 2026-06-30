import 'dart:typed_data';

/// Una nota de voz grabada, lista para subir (`/upload` → ref BARE) y enviar
/// como `type:ptt`.
class RecordedVoice {
  const RecordedVoice({
    required this.bytes,
    required this.duration,
    this.waveform = const <int>[],
  });

  /// Bytes del archivo Opus-en-Ogg.
  final Uint8List bytes;

  /// Duración grabada (alimenta el guard de duración mínima y el preview).
  final Duration duration;

  /// Muestras de amplitud `0-100` (hasta 64) computadas durante la grabación;
  /// vacío si no se calcularon. El backend las pone en el waveform nativo de
  /// la nota de voz para que el receptor lo vea.
  final List<int> waveform;
}

/// Grabador de notas de voz (Opus-en-Ogg). Aísla el plugin nativo y la
/// degradación de escritorio detrás de un puerto para poder probar el flujo
/// del composer sin un device ni canales de plataforma.
///
/// En plataformas sin micrófono real (el dev box es Linux; tampoco hay impl
/// Opus bajo Android API<29) el resolver inyecta un Noop: [isSupported]
/// devuelve false y la UI no ofrece la grabación.
abstract interface class AudioRecorder {
  /// Si esta plataforma puede grabar Opus (Android API>=29). Falso ⇒ la UI
  /// no muestra el botón de micrófono.
  Future<bool> isSupported();

  /// Solicita/verifica el permiso de micrófono. Falso ⇒ no se puede grabar.
  Future<bool> hasPermission();

  /// Empieza a grabar a un archivo temporal Opus-en-Ogg.
  Future<void> start();

  /// Detiene y devuelve la grabación, o null si no hubo nada utilizable
  /// (no se estaba grabando / fallo / archivo vacío).
  Future<RecordedVoice?> stop();

  /// Detiene y descarta la grabación.
  Future<void> cancel();

  /// Pausa la grabación en curso conservando el mismo archivo (manos libres,
  /// al estilo de WhatsApp): el tiempo transcurrido y el waveform se congelan;
  /// [resume] continúa el mismo clip. No-op si no se está grabando.
  Future<void> pause();

  /// Reanuda una grabación pausada con [pause], continuando el mismo archivo.
  /// No-op si no estaba pausada.
  Future<void> resume();

  /// Amplitud del micrófono normalizada a `0..100` mientras graba.
  Stream<double> get amplitude;

  /// Tiempo transcurrido de la grabación en curso.
  Stream<Duration> get elapsed;

  /// Libera recursos nativos.
  Future<void> dispose();
}
