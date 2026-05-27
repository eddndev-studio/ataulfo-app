import 'package:agentic/features/flows/domain/entities/flow.dart';
import 'package:agentic/features/flows/domain/failures/flows_failure.dart';
import 'package:agentic/features/flows/domain/repositories/flows_repository.dart';
import 'package:agentic/features/flows/presentation/bloc/flow_detail_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements FlowsRepository {}

const _flow = Flow(
  id: 'f1',
  templateId: 't1',
  name: 'Bienvenida',
  isActive: true,
  version: 3,
  cooldownMs: 0,
  usageLimit: 0,
  excludesFlows: <String>[],
);

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  group('FlowDetailBloc', () {
    test('estado inicial = Loading (sin flash de Initial)', () {
      final bloc = FlowDetailBloc(repo: repo, id: 'f1');
      expect(bloc.state, const FlowDetailLoading());
      bloc.close();
    });

    blocTest<FlowDetailBloc, FlowDetailState>(
      'LoadRequested ok → Loaded(flow)',
      build: () {
        when(() => repo.flowById('f1')).thenAnswer((_) async => _flow);
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      act: (bloc) => bloc.add(const FlowDetailLoadRequested()),
      expect: () => const <FlowDetailState>[FlowDetailLoaded(_flow)],
      verify: (_) {
        verify(() => repo.flowById('f1')).called(1);
      },
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      'flowById falla con NotFound → Failed(NotFound)',
      build: () {
        when(
          () => repo.flowById('f1'),
        ).thenAnswer((_) => Future<Flow>.error(const FlowsNotFoundFailure()));
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      act: (bloc) => bloc.add(const FlowDetailLoadRequested()),
      expect: () => const <FlowDetailState>[
        FlowDetailFailed(FlowsNotFoundFailure()),
      ],
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      'flowById falla con ServerFailure → Failed(Server)',
      build: () {
        when(
          () => repo.flowById('f1'),
        ).thenAnswer((_) => Future<Flow>.error(const FlowsServerFailure()));
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      act: (bloc) => bloc.add(const FlowDetailLoadRequested()),
      expect: () => const <FlowDetailState>[
        FlowDetailFailed(FlowsServerFailure()),
      ],
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      'retry desde Failed re-emite Loading visible y luego Loaded',
      build: () {
        var calls = 0;
        when(() => repo.flowById('f1')).thenAnswer((_) {
          calls++;
          if (calls == 1) {
            return Future<Flow>.error(const FlowsServerFailure());
          }
          return Future<Flow>.value(_flow);
        });
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      act: (bloc) async {
        bloc.add(const FlowDetailLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const FlowDetailLoadRequested());
      },
      expect: () => const <FlowDetailState>[
        FlowDetailFailed(FlowsServerFailure()),
        FlowDetailLoading(),
        FlowDetailLoaded(_flow),
      ],
    );

    test('Loaded value-equality', () {
      const a = FlowDetailLoaded(_flow);
      const b = FlowDetailLoaded(_flow);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}
