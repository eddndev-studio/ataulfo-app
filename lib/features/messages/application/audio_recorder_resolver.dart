import '../data/media/noop_audio_recorder.dart';
import '../data/media/record_audio_recorder.dart';
import '../domain/repositories/audio_recorder.dart';

/// Elige el [AudioRecorder] según la plataforma: sólo Android usa el grabador
/// real (Opus vía `record`); el resto (escritorio/Linux del dev box, web) usa
/// un Noop para que la app corra sin micrófono nativo. Aísla la selección del
/// bootstrap para poder probarla sin canales de plataforma.
///
/// `androidRecorder` se inyecta sólo en tests; en producción construye el
/// [RecordAudioRecorder] real.
class AudioRecorderResolver {
  AudioRecorderResolver({
    required this.isAndroid,
    AudioRecorder Function()? androidRecorder,
  }) : _androidRecorder = androidRecorder ?? RecordAudioRecorder.new;

  final bool isAndroid;
  final AudioRecorder Function() _androidRecorder;

  AudioRecorder resolve() =>
      isAndroid ? _androidRecorder() : const NoopAudioRecorder();
}
