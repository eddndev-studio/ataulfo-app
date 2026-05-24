import 'package:agentic/features/bots/domain/entities/bot.dart';
import 'package:agentic/features/bots/domain/failures/bots_failure.dart';
import 'package:agentic/features/bots/domain/repositories/bots_repository.dart';
import 'package:agentic/features/bots/presentation/bloc/bots_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements BotsRepository {}

const _b1 = Bot(
  id: 'b1',
  orgId: 'o1',
  templateId: 't1',
  name: 'Soporte',
  channel: BotChannel.waUnofficial,
  identifier: '52155...',
  version: 3,
  paused: false,
  aiDisabled: false,
);
const _b2 = Bot(
  id: 'b2',
  orgId: 'o1',
  templateId: 't1',
  name: 'Cobranza',
  channel: BotChannel.waba,
  identifier: null,
  version: 1,
  paused: true,
  aiDisabled: false,
);

void main() {
  group('BotsBloc', () {
    test('estado inicial = BotsInitial', () {
      final bloc = BotsBloc(_MockRepo());
      expect(bloc.state, const BotsInitial());
    });

    group('BotsLoadRequested', () {
      blocTest<BotsBloc, BotsState>(
        'list() ok → [Loading, Loaded(items, isRefreshing: false)]',
        build: () {
          final repo = _MockRepo();
          when(repo.list).thenAnswer((_) async => const <Bot>[_b1, _b2]);
          return BotsBloc(repo);
        },
        act: (bloc) => bloc.add(const BotsLoadRequested()),
        expect: () => const <BotsState>[
          BotsLoading(),
          BotsLoaded(items: <Bot>[_b1, _b2], isRefreshing: false),
        ],
      );

      blocTest<BotsBloc, BotsState>(
        'list() ok con [] → [Loading, Loaded(empty)]',
        build: () {
          final repo = _MockRepo();
          when(repo.list).thenAnswer((_) async => const <Bot>[]);
          return BotsBloc(repo);
        },
        act: (bloc) => bloc.add(const BotsLoadRequested()),
        expect: () => const <BotsState>[
          BotsLoading(),
          BotsLoaded(items: <Bot>[], isRefreshing: false),
        ],
      );

      blocTest<BotsBloc, BotsState>(
        '403 → [Loading, Failed(Forbidden)]',
        build: () {
          final repo = _MockRepo();
          when(
            repo.list,
          ).thenAnswer((_) => Future<List<Bot>>.error(const BotsForbiddenFailure()));
          return BotsBloc(repo);
        },
        act: (bloc) => bloc.add(const BotsLoadRequested()),
        expect: () => const <BotsState>[
          BotsLoading(),
          BotsFailed(BotsForbiddenFailure()),
        ],
      );

      blocTest<BotsBloc, BotsState>(
        'network → [Loading, Failed(Network)]',
        build: () {
          final repo = _MockRepo();
          when(
            repo.list,
          ).thenAnswer((_) => Future<List<Bot>>.error(const BotsNetworkFailure()));
          return BotsBloc(repo);
        },
        act: (bloc) => bloc.add(const BotsLoadRequested()),
        expect: () => const <BotsState>[
          BotsLoading(),
          BotsFailed(BotsNetworkFailure()),
        ],
      );
    });

    group('BotsRefreshRequested', () {
      blocTest<BotsBloc, BotsState>(
        'desde Loaded → emite Loaded(prev, isRefreshing: true) y luego Loaded(nuevos, false)',
        build: () {
          final repo = _MockRepo();
          when(repo.list).thenAnswer((_) async => const <Bot>[_b2]);
          return BotsBloc(repo);
        },
        seed: () =>
            const BotsLoaded(items: <Bot>[_b1], isRefreshing: false),
        act: (bloc) => bloc.add(const BotsRefreshRequested()),
        expect: () => const <BotsState>[
          BotsLoaded(items: <Bot>[_b1], isRefreshing: true),
          BotsLoaded(items: <Bot>[_b2], isRefreshing: false),
        ],
      );

      blocTest<BotsBloc, BotsState>(
        'desde Loaded con error de red → mantiene lista visible y emite Failed',
        // Decisión: con la lista ya en memoria, un refresh que falla DEBE
        // mostrar el error sin descartar lo que el operador ya estaba viendo.
        // El widget puede ofrecer reintento manteniendo el contexto.
        build: () {
          final repo = _MockRepo();
          when(
            repo.list,
          ).thenAnswer((_) => Future<List<Bot>>.error(const BotsNetworkFailure()));
          return BotsBloc(repo);
        },
        seed: () =>
            const BotsLoaded(items: <Bot>[_b1], isRefreshing: false),
        act: (bloc) => bloc.add(const BotsRefreshRequested()),
        expect: () => const <BotsState>[
          BotsLoaded(items: <Bot>[_b1], isRefreshing: true),
          BotsFailed(BotsNetworkFailure()),
        ],
      );

      blocTest<BotsBloc, BotsState>(
        'desde Initial cae a load (no hay prev para refrescar)',
        build: () {
          final repo = _MockRepo();
          when(repo.list).thenAnswer((_) async => const <Bot>[_b1]);
          return BotsBloc(repo);
        },
        act: (bloc) => bloc.add(const BotsRefreshRequested()),
        expect: () => const <BotsState>[
          BotsLoading(),
          BotsLoaded(items: <Bot>[_b1], isRefreshing: false),
        ],
      );
    });
  });

  group('BotsLoaded value-equality', () {
    test('Loaded con misma lista y mismo isRefreshing son iguales', () {
      const a = BotsLoaded(items: <Bot>[_b1], isRefreshing: false);
      const b = BotsLoaded(items: <Bot>[_b1], isRefreshing: false);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('difieren si isRefreshing cambia', () {
      const a = BotsLoaded(items: <Bot>[_b1], isRefreshing: false);
      const b = BotsLoaded(items: <Bot>[_b1], isRefreshing: true);
      expect(a, isNot(b));
    });

    test('difieren si la lista cambia', () {
      const a = BotsLoaded(items: <Bot>[_b1], isRefreshing: false);
      const b = BotsLoaded(items: <Bot>[_b1, _b2], isRefreshing: false);
      expect(a, isNot(b));
    });
  });
}
