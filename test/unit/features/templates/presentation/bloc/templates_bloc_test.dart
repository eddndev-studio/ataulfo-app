import 'package:agentic/features/templates/domain/entities/template.dart';
import 'package:agentic/features/templates/domain/failures/templates_failure.dart';
import 'package:agentic/features/templates/domain/repositories/templates_repository.dart';
import 'package:agentic/features/templates/presentation/bloc/templates_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements TemplatesRepository {}

const _ai = AIConfig(
  enabled: false,
  provider: AIProvider.gemini,
  model: 'gemini-3.1-pro-preview',
  temperature: 0.7,
  thinkingLevel: ThinkingLevel.low,
  systemPrompt: '',
  contextMessages: 20,
);

const _t1 = Template(
  id: 't1',
  orgId: 'o1',
  name: 'Soporte',
  version: 1,
  ai: _ai,
);
const _t2 = Template(
  id: 't2',
  orgId: 'o1',
  name: 'Ventas',
  version: 3,
  ai: _ai,
);

void main() {
  group('TemplatesBloc', () {
    test('estado inicial = TemplatesInitial', () {
      final bloc = TemplatesBloc(_MockRepo());
      expect(bloc.state, const TemplatesInitial());
    });

    group('TemplatesLoadRequested', () {
      blocTest<TemplatesBloc, TemplatesState>(
        'list() ok → [Loading, Loaded(items, isRefreshing: false)]',
        build: () {
          final repo = _MockRepo();
          when(repo.list).thenAnswer((_) async => const <Template>[_t1, _t2]);
          return TemplatesBloc(repo);
        },
        act: (bloc) => bloc.add(const TemplatesLoadRequested()),
        expect: () => const <TemplatesState>[
          TemplatesLoading(),
          TemplatesLoaded(items: <Template>[_t1, _t2], isRefreshing: false),
        ],
      );

      blocTest<TemplatesBloc, TemplatesState>(
        'list() ok con [] → [Loading, Loaded(empty)]',
        build: () {
          final repo = _MockRepo();
          when(repo.list).thenAnswer((_) async => const <Template>[]);
          return TemplatesBloc(repo);
        },
        act: (bloc) => bloc.add(const TemplatesLoadRequested()),
        expect: () => const <TemplatesState>[
          TemplatesLoading(),
          TemplatesLoaded(items: <Template>[], isRefreshing: false),
        ],
      );

      blocTest<TemplatesBloc, TemplatesState>(
        '403 → [Loading, Failed(Forbidden)]',
        build: () {
          final repo = _MockRepo();
          when(repo.list).thenAnswer(
            (_) => Future<List<Template>>.error(
              const TemplatesForbiddenFailure(),
            ),
          );
          return TemplatesBloc(repo);
        },
        act: (bloc) => bloc.add(const TemplatesLoadRequested()),
        expect: () => const <TemplatesState>[
          TemplatesLoading(),
          TemplatesFailed(TemplatesForbiddenFailure()),
        ],
      );

      blocTest<TemplatesBloc, TemplatesState>(
        'network → [Loading, Failed(Network)]',
        build: () {
          final repo = _MockRepo();
          when(repo.list).thenAnswer(
            (_) => Future<List<Template>>.error(
              const TemplatesNetworkFailure(),
            ),
          );
          return TemplatesBloc(repo);
        },
        act: (bloc) => bloc.add(const TemplatesLoadRequested()),
        expect: () => const <TemplatesState>[
          TemplatesLoading(),
          TemplatesFailed(TemplatesNetworkFailure()),
        ],
      );
    });

    group('TemplatesRefreshRequested', () {
      blocTest<TemplatesBloc, TemplatesState>(
        'desde Loaded → emite Loaded(prev, isRefreshing: true) y luego '
        'Loaded(nuevos, false)',
        build: () {
          final repo = _MockRepo();
          when(repo.list).thenAnswer((_) async => const <Template>[_t2]);
          return TemplatesBloc(repo);
        },
        seed: () =>
            const TemplatesLoaded(items: <Template>[_t1], isRefreshing: false),
        act: (bloc) => bloc.add(const TemplatesRefreshRequested()),
        expect: () => const <TemplatesState>[
          TemplatesLoaded(items: <Template>[_t1], isRefreshing: true),
          TemplatesLoaded(items: <Template>[_t2], isRefreshing: false),
        ],
      );

      blocTest<TemplatesBloc, TemplatesState>(
        'desde Loaded con error de red → mantiene lista visible y emite Failed',
        // Decisión espejo de bots: con la lista ya en memoria, un refresh
        // que falla DEBE mostrar el error sin descartar lo que el operador
        // ya estaba viendo. El widget puede ofrecer reintento manteniendo
        // el contexto.
        build: () {
          final repo = _MockRepo();
          when(repo.list).thenAnswer(
            (_) => Future<List<Template>>.error(
              const TemplatesNetworkFailure(),
            ),
          );
          return TemplatesBloc(repo);
        },
        seed: () =>
            const TemplatesLoaded(items: <Template>[_t1], isRefreshing: false),
        act: (bloc) => bloc.add(const TemplatesRefreshRequested()),
        expect: () => const <TemplatesState>[
          TemplatesLoaded(items: <Template>[_t1], isRefreshing: true),
          TemplatesFailed(TemplatesNetworkFailure()),
        ],
      );

      blocTest<TemplatesBloc, TemplatesState>(
        'desde Initial cae a load (no hay prev para refrescar)',
        build: () {
          final repo = _MockRepo();
          when(repo.list).thenAnswer((_) async => const <Template>[_t1]);
          return TemplatesBloc(repo);
        },
        act: (bloc) => bloc.add(const TemplatesRefreshRequested()),
        expect: () => const <TemplatesState>[
          TemplatesLoading(),
          TemplatesLoaded(items: <Template>[_t1], isRefreshing: false),
        ],
      );
    });
  });

  group('TemplatesLoaded value-equality', () {
    test('Loaded con misma lista y mismo isRefreshing son iguales', () {
      const a = TemplatesLoaded(items: <Template>[_t1], isRefreshing: false);
      const b = TemplatesLoaded(items: <Template>[_t1], isRefreshing: false);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('difieren si isRefreshing cambia', () {
      const a = TemplatesLoaded(items: <Template>[_t1], isRefreshing: false);
      const b = TemplatesLoaded(items: <Template>[_t1], isRefreshing: true);
      expect(a, isNot(b));
    });

    test('difieren si la lista cambia', () {
      const a = TemplatesLoaded(items: <Template>[_t1], isRefreshing: false);
      const b = TemplatesLoaded(
        items: <Template>[_t1, _t2],
        isRefreshing: false,
      );
      expect(a, isNot(b));
    });
  });
}
