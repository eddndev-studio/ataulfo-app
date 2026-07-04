import '../../../../core/audio/audio_recorder.dart';

/// Grabador inerte para plataformas sin micrófono nativo (el dev box es Linux;
/// también web). Se anuncia como NO soportado, así la UI no ofrece grabar, y
/// todas las operaciones son no-ops. Mantiene la app corriendo fuera de
/// Android sin canales de plataforma.
class NoopAudioRecorder implements AudioRecorder {
  const NoopAudioRecorder();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<void> start() async {}

  @override
  Future<RecordedVoice?> stop() async => null;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Stream<double> get amplitude => const Stream<double>.empty();

  @override
  Stream<Duration> get elapsed => const Stream<Duration>.empty();

  @override
  Future<void> dispose() async {}
}
