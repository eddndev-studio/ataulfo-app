import 'package:ataulfo/features/flows/domain/entities/flow.dart';
import 'package:ataulfo/features/flows/domain/failures/flows_failure.dart';
import 'package:ataulfo/features/flows/domain/repositories/flows_repository.dart';
import 'package:ataulfo/features/flows/presentation/bloc/flow_create_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements FlowsRepository {}

const _flow = Flow(
  id: 'f-new',
  templateId: 't1',
  name: 'Bienvenida',
  isActive: true,
  version: 1,
  cooldownMs: 0,
  usageLimit: 0,
  excludesFlows: <String>[],
);

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  group('FlowCreateBloc', () {
    test('estado inicial = Initial', () {
      final bloc = FlowCreateBloc(repo: repo, templateId: 't1');
      expect(bloc.state, const FlowCreateInitial());
      bloc.close();
    });

    blocTest<FlowCreateBloc, FlowCreateState>(
      'Submitted ok → Submitting → Succeeded(flow)',
      build: () {
        when(
          () => repo.createFlow(templateId: 't1', name: 'Bienvenida'),
        ).thenAnswer((_) async => _flow);
        return FlowCreateBloc(repo: repo, templateId: 't1');
      },
      act: (bloc) => bloc.add(const FlowCreateSubmitted(name: 'Bienvenida')),
      expect: () => const <FlowCreateState>[
        FlowCreateSubmitting(),
        FlowCreateSucceeded(_flow),
      ],
      verify: (_) => verify(
        () => repo.createFlow(templateId: 't1', name: 'Bienvenida'),
      ).called(1),
    );

    blocTest<FlowCreateBloc, FlowCreateState>(
      'Submitted con nombre vacío → Submitting → Failed(InvalidCreate)',
      build: () {
        when(
          () => repo.createFlow(templateId: 't1', name: ''),
        ).thenThrow(const FlowsInvalidCreateFailure());
        return FlowCreateBloc(repo: repo, templateId: 't1');
      },
      act: (bloc) => bloc.add(const FlowCreateSubmitted(name: '')),
      expect: () => const <FlowCreateState>[
        FlowCreateSubmitting(),
        FlowCreateFailed(FlowsInvalidCreateFailure()),
      ],
    );

    blocTest<FlowCreateBloc, FlowCreateState>(
      'Submitted con network failure → Failed; reintento ok → Succeeded',
      build: () {
        var calls = 0;
        when(
          () => repo.createFlow(templateId: 't1', name: 'Bienvenida'),
        ).thenAnswer((_) async {
          calls += 1;
          if (calls == 1) throw const FlowsNetworkFailure();
          return _flow;
        });
        return FlowCreateBloc(repo: repo, templateId: 't1');
      },
      act: (bloc) async {
        bloc.add(const FlowCreateSubmitted(name: 'Bienvenida'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const FlowCreateSubmitted(name: 'Bienvenida'));
      },
      expect: () => const <FlowCreateState>[
        FlowCreateSubmitting(),
        FlowCreateFailed(FlowsNetworkFailure()),
        FlowCreateSubmitting(),
        FlowCreateSucceeded(_flow),
      ],
    );
  });
}
