import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/audio_engine.dart';

/// Estado de la reproducción de audio del hilo. Hay UN player por hilo
/// (modelo de mensajería): [sourceKey] identifica la fuente activa (el
/// `mediaRef` de la nota, estable e inmutable —no la URL firmada efímera—);
/// cada burbuja de audio se pinta como "suya" sólo si su ref coincide.
class ThreadAudioState {
  const ThreadAudioState({
    this.sourceKey,
    this.playing = false,
    this.position = Duration.zero,
    this.duration,
    this.speed = 1.0,
    this.failedKey,
  });

  /// Fuente cargada en el player —el `mediaRef` de la nota— (`null` = nada
  /// sonó aún).
  final String? sourceKey;

  final bool playing;

  final Duration position;

  /// `null` mientras el transporte no conoce la duración.
  final Duration? duration;

  /// Velocidad de reproducción (1.0 = normal). Es del hilo, no de la fuente:
  /// se conserva al cambiar de nota y al completar, y se reasienta en el engine
  /// al cargar una fuente nueva.
  final double speed;

  /// Último `mediaRef` que no se pudo cargar/reproducir — la UI lo anuncia y
  /// este campo se conserva hasta el siguiente intento (cambia ⇒ nuevo aviso).
  final String? failedKey;

  ThreadAudioState copyWith({
    String? sourceKey,
    bool? playing,
    Duration? position,
    Duration? duration,
    double? speed,
    String? failedKey,
  }) => ThreadAudioState(
    sourceKey: sourceKey ?? this.sourceKey,
    playing: playing ?? this.playing,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    speed: speed ?? this.speed,
    failedKey: failedKey ?? this.failedKey,
  );

  @override
  bool operator ==(Object other) =>
      other is ThreadAudioState &&
      other.sourceKey == sourceKey &&
      other.playing == playing &&
      other.position == position &&
      other.duration == duration &&
      other.speed == speed &&
      other.failedKey == failedKey;

  @override
  int get hashCode =>
      Object.hash(sourceKey, playing, position, duration, speed, failedKey);
}

/// Controla el audio del hilo contra el [AudioEngine]: toggle por burbuja
/// (cargar/pausar/reanudar), espejo de posición/duración y reset al
/// completar. Los streams del engine son la única fuente de verdad del
/// estado de transporte (no se asume éxito de play/pause).
class ThreadAudioCubit extends Cubit<ThreadAudioState> {
  ThreadAudioCubit({required AudioEngine engine})
    : _engine = engine,
      super(const ThreadAudioState()) {
    _subs = <StreamSubscription<void>>[
      _engine.playingStream.listen(
        (playing) => emit(state.copyWith(playing: playing)),
      ),
      _engine.positionStream.listen(
        (position) => emit(state.copyWith(position: position)),
      ),
      _engine.durationStream.listen(
        (duration) => emit(state.copyWith(duration: duration)),
      ),
      _engine.completedStream.listen(
        (_) => emit(
          ThreadAudioState(
            sourceKey: state.sourceKey,
            duration: state.duration,
            speed: state.speed,
            failedKey: state.failedKey,
          ),
        ),
      ),
    ];
  }

  final AudioEngine _engine;
  late final List<StreamSubscription<void>> _subs;

  /// Tap en la burbuja de audio [key] (su `mediaRef`): fuente nueva ⇒ cargar y
  /// reproducir (pausa la anterior por construcción — un solo engine); la misma
  /// fuente alterna play/pausa conservando posición.
  ///
  /// Prefiere [bytes] (la copia local) sobre [url] (streaming firmado): el
  /// archivo completo hace que el transporte reporte la duración de inmediato
  /// (barra de progreso viva). Si cargar los bytes falla (formato/copia
  /// ilegible), degrada al streaming de [url] —no peor que sin caché—. En
  /// play/pausa de la fuente ya activa, [bytes]/[url] son irrelevantes.
  Future<void> toggle(
    String key, {
    Uint8List? bytes,
    String? url,
    String contentType = 'audio/ogg',
  }) async {
    try {
      if (state.sourceKey != key) {
        final speed = state.speed;
        await _load(bytes: bytes, url: url, contentType: contentType);
        emit(
          ThreadAudioState(
            sourceKey: key,
            // position/duration arrancan de cero para la fuente nueva; los
            // streams del engine los actualizan enseguida. La velocidad del
            // hilo se conserva y se reasienta abajo (just_audio la resetea a
            // 1.0 al cargar una fuente).
            speed: speed,
            failedKey: state.failedKey,
          ),
        );
        await _engine.setSpeed(speed);
        await _engine.play();
        return;
      }
      if (state.playing) {
        await _engine.pause();
      } else {
        await _engine.play();
      }
    } on Exception {
      // Transporte/formato caído (sin bytes ni URL viva, plataforma sin
      // plugin…): señalar la fuente fallida sin tirar el estado previo.
      emit(state.copyWith(failedKey: key));
    }
  }

  /// Carga la fuente nueva en el engine: bytes locales primero; si fallan,
  /// degrada al streaming de la URL. Lanza si no queda ninguna fuente viable
  /// (lo atrapa [toggle] y marca `failedKey`).
  Future<void> _load({
    Uint8List? bytes,
    String? url,
    required String contentType,
  }) async {
    if (bytes != null) {
      try {
        await _engine.setBytes(bytes, contentType);
        return;
      } on Exception {
        // Copia local ilegible / formato no soportado: cae al streaming si hay
        // URL; si no, re-lanza para que toggle marque el fallo.
        if (url == null) rethrow;
      }
    }
    if (url == null) throw Exception('sin fuente de audio');
    await _engine.setUrl(url);
  }

  /// Velocidades de reproducción disponibles, en orden de ciclo.
  static const List<double> _speeds = <double>[1.0, 1.5, 2.0];

  /// Avanza a la siguiente velocidad (1x → 1.5x → 2x → 1x) y la fija en el
  /// engine. Un fallo de la plataforma no altera el estado.
  Future<void> cycleSpeed() async {
    final i = _speeds.indexOf(state.speed);
    final next = _speeds[(i + 1) % _speeds.length];
    try {
      await _engine.setSpeed(next);
      emit(state.copyWith(speed: next));
    } on Exception {
      // Sin player en la plataforma: la velocidad no cambia.
    }
  }

  /// Salta a [position] dentro de la fuente activa (scrubbing). Emite la
  /// posición saltada tras el seek del engine; la barra conserva el valor
  /// soltado hasta entonces, de modo que no parpadea de regreso.
  Future<void> seek(Duration position) async {
    try {
      await _engine.seek(position);
      emit(state.copyWith(position: position));
    } on Exception {
      // Sin player en la plataforma: el scrubbing no aplica.
    }
  }

  @override
  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _engine.dispose();
    return super.close();
  }
}
