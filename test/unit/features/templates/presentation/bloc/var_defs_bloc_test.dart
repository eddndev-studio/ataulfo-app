import 'package:agentic/features/templates/domain/entities/variable_def.dart';
import 'package:agentic/features/templates/domain/failures/templates_failure.dart';
import 'package:agentic/features/templates/domain/repositories/templates_repository.dart';
import 'package:agentic/features/templates/presentation/bloc/var_defs_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements TemplatesRepository {}

const _defs = <VariableDef>[
  VariableDef(
    id: 'v1',
    name: 'nombre',
    type: VarType.text,
    defaultValue: 'cliente',
    description: '',
  ),
];

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  group('VarDefsBloc', () {
    test('estado inicial = Loading (sin flash de Initial)', () {
      final bloc = VarDefsBloc(repo: repo, templateId: 't1');
      expect(bloc.state, const VarDefsLoading());
      bloc.close();
    });

    blocTest<VarDefsBloc, VarDefsState>(
      'LoadRequested ok → Loaded(defs, version) (no re-emite Loading post-construcción)',
      build: () {
        when(
          () => repo.listVarDefs('t1'),
        ).thenAnswer((_) async => (version: 3, defs: _defs));
        return VarDefsBloc(repo: repo, templateId: 't1');
      },
      act: (bloc) => bloc.add(const VarDefsLoadRequested()),
      expect: () => const <VarDefsState>[VarDefsLoaded(_defs, 3)],
      verify: (_) => verify(() => repo.listVarDefs('t1')).called(1),
    );

    blocTest<VarDefsBloc, VarDefsState>(
      'LoadRequested ok con lista vacía → Loaded([], v) (plantilla sin vars)',
      build: () {
        when(() => repo.listVarDefs('t1')).thenAnswer(
          (_) async => (version: 1, defs: const <VariableDef>[]),
        );
        return VarDefsBloc(repo: repo, templateId: 't1');
      },
      act: (bloc) => bloc.add(const VarDefsLoadRequested()),
      expect: () => const <VarDefsState>[VarDefsLoaded(<VariableDef>[], 1)],
    );

    blocTest<VarDefsBloc, VarDefsState>(
      'LoadRequested 404 → Failed(NotFound)',
      build: () {
        when(() => repo.listVarDefs('t1')).thenAnswer(
          (_) => Future<({int version, List<VariableDef> defs})>.error(
            const TemplatesNotFoundFailure(),
          ),
        );
        return VarDefsBloc(repo: repo, templateId: 't1');
      },
      act: (bloc) => bloc.add(const VarDefsLoadRequested()),
      expect: () => const <VarDefsState>[
        VarDefsFailed(TemplatesNotFoundFailure()),
      ],
    );

    blocTest<VarDefsBloc, VarDefsState>(
      'retry desde Failed re-emite Loading visible y luego Loaded',
      build: () {
        var calls = 0;
        when(() => repo.listVarDefs('t1')).thenAnswer((_) {
          calls++;
          if (calls == 1) {
            return Future<({int version, List<VariableDef> defs})>.error(
              const TemplatesServerFailure(),
            );
          }
          return Future<({int version, List<VariableDef> defs})>.value(
            (version: 4, defs: _defs),
          );
        });
        return VarDefsBloc(repo: repo, templateId: 't1');
      },
      act: (bloc) async {
        bloc.add(const VarDefsLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const VarDefsLoadRequested());
      },
      expect: () => const <VarDefsState>[
        VarDefsFailed(TemplatesServerFailure()),
        VarDefsLoading(),
        VarDefsLoaded(_defs, 4),
      ],
    );

    test('value-equality de los estados', () {
      expect(const VarDefsLoading(), equals(const VarDefsLoading()));
      expect(
        const VarDefsLoaded(_defs, 1),
        equals(const VarDefsLoaded(_defs, 1)),
      );
      expect(
        const VarDefsFailed(TemplatesNetworkFailure()),
        equals(const VarDefsFailed(TemplatesNetworkFailure())),
      );
    });

    test('Loaded expone la version vigente de la Template padre', () {
      const loaded = VarDefsLoaded(_defs, 7);
      expect(loaded.version, 7);
      expect(
        loaded,
        isNot(equals(const VarDefsLoaded(_defs, 8))),
        reason: 'la version forma parte de la equality del state',
      );
    });
  });
}
