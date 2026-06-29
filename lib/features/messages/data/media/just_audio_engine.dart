import 'package:just_audio/just_audio.dart' as ja;

import '../../domain/repositories/audio_engine.dart';

/// [AudioEngine] sobre just_audio (ExoPlayer en Android: cubre el opus/ogg
/// de las notas de voz de WhatsApp). Adaptador fino sin lógica propia: el
/// mapeo de streams es 1:1 y la política (un player, toggle, fallos) vive en
/// `ThreadAudioCubit`. En plataformas sin implementación del plugin las
/// llamadas lanzan y el cubit lo degrada a aviso.
class JustAudioEngine implements AudioEngine {
  JustAudioEngine([ja.AudioPlayer? player])
    : _player = player ?? ja.AudioPlayer();

  final ja.AudioPlayer _player;

  @override
  Future<void> setUrl(String url) async {
    await _player.setUrl(url);
  }

  @override
  Future<void> play() async {
    // El play() de just_audio al COMPLETAR la fuente resuelve sin reiniciar;
    // re-tocar una nota terminada debe sonar desde el inicio.
    if (_player.processingState == ja.ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<void> get completedStream => _player.processingStateStream.where(
    (s) => s == ja.ProcessingState.completed,
  );

  @override
  Future<void> dispose() => _player.dispose();
}
