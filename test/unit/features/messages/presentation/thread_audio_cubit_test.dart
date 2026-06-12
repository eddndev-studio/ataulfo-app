import 'dart:async';

import 'package:ataulfo/features/messages/domain/repositories/audio_engine.dart';
import 'package:ataulfo/features/messages/presentation/bloc/thread_audio_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Engine fake: registra llamadas y expone los streams para empujar eventos
/// desde el test (lo que haría el plugin real).
class _FakeEngine implements AudioEngine {
  final List<String> calls = <String>[];
  bool failSetUrl = false;

  final StreamController<bool> playing = StreamController<bool>.broadcast();
  final StreamController<Duration> position =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> duration =
      StreamController<Duration?>.broadcast();
  final StreamController<void> completed = StreamController<void>.broadcast();

  @override
  Future<void> setUrl(String url) async {
    calls.add('setUrl:$url');
    if (failSetUrl) throw Exception('formato no soportado');
  }

  @override
  Future<void> play() async {
    calls.add('play');
    playing.add(true);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    playing.add(false);
  }

  @override
  Stream<bool> get playingStream => playing.stream;
  @override
  Stream<Duration> get positionStream => position.stream;
  @override
  Stream<Duration?> get durationStream => duration.stream;
  @override
  Stream<void> get completedStream => completed.stream;

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    await playing.close();
    await position.close();
    await duration.close();
    await completed.close();
  }
}

void main() {
  late _FakeEngine engine;
  late ThreadAudioCubit cubit;

  setUp(() {
    engine = _FakeEngine();
    cubit = ThreadAudioCubit(engine: engine);
  });

  tearDown(() async {
    await cubit.close();
  });

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  test(
    'toggle con fuente nueva: setUrl + play y el estado adopta la url',
    () async {
      await cubit.toggle('https://m/a.ogg');
      await pump();

      expect(
        engine.calls,
        containsAllInOrder(<String>['setUrl:https://m/a.ogg', 'play']),
      );
      expect(cubit.state.url, 'https://m/a.ogg');
      expect(cubit.state.playing, isTrue);
    },
  );

  test(
    'toggle sobre la misma url reproduciendo pausa (sin re-setUrl)',
    () async {
      await cubit.toggle('https://m/a.ogg');
      await pump();
      engine.calls.clear();

      await cubit.toggle('https://m/a.ogg');
      await pump();

      expect(engine.calls, <String>['pause']);
      expect(cubit.state.playing, isFalse);
    },
  );

  test('toggle sobre la misma url pausada reanuda donde iba', () async {
    await cubit.toggle('https://m/a.ogg');
    await pump();
    await cubit.toggle('https://m/a.ogg'); // pausa
    await pump();
    engine.calls.clear();

    await cubit.toggle('https://m/a.ogg');
    await pump();

    expect(engine.calls, <String>['play']); // ni setUrl ni reinicio
    expect(cubit.state.playing, isTrue);
  });

  test('cambiar de fuente re-carga: setUrl de la nueva y play', () async {
    await cubit.toggle('https://m/a.ogg');
    await pump();
    engine.calls.clear();

    await cubit.toggle('https://m/b.ogg');
    await pump();

    expect(
      engine.calls,
      containsAllInOrder(<String>['setUrl:https://m/b.ogg', 'play']),
    );
    expect(cubit.state.url, 'https://m/b.ogg');
  });

  test('posición y duración del engine fluyen al estado', () async {
    await cubit.toggle('https://m/a.ogg');
    await pump();

    engine.duration.add(const Duration(seconds: 30));
    engine.position.add(const Duration(seconds: 7));
    await pump();

    expect(cubit.state.duration, const Duration(seconds: 30));
    expect(cubit.state.position, const Duration(seconds: 7));
  });

  test(
    'al completar: deja de reproducir y la posición vuelve a cero',
    () async {
      await cubit.toggle('https://m/a.ogg');
      await pump();
      engine.position.add(const Duration(seconds: 30));
      engine.completed.add(null);
      await pump();

      expect(cubit.state.playing, isFalse);
      expect(cubit.state.position, Duration.zero);
    },
  );

  test(
    'si el engine falla al cargar, señala failedUrl y no adopta la fuente',
    () async {
      engine.failSetUrl = true;

      await cubit.toggle('https://m/rota.ogg');
      await pump();

      expect(cubit.state.failedUrl, 'https://m/rota.ogg');
      expect(cubit.state.url, isNull);
      expect(cubit.state.playing, isFalse);
    },
  );

  test('close dispone el engine', () async {
    await cubit.close();
    expect(engine.calls, contains('dispose'));
  });
}
