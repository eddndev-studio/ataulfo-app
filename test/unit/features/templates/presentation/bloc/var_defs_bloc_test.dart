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
  setUpAll(() {
    registerFallbackValue(VarType.text);
  });

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

  group('VarDefsBloc.AddRequested', () {
    const addedDef = VariableDef(
      id: 'vd_new',
      name: 'saldo',
      type: VarType.text,
      defaultValue: 'x',
      description: '',
    );

    const newDefs = <VariableDef>[..._defs, addedDef];

    blocTest<VarDefsBloc, VarDefsState>(
      'success: Mutating → Loading → Loaded(newDefs, newVersion) (refetch tras add)',
      build: () {
        // El primer listVarDefs es el load inicial; el segundo es el
        // refetch que el bloc dispara tras el POST success.
        var listCalls = 0;
        when(() => repo.listVarDefs('t1')).thenAnswer((_) async {
          listCalls++;
          return listCalls == 1
              ? (version: 2, defs: _defs)
              : (version: 3, defs: newDefs);
        });
        when(
          () => repo.addVarDef(
            templateId: 't1',
            name: 'saldo',
            type: VarType.text,
            defaultValue: 'x',
            description: '',
            version: 2,
          ),
        ).thenAnswer((_) async => addedDef);
        return VarDefsBloc(repo: repo, templateId: 't1')
          ..add(const VarDefsLoadRequested());
      },
      act: (bloc) async {
        // Esperar al Loaded inicial antes de pedir el Add (necesita la
        // version del Template para CAS).
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const VarDefsAddRequested(
            name: 'saldo',
            type: VarType.text,
            defaultValue: 'x',
            description: '',
          ),
        );
      },
      expect: () => const <VarDefsState>[
        VarDefsLoaded(_defs, 2),
        VarDefsMutating(_defs, 2),
        VarDefsLoading(),
        VarDefsLoaded(newDefs, 3),
      ],
      verify: (_) {
        verify(
          () => repo.addVarDef(
            templateId: 't1',
            name: 'saldo',
            type: VarType.text,
            defaultValue: 'x',
            description: '',
            version: 2,
          ),
        ).called(1);
        // El refetch corre tras success ⇒ 2 calls a listVarDefs (load
        // inicial + refetch post-add).
        verify(() => repo.listVarDefs('t1')).called(2);
      },
    );

    blocTest<VarDefsBloc, VarDefsState>(
      'failure 409: Mutating → MutationFailed(prev, Conflict) (no se pierde el snapshot)',
      build: () {
        when(
          () => repo.listVarDefs('t1'),
        ).thenAnswer((_) async => (version: 2, defs: _defs));
        when(
          () => repo.addVarDef(
            templateId: 't1',
            name: 'dup',
            type: VarType.text,
            defaultValue: '',
            description: '',
            version: 2,
          ),
        ).thenAnswer(
          (_) => Future<VariableDef>.error(const TemplatesConflictFailure()),
        );
        return VarDefsBloc(repo: repo, templateId: 't1')
          ..add(const VarDefsLoadRequested());
      },
      act: (bloc) async {
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const VarDefsAddRequested(
            name: 'dup',
            type: VarType.text,
            defaultValue: '',
            description: '',
          ),
        );
      },
      expect: () => const <VarDefsState>[
        VarDefsLoaded(_defs, 2),
        VarDefsMutating(_defs, 2),
        VarDefsMutationFailed(_defs, 2, TemplatesConflictFailure()),
      ],
    );

    blocTest<VarDefsBloc, VarDefsState>(
      'AddRequested desde Loading se ignora (defensive: no hay version para CAS)',
      build: () => VarDefsBloc(repo: repo, templateId: 't1'),
      act: (bloc) => bloc.add(
        const VarDefsAddRequested(
          name: 'x',
          type: VarType.text,
          defaultValue: '',
          description: '',
        ),
      ),
      expect: () => const <VarDefsState>[],
      verify: (_) {
        verifyNever(
          () => repo.addVarDef(
            templateId: any(named: 'templateId'),
            name: any(named: 'name'),
            type: any(named: 'type'),
            defaultValue: any(named: 'defaultValue'),
            description: any(named: 'description'),
            version: any(named: 'version'),
          ),
        );
      },
    );

    test('equality de Mutating y MutationFailed incluye defs+version', () {
      expect(
        const VarDefsMutating(_defs, 2),
        equals(const VarDefsMutating(_defs, 2)),
      );
      expect(
        const VarDefsMutating(_defs, 2),
        isNot(equals(const VarDefsMutating(_defs, 3))),
      );
      expect(
        const VarDefsMutationFailed(_defs, 2, TemplatesConflictFailure()),
        equals(
          const VarDefsMutationFailed(_defs, 2, TemplatesConflictFailure()),
        ),
      );
      expect(
        const VarDefsMutationFailed(_defs, 2, TemplatesConflictFailure()),
        isNot(
          equals(
            const VarDefsMutationFailed(_defs, 2, TemplatesServerFailure()),
          ),
        ),
      );
    });
  });
}
