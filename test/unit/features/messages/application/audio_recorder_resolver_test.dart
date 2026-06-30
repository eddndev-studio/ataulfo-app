import 'package:ataulfo/features/messages/application/audio_recorder_resolver.dart';
import 'package:ataulfo/features/messages/data/media/noop_audio_recorder.dart';
import 'package:ataulfo/features/messages/domain/repositories/audio_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Grabador de prueba: marca que la factory de Android se invocó sin construir
/// el plugin real (que necesitaría canales de plataforma).
class _StubRecorder implements AudioRecorder {
  @override
  Future<bool> isSupported() async => true;
  @override
  Future<bool> hasPermission() async => true;
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

void main() {
  test('en Android construye el grabador real (factory inyectada)', () {
    var built = 0;
    final resolver = AudioRecorderResolver(
      isAndroid: true,
      androidRecorder: () {
        built++;
        return _StubRecorder();
      },
    );

    final r = resolver.resolve();

    expect(built, 1);
    expect(r, isA<_StubRecorder>());
  });

  test('fuera de Android usa el Noop (sin construir el real)', () {
    var built = 0;
    final resolver = AudioRecorderResolver(
      isAndroid: false,
      androidRecorder: () {
        built++;
        return _StubRecorder();
      },
    );

    final r = resolver.resolve();

    expect(built, 0);
    expect(r, isA<NoopAudioRecorder>());
  });
}
