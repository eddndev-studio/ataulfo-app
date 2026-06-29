// StreamAudioSource/StreamAudioResponse están marcados @experimental en
// just_audio, pero son la vía canónica para reproducir bytes en memoria y la
// versión del paquete está fijada (pin en pubspec): el cambio de API se absorbe
// en una actualización controlada, no en silencio.
// ignore_for_file: experimental_member_use
import 'dart:typed_data';

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
  Future<void> setBytes(Uint8List bytes, String contentType) async {
    await _player.setAudioSource(_BytesAudioSource(bytes, contentType));
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

/// Fuente de just_audio respaldada por bytes en memoria: sirve el clip COMPLETO
/// (honra los range requests del player) con un content-type explícito, así el
/// extractor abre el contenedor y reporta la duración de una. Es lo que hace que
/// reproducir la copia local —no streamear la URL firmada— reviva la barra de
/// progreso de las notas Ogg/Opus.
class _BytesAudioSource extends ja.StreamAudioSource {
  _BytesAudioSource(this._bytes, this._contentType);

  final Uint8List _bytes;
  final String _contentType;

  @override
  Future<ja.StreamAudioResponse> request([int? start, int? end]) async {
    final from = start ?? 0;
    final to = end ?? _bytes.length;
    return ja.StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: to - from,
      offset: from,
      stream: Stream<List<int>>.value(_bytes.sublist(from, to)),
      contentType: _contentType,
    );
  }
}
