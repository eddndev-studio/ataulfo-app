import 'dart:async';
import 'dart:typed_data';

import 'package:ataulfo/features/messages/domain/repositories/audio_engine.dart';
import 'package:ataulfo/features/messages/presentation/bloc/thread_audio_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Engine fake: registra llamadas y expone los streams para empujar eventos
/// desde el test (lo que haría el plugin real).
class _FakeEngine implements AudioEngine {
  final List<String> calls = <String>[];
  bool failSetUrl = false;
  bool failSetBytes = false;

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
  Future<void> setBytes(Uint8List bytes, String contentType) async {
    calls.add('setBytes:${bytes.length}:$contentType');
    if (failSetBytes) throw Exception('copia local ilegible');
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
  Future<void> seek(Duration position) async {
    calls.add('seek:${position.inMilliseconds}');
  }

  @override
  Future<void> setSpeed(double speed) async {
    calls.add('setSpeed:$speed');
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

  final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

  setUp(() {
    engine = _FakeEngine();
    cubit = ThreadAudioCubit(engine: engine);
  });

  tearDown(() async {
    await cubit.close();
  });

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  test(
    'toggle con bytes: setBytes + play; el estado adopta el mediaRef (sin setUrl)',
    () async {
      await cubit.toggle('ref-a', bytes: bytes, url: 'https://m/a.ogg');
      await pump();

      expect(
        engine.calls,
        containsAllInOrder(<String>['setBytes:4:audio/ogg', 'play']),
      );
      expect(engine.calls, isNot(contains('setUrl:https://m/a.ogg')));
      expect(cubit.state.sourceKey, 'ref-a');
      expect(cubit.state.playing, isTrue);
    },
  );

  test('toggle sin bytes cae al streaming de la url', () async {
    await cubit.toggle('ref-a', url: 'https://m/a.ogg');
    await pump();

    expect(
      engine.calls,
      containsAllInOrder(<String>['setUrl:https://m/a.ogg', 'play']),
    );
    expect(cubit.state.sourceKey, 'ref-a');
  });

  test('si setBytes falla pero hay url, degrada al streaming', () async {
    engine.failSetBytes = true;

    await cubit.toggle('ref-a', bytes: bytes, url: 'https://m/a.ogg');
    await pump();

    // Intenta los bytes, falla, y cae a la URL sin tirar la reproducción.
    expect(
      engine.calls,
      containsAllInOrder(<String>[
        'setBytes:4:audio/ogg',
        'setUrl:https://m/a.ogg',
        'play',
      ]),
    );
    expect(cubit.state.sourceKey, 'ref-a');
    expect(cubit.state.failedKey, isNull);
  });

  test(
    'si setBytes falla y no hay url, marca failedKey y no adopta la fuente',
    () async {
      engine.failSetBytes = true;

      await cubit.toggle('ref-a', bytes: bytes);
      await pump();

      expect(cubit.state.failedKey, 'ref-a');
      expect(cubit.state.sourceKey, isNull);
      expect(cubit.state.playing, isFalse);
    },
  );

  test('toggle sin bytes y sin url marca failedKey', () async {
    await cubit.toggle('ref-a');
    await pump();

    expect(cubit.state.failedKey, 'ref-a');
    expect(cubit.state.sourceKey, isNull);
  });

  test('toggle sobre el mismo ref reproduciendo pausa (sin re-cargar)', () async {
    await cubit.toggle('ref-a', bytes: bytes);
    await pump();
    engine.calls.clear();

    await cubit.toggle('ref-a');
    await pump();

    expect(engine.calls, <String>['pause']);
    expect(cubit.state.playing, isFalse);
  });

  test('toggle sobre el mismo ref pausado reanuda donde iba', () async {
    await cubit.toggle('ref-a', bytes: bytes);
    await pump();
    await cubit.toggle('ref-a'); // pausa
    await pump();
    engine.calls.clear();

    await cubit.toggle('ref-a');
    await pump();

    expect(engine.calls, <String>['play']); // ni re-carga ni reinicio
    expect(cubit.state.playing, isTrue);
  });

  test('cambiar de fuente re-carga: setBytes de la nueva y play', () async {
    await cubit.toggle('ref-a', bytes: bytes);
    await pump();
    engine.calls.clear();

    final other = Uint8List.fromList(<int>[9, 9]);
    await cubit.toggle('ref-b', bytes: other);
    await pump();

    expect(
      engine.calls,
      containsAllInOrder(<String>['setBytes:2:audio/ogg', 'play']),
    );
    expect(cubit.state.sourceKey, 'ref-b');
  });

  test('posición y duración del engine fluyen al estado', () async {
    await cubit.toggle('ref-a', bytes: bytes);
    await pump();

    engine.duration.add(const Duration(seconds: 30));
    engine.position.add(const Duration(seconds: 7));
    await pump();

    expect(cubit.state.duration, const Duration(seconds: 30));
    expect(cubit.state.position, const Duration(seconds: 7));
  });

  test('al completar: deja de reproducir y la posición vuelve a cero', () async {
    await cubit.toggle('ref-a', bytes: bytes);
    await pump();
    engine.position.add(const Duration(seconds: 30));
    engine.completed.add(null);
    await pump();

    expect(cubit.state.playing, isFalse);
    expect(cubit.state.position, Duration.zero);
  });

  test(
    'si el engine falla al cargar la url, señala failedKey y no adopta la fuente',
    () async {
      engine.failSetUrl = true;

      await cubit.toggle('ref-rota', url: 'https://m/rota.ogg');
      await pump();

      expect(cubit.state.failedKey, 'ref-rota');
      expect(cubit.state.sourceKey, isNull);
      expect(cubit.state.playing, isFalse);
    },
  );

  test('cycleSpeed alterna 1x→1.5x→2x→1x y lo fija en el engine', () async {
    await cubit.toggle('ref-a', bytes: bytes);
    await pump();
    engine.calls.clear();

    await cubit.cycleSpeed();
    expect(cubit.state.speed, 1.5);
    await cubit.cycleSpeed();
    expect(cubit.state.speed, 2.0);
    await cubit.cycleSpeed();
    expect(cubit.state.speed, 1.0);

    expect(engine.calls, <String>[
      'setSpeed:1.5',
      'setSpeed:2.0',
      'setSpeed:1.0',
    ]);
  });

  test('una fuente nueva conserva la velocidad elegida y la reasienta', () async {
    await cubit.toggle('ref-a', bytes: bytes);
    await pump();
    await cubit.cycleSpeed(); // 1.5
    engine.calls.clear();

    await cubit.toggle('ref-b', bytes: bytes);
    await pump();

    expect(cubit.state.speed, 1.5);
    expect(
      engine.calls,
      containsAllInOrder(<String>['setBytes:4:audio/ogg', 'setSpeed:1.5', 'play']),
    );
  });

  test('al completar conserva la velocidad', () async {
    await cubit.toggle('ref-a', bytes: bytes);
    await pump();
    await cubit.cycleSpeed(); // 1.5
    engine.completed.add(null);
    await pump();

    expect(cubit.state.speed, 1.5);
    expect(cubit.state.position, Duration.zero);
  });

  test('seek salta en el engine y refleja la posición', () async {
    await cubit.toggle('ref-a', bytes: bytes);
    await pump();
    engine.calls.clear();

    await cubit.seek(const Duration(seconds: 12));

    expect(engine.calls, contains('seek:12000'));
    expect(cubit.state.position, const Duration(seconds: 12));
  });

  test('close dispone el engine', () async {
    await cubit.close();
    expect(engine.calls, contains('dispose'));
  });
}
