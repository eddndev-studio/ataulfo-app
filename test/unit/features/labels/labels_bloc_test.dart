import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/failures/labels_failure.dart';
import 'package:ataulfo/features/labels/domain/repositories/labels_repository.dart';
import 'package:ataulfo/features/labels/presentation/bloc/labels_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements LabelsRepository {}

Label _label({
  String id = 'l1',
  String name = 'VIP',
  String color = '#FF8800',
  String description = '',
}) => Label(id: id, name: name, color: color, description: description);

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  LabelsBloc build() => LabelsBloc(repo: repo);

  test('estado inicial es LabelsLoading (no flashea Initial)', () {
    when(() => repo.listLabels()).thenAnswer((_) async => <Label>[]);
    expect(build().state, const LabelsLoading());
  });

  group('carga inicial', () {
    blocTest<LabelsBloc, LabelsState>(
      'load → Loaded con el catálogo',
      build: () {
        when(() => repo.listLabels()).thenAnswer(
          (_) async => <Label>[_label(), _label(id: 'l2', name: 'Lead')],
        );
        return build();
      },
      act: (b) => b.add(const LabelsLoadRequested()),
      expect: () => <LabelsState>[
        LabelsLoaded(<Label>[_label(), _label(id: 'l2', name: 'Lead')]),
      ],
    );

    blocTest<LabelsBloc, LabelsState>(
      'load con lista vacía → Loaded([]) (org sin labels es válido)',
      build: () {
        when(() => repo.listLabels()).thenAnswer((_) async => <Label>[]);
        return build();
      },
      act: (b) => b.add(const LabelsLoadRequested()),
      expect: () => <LabelsState>[const LabelsLoaded(<Label>[])],
    );

    blocTest<LabelsBloc, LabelsState>(
      'load failure → Failed con la failure tipada',
      build: () {
        when(() => repo.listLabels()).thenThrow(const LabelsForbiddenFailure());
        return build();
      },
      act: (b) => b.add(const LabelsLoadRequested()),
      expect: () => <LabelsState>[const LabelsFailed(LabelsForbiddenFailure())],
    );
  });

  group('reintento tras error', () {
    blocTest<LabelsBloc, LabelsState>(
      'Failed → reintento → Loading → Loaded',
      build: () {
        var calls = 0;
        when(() => repo.listLabels()).thenAnswer((_) async {
          calls++;
          if (calls == 1) throw const LabelsNetworkFailure();
          return <Label>[_label()];
        });
        return build();
      },
      act: (b) async {
        b.add(const LabelsLoadRequested());
        await Future<void>.delayed(Duration.zero);
        b.add(const LabelsLoadRequested());
      },
      expect: () => <LabelsState>[
        const LabelsFailed(LabelsNetworkFailure()),
        const LabelsLoading(),
        LabelsLoaded(<Label>[_label()]),
      ],
    );
  });
}
