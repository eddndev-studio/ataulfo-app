import 'dart:typed_data';

import 'package:ataulfo/features/messages/domain/repositories/audio_engine.dart';
import 'package:ataulfo/features/messages/domain/repositories/media_opener.dart';
import 'package:ataulfo/features/messages/domain/repositories/media_sharer.dart';

/// Engine de audio inerte: deja montar el hilo (y su `ThreadAudioCubit`)
/// en tests sin plugin de plataforma. Los streams vacíos nunca emiten, así
/// que `pumpAndSettle` termina.
class FakeAudioEngine implements AudioEngine {
  const FakeAudioEngine();

  @override
  Future<void> setUrl(String url) async {}

  @override
  Future<void> setBytes(Uint8List bytes, String contentType) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Stream<bool> get playingStream => const Stream<bool>.empty();

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Stream<Duration?> get durationStream => const Stream<Duration?>.empty();

  @override
  Stream<void> get completedStream => const Stream<void>.empty();

  @override
  Future<void> dispose() async {}
}

/// Abridor de media no-op para el wiring de rutas en tests.
class FakeMediaOpener implements MediaOpener {
  const FakeMediaOpener();

  @override
  Future<void> open({required String url}) async {}
}

/// Compartidor de media no-op para el wiring de rutas en tests.
class FakeMediaSharer implements MediaSharer {
  const FakeMediaSharer();

  @override
  Future<void> share({
    required Uint8List bytes,
    required String filename,
  }) async {}
}
