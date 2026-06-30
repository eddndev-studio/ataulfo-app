import 'dart:async';

import 'package:ataulfo/features/messages/data/media/record_audio_recorder.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart' as rec;

class _MockRec extends Mock implements rec.AudioRecorder {}

void main() {
  test(
    'un teardown (stop) durante un resume() pendiente no deja un ticker huérfano',
    () {
      fakeAsync((async) {
        final mock = _MockRec();
        when(() => mock.pause()).thenAnswer((_) async {});
        final resumeGate = Completer<void>();
        when(() => mock.resume()).thenAnswer((_) => resumeGate.future);
        when(() => mock.stop()).thenAnswer((_) async => null);

        final recorder = RecordAudioRecorder(recorder: mock);
        final ticks = <Duration>[];
        final sub = recorder.elapsed.listen(ticks.add);

        // Estado pausado.
        recorder.pause();
        async.flushMicrotasks();

        // Reanudar: queda suspendido en el round-trip de la plataforma.
        recorder.resume();
        async.flushMicrotasks();

        // Antes de que resuelva, se detiene la grabación (envío/cancelación):
        // _stopStreams() corre sincrónicamente y desmonta el ticker.
        recorder.stop();
        async.flushMicrotasks();

        // Ahora sí resuelve el resume: NO debe re-armar un ticker sobre un
        // grabador ya detenido (el grabador es un singleton de la app).
        resumeGate.complete();
        async.flushMicrotasks();

        ticks.clear();
        async.elapse(const Duration(milliseconds: 600));
        async.flushMicrotasks();
        expect(
          ticks,
          isEmpty,
          reason: 'el ticker no debe seguir emitiendo tras el teardown',
        );

        sub.cancel();
      });
    },
  );
}
