import 'package:ataulfo/features/messages/data/media/noop_audio_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('se anuncia no soportado y no graba nada', () async {
    const r = NoopAudioRecorder();

    expect(await r.isSupported(), isFalse);
    expect(await r.hasPermission(), isFalse);
    await r.start();
    expect(await r.stop(), isNull);
    await r.cancel();
    await r.dispose();
  });

  test('los streams están vacíos (terminan sin emitir)', () async {
    const r = NoopAudioRecorder();
    await expectLater(r.amplitude, emitsDone);
    await expectLater(r.elapsed, emitsDone);
  });
}
