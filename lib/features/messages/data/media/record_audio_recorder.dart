import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as rec;

import '../../domain/repositories/audio_recorder.dart';
import 'waveform.dart';

/// Grabador real de notas de voz: Opus-en-Ogg vía el plugin `record`. WhatsApp
/// móvil sólo renderiza como nota de voz el Opus-en-Ogg, así que la config es
/// fija (opus, 16 kHz mono ~16 kbps — paridad con las notas nativas). Opus
/// exige Android API>=29; el resolver restringe este adapter a Android e
/// [isSupported] confirma el encoder antes de ofrecer el micrófono.
///
/// Adaptador delgado (sin lógica de negocio, igual que el engine de playback):
/// expone la amplitud en vivo para la UI y el tiempo transcurrido por un
/// stopwatch. No se prueba en unidad (necesita micrófono); el flujo del
/// composer se prueba contra un fake del puerto.
class RecordAudioRecorder implements AudioRecorder {
  RecordAudioRecorder({rec.AudioRecorder? recorder})
    : _rec = recorder ?? rec.AudioRecorder();

  final rec.AudioRecorder _rec;

  final StreamController<double> _amplitude =
      StreamController<double>.broadcast();
  final StreamController<Duration> _elapsed =
      StreamController<Duration>.broadcast();

  StreamSubscription<rec.Amplitude>? _ampSub;
  Timer? _ticker;
  final Stopwatch _watch = Stopwatch();

  /// Grabación pausada (manos libres): el stopwatch y el ticker están detenidos
  /// y el listener de amplitud descarta muestras hasta reanudar.
  bool _paused = false;

  /// Muestras de amplitud (0-100) capturadas en vivo; al detener se reducen a
  /// 64 para el waveform nativo de la nota de voz.
  final List<int> _samples = <int>[];

  // Piso en dBFS para normalizar la amplitud a 0-100: por debajo de esto se
  // trata como silencio. El habla normal en Android ronda -50..0 dBFS.
  static const double _floorDb = -50.0;

  static const rec.RecordConfig _config = rec.RecordConfig(
    encoder: rec.AudioEncoder.opus,
    sampleRate: 16000,
    numChannels: 1,
    bitRate: 16000,
  );

  @override
  Future<bool> isSupported() => _rec.isEncoderSupported(rec.AudioEncoder.opus);

  @override
  Future<bool> hasPermission() => _rec.hasPermission();

  @override
  Future<void> start() async {
    // Defensa ante un start() re-entrante: cancela cualquier timer/suscripción
    // previa antes de reasignar, para no dejarlos huérfanos.
    _stopStreams();
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice-${DateTime.now().microsecondsSinceEpoch}.opus';
    _samples.clear();
    await _rec.start(_config, path: path);
    _watch
      ..reset()
      ..start();
    _startTicker();
    _ampSub = _rec.onAmplitudeChanged(const Duration(milliseconds: 100)).listen(
      (a) {
        // En pausa el grabador no captura; descarta cualquier muestra rezagada
        // para que ni el waveform del wire ni el feedback en vivo avancen.
        if (_paused) return;
        final v = _normalize(a.current);
        _samples.add(v.round());
        _amplitude.add(v);
      },
    );
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _elapsed.add(_watch.elapsed);
    });
  }

  @override
  Future<void> pause() async {
    if (_paused) return;
    _paused = true;
    // Congela el tiempo y deja de emitir transcurrido; el archivo se conserva.
    _watch.stop();
    _ticker?.cancel();
    _ticker = null;
    await _rec.pause();
  }

  @override
  Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    await _rec.resume();
    // Continúa el mismo clip: el stopwatch reanuda (excluye la pausa) y el
    // ticker vuelve a publicar el transcurrido.
    _watch.start();
    _startTicker();
  }

  @override
  Future<RecordedVoice?> stop() async {
    final elapsed = _watch.elapsed;
    final path = await _teardownAndStop();
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    return RecordedVoice(
      bytes: bytes,
      duration: elapsed,
      waveform: downsampleWaveform(_samples),
    );
  }

  @override
  Future<void> cancel() async {
    _stopStreams();
    await _rec.cancel();
  }

  @override
  Stream<double> get amplitude => _amplitude.stream;

  @override
  Stream<Duration> get elapsed => _elapsed.stream;

  @override
  Future<void> dispose() async {
    _stopStreams();
    await _amplitude.close();
    await _elapsed.close();
    await _rec.dispose();
  }

  Future<String?> _teardownAndStop() async {
    _stopStreams();
    return _rec.stop();
  }

  void _stopStreams() {
    _paused = false;
    _watch.stop();
    _ticker?.cancel();
    _ticker = null;
    _ampSub?.cancel();
    _ampSub = null;
  }

  // dBFS (<=0) → 0..100. Clampa al piso y reescala lineal. Un valor no-finito
  // (silencio absoluto en algunos backends) se trata como silencio (0) en vez
  // de propagar un NaN que reventaría el .round() del acumulador.
  double _normalize(double dbfs) {
    if (!dbfs.isFinite) return 0;
    if (dbfs <= _floorDb) return 0;
    if (dbfs >= 0) return 100;
    return (dbfs - _floorDb) / (-_floorDb) * 100;
  }
}
