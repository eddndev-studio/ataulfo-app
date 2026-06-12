import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/audio_engine.dart';

/// Estado de la reproducción de audio del hilo. Hay UN player por hilo
/// (modelo de mensajería): [url] es la fuente activa; cada burbuja de audio
/// se pinta como "suya" sólo si su URL coincide.
class ThreadAudioState {
  const ThreadAudioState({
    this.url,
    this.playing = false,
    this.position = Duration.zero,
    this.duration,
    this.failedUrl,
  });

  /// Fuente cargada en el player (`null` = nada sonó aún).
  final String? url;

  final bool playing;

  final Duration position;

  /// `null` mientras el transporte no conoce la duración.
  final Duration? duration;

  /// Última URL que no se pudo cargar/reproducir — la UI lo anuncia y este
  /// campo se conserva hasta el siguiente intento (cambia ⇒ nuevo aviso).
  final String? failedUrl;

  ThreadAudioState copyWith({
    String? url,
    bool? playing,
    Duration? position,
    Duration? duration,
    String? failedUrl,
  }) => ThreadAudioState(
    url: url ?? this.url,
    playing: playing ?? this.playing,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    failedUrl: failedUrl ?? this.failedUrl,
  );

  @override
  bool operator ==(Object other) =>
      other is ThreadAudioState &&
      other.url == url &&
      other.playing == playing &&
      other.position == position &&
      other.duration == duration &&
      other.failedUrl == failedUrl;

  @override
  int get hashCode => Object.hash(url, playing, position, duration, failedUrl);
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
            url: state.url,
            duration: state.duration,
            failedUrl: state.failedUrl,
          ),
        ),
      ),
    ];
  }

  final AudioEngine _engine;
  late final List<StreamSubscription<void>> _subs;

  /// Tap en la burbuja de audio [url]: fuente nueva ⇒ cargar y reproducir
  /// (pausa la anterior por construcción — un solo engine); la misma fuente
  /// alterna play/pausa conservando posición.
  Future<void> toggle(String url) async {
    try {
      if (state.url != url) {
        await _engine.setUrl(url);
        emit(
          ThreadAudioState(
            url: url,
            // position/duration arrancan de cero para la fuente nueva; los
            // streams del engine los actualizan enseguida.
            failedUrl: state.failedUrl,
          ),
        );
        await _engine.play();
        return;
      }
      if (state.playing) {
        await _engine.pause();
      } else {
        await _engine.play();
      }
    } on Exception {
      // Transporte/formato caído (URL firmada expirada, plataforma sin
      // plugin…): señalar la URL fallida sin tirar el estado previo.
      emit(state.copyWith(failedUrl: url));
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
