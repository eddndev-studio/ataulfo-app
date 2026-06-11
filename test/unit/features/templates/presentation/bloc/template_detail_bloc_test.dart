import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:ataulfo/features/templates/domain/failures/templates_failure.dart';
import 'package:ataulfo/features/templates/domain/repositories/templates_repository.dart';
import 'package:ataulfo/features/templates/presentation/bloc/template_detail_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements TemplatesRepository {}

const _t1Ai = AIConfig(
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
  ai: _t1Ai,
);

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  group('TemplateDetailBloc', () {
    test('estado inicial = TemplateDetailLoading', () {
      // Patrón espejo de BotDetailBloc: el bloc arranca en Loading para que
      // la página tenga spinner desde el primer frame; la página dispara
      // LoadRequested al construirse y no hay flash de Initial.
      final bloc = TemplateDetailBloc(repo: repo, id: 't1');
      expect(bloc.state, const TemplateDetailLoading());
    });

    blocTest<TemplateDetailBloc, TemplateDetailState>(
      'LoadRequested + repo.byId OK → Loaded(template)',
      build: () {
        when(() => repo.byId('t1')).thenAnswer((_) async => _t1);
        return TemplateDetailBloc(repo: repo, id: 't1');
      },
      act: (bloc) => bloc.add(const TemplateDetailLoadRequested()),
      // Loading inicial vs Loading emitido por el handler colapsan por
      // value-eq; sólo Loaded entra en la lista de emisiones.
      expect: () => const <TemplateDetailState>[TemplateDetailLoaded(_t1)],
      verify: (_) => verify(() => repo.byId('t1')).called(1),
    );

    blocTest<TemplateDetailBloc, TemplateDetailState>(
      'LoadRequested + repo.byId NotFound → Failed(NotFound)',
      build: () {
        when(() => repo.byId('missing')).thenAnswer(
          (_) => Future<Template>.error(const TemplatesNotFoundFailure()),
        );
        return TemplateDetailBloc(repo: repo, id: 'missing');
      },
      act: (bloc) => bloc.add(const TemplateDetailLoadRequested()),
      expect: () => const <TemplateDetailState>[
        TemplateDetailFailed(TemplatesNotFoundFailure()),
      ],
    );

    blocTest<TemplateDetailBloc, TemplateDetailState>(
      'LoadRequested + repo.byId Forbidden → Failed(Forbidden)',
      build: () {
        when(() => repo.byId('t1')).thenAnswer(
          (_) => Future<Template>.error(const TemplatesForbiddenFailure()),
        );
        return TemplateDetailBloc(repo: repo, id: 't1');
      },
      act: (bloc) => bloc.add(const TemplateDetailLoadRequested()),
      expect: () => const <TemplateDetailState>[
        TemplateDetailFailed(TemplatesForbiddenFailure()),
      ],
    );

    blocTest<TemplateDetailBloc, TemplateDetailState>(
      'retry desde Failed: LoadRequested re-emite Loading y luego Loaded',
      build: () {
        when(() => repo.byId('t1')).thenAnswer((_) async => _t1);
        return TemplateDetailBloc(repo: repo, id: 't1');
      },
      // El usuario llega al estado Failed y toca "Reintentar". Aquí
      // forzamos ese seed; el handler debe pasar por Loading visible (no
      // colapsa porque Failed ≠ Loading) antes de aterrizar en Loaded.
      seed: () => const TemplateDetailFailed(TemplatesNetworkFailure()),
      act: (bloc) => bloc.add(const TemplateDetailLoadRequested()),
      expect: () => const <TemplateDetailState>[
        TemplateDetailLoading(),
        TemplateDetailLoaded(_t1),
      ],
    );

    blocTest<TemplateDetailBloc, TemplateDetailState>(
      'RenameRequested desde Loaded → Mutating → Loaded(actualizada); '
      'el PUT viaja con ai:null (la config IA queda intacta)',
      build: () {
        const renamed = Template(
          id: 't1',
          orgId: 'o1',
          name: 'Ventas',
          version: 2,
          ai: _t1Ai,
        );
        when(
          () => repo.update(id: 't1', name: 'Ventas', version: 1, ai: null),
        ).thenAnswer((_) async => renamed);
        return TemplateDetailBloc(repo: repo, id: 't1');
      },
      seed: () => const TemplateDetailLoaded(_t1),
      act: (bloc) => bloc.add(const TemplateDetailRenameRequested('Ventas')),
      expect: () => const <TemplateDetailState>[
        TemplateDetailMutating(_t1),
        TemplateDetailLoaded(
          Template(
            id: 't1',
            orgId: 'o1',
            name: 'Ventas',
            version: 2,
            ai: _t1Ai,
          ),
        ),
      ],
      verify: (_) => verify(
        () => repo.update(id: 't1', name: 'Ventas', version: 1, ai: null),
      ).called(1),
    );

    blocTest<TemplateDetailBloc, TemplateDetailState>(
      'Rename con 409 (CAS stale) → re-GET y MutationFailed con la '
      'plantilla REFRESCADA (siguiente intento parte de la versión nueva)',
      build: () {
        const refreshed = Template(
          id: 't1',
          orgId: 'o1',
          name: 'Soporte v2',
          version: 5,
          ai: _t1Ai,
        );
        when(
          () => repo.update(
            id: 't1',
            name: any(named: 'name'),
            version: any(named: 'version'),
            ai: null,
          ),
        ).thenAnswer(
          (_) => Future<Template>.error(const TemplatesConflictFailure()),
        );
        when(() => repo.byId('t1')).thenAnswer((_) async => refreshed);
        return TemplateDetailBloc(repo: repo, id: 't1');
      },
      seed: () => const TemplateDetailLoaded(_t1),
      act: (bloc) => bloc.add(const TemplateDetailRenameRequested('Ventas')),
      expect: () => const <TemplateDetailState>[
        TemplateDetailMutating(_t1),
        TemplateDetailMutationFailed(
          Template(
            id: 't1',
            orgId: 'o1',
            name: 'Soporte v2',
            version: 5,
            ai: _t1Ai,
          ),
          TemplatesConflictFailure(),
        ),
      ],
    );

    blocTest<TemplateDetailBloc, TemplateDetailState>(
      'Rename con fallo no-CAS → MutationFailed conserva el snapshot previo',
      build: () {
        when(
          () => repo.update(
            id: 't1',
            name: any(named: 'name'),
            version: any(named: 'version'),
            ai: null,
          ),
        ).thenAnswer(
          (_) => Future<Template>.error(const TemplatesNetworkFailure()),
        );
        return TemplateDetailBloc(repo: repo, id: 't1');
      },
      seed: () => const TemplateDetailLoaded(_t1),
      act: (bloc) => bloc.add(const TemplateDetailRenameRequested('Ventas')),
      expect: () => const <TemplateDetailState>[
        TemplateDetailMutating(_t1),
        TemplateDetailMutationFailed(_t1, TemplatesNetworkFailure()),
      ],
    );

    blocTest<TemplateDetailBloc, TemplateDetailState>(
      'Rename sin snapshot (Loading) se ignora: no hay versión CAS de base',
      build: () => TemplateDetailBloc(repo: repo, id: 't1'),
      act: (bloc) => bloc.add(const TemplateDetailRenameRequested('Ventas')),
      expect: () => const <TemplateDetailState>[],
      verify: (_) => verifyNever(
        () => repo.update(
          id: any(named: 'id'),
          name: any(named: 'name'),
          version: any(named: 'version'),
          ai: any(named: 'ai'),
        ),
      ),
    );

    blocTest<TemplateDetailBloc, TemplateDetailState>(
      'retry de rename desde MutationFailed usa la versión refrescada',
      build: () {
        const renamed = Template(
          id: 't1',
          orgId: 'o1',
          name: 'Ventas',
          version: 6,
          ai: _t1Ai,
        );
        when(
          () => repo.update(id: 't1', name: 'Ventas', version: 5, ai: null),
        ).thenAnswer((_) async => renamed);
        return TemplateDetailBloc(repo: repo, id: 't1');
      },
      seed: () => const TemplateDetailMutationFailed(
        Template(
          id: 't1',
          orgId: 'o1',
          name: 'Soporte v2',
          version: 5,
          ai: _t1Ai,
        ),
        TemplatesConflictFailure(),
      ),
      act: (bloc) => bloc.add(const TemplateDetailRenameRequested('Ventas')),
      expect: () => const <TemplateDetailState>[
        TemplateDetailMutating(
          Template(
            id: 't1',
            orgId: 'o1',
            name: 'Soporte v2',
            version: 5,
            ai: _t1Ai,
          ),
        ),
        TemplateDetailLoaded(
          Template(
            id: 't1',
            orgId: 'o1',
            name: 'Ventas',
            version: 6,
            ai: _t1Ai,
          ),
        ),
      ],
    );

    blocTest<TemplateDetailBloc, TemplateDetailState>(
      'AiUpdateRequested desde Loaded → Mutating → Loaded; el PUT viaja '
      'con el name ACTUAL (la edición del motor no renombra)',
      build: () {
        const newAi = AIConfig(
          enabled: true,
          provider: AIProvider.gemini,
          model: 'gemini-3.1-pro-preview',
          temperature: 1.2,
          thinkingLevel: ThinkingLevel.low,
          systemPrompt: '',
          contextMessages: 20,
        );
        const updated = Template(
          id: 't1',
          orgId: 'o1',
          name: 'Soporte',
          version: 2,
          ai: newAi,
        );
        when(
          () => repo.update(id: 't1', name: 'Soporte', version: 1, ai: newAi),
        ).thenAnswer((_) async => updated);
        return TemplateDetailBloc(repo: repo, id: 't1');
      },
      seed: () => const TemplateDetailLoaded(_t1),
      act: (bloc) => bloc.add(
        const TemplateDetailAiUpdateRequested(
          AIConfig(
            enabled: true,
            provider: AIProvider.gemini,
            model: 'gemini-3.1-pro-preview',
            temperature: 1.2,
            thinkingLevel: ThinkingLevel.low,
            systemPrompt: '',
            contextMessages: 20,
          ),
        ),
      ),
      expect: () => const <TemplateDetailState>[
        TemplateDetailMutating(_t1),
        TemplateDetailLoaded(
          Template(
            id: 't1',
            orgId: 'o1',
            name: 'Soporte',
            version: 2,
            ai: AIConfig(
              enabled: true,
              provider: AIProvider.gemini,
              model: 'gemini-3.1-pro-preview',
              temperature: 1.2,
              thinkingLevel: ThinkingLevel.low,
              systemPrompt: '',
              contextMessages: 20,
            ),
          ),
        ),
      ],
    );

    blocTest<TemplateDetailBloc, TemplateDetailState>(
      'AiUpdate con 409 → re-GET y MutationFailed con la plantilla refrescada',
      build: () {
        const refreshed = Template(
          id: 't1',
          orgId: 'o1',
          name: 'Soporte',
          version: 9,
          ai: _t1Ai,
        );
        when(
          () => repo.update(
            id: 't1',
            name: any(named: 'name'),
            version: any(named: 'version'),
            ai: any(named: 'ai'),
          ),
        ).thenAnswer(
          (_) => Future<Template>.error(const TemplatesConflictFailure()),
        );
        when(() => repo.byId('t1')).thenAnswer((_) async => refreshed);
        return TemplateDetailBloc(repo: repo, id: 't1');
      },
      seed: () => const TemplateDetailLoaded(_t1),
      act: (bloc) => bloc.add(const TemplateDetailAiUpdateRequested(_t1Ai)),
      expect: () => const <TemplateDetailState>[
        TemplateDetailMutating(_t1),
        TemplateDetailMutationFailed(
          Template(
            id: 't1',
            orgId: 'o1',
            name: 'Soporte',
            version: 9,
            ai: _t1Ai,
          ),
          TemplatesConflictFailure(),
        ),
      ],
    );

    test('value-equality de eventos y estados', () {
      expect(
        const TemplateDetailLoadRequested(),
        const TemplateDetailLoadRequested(),
      );
      expect(const TemplateDetailLoading(), const TemplateDetailLoading());
      expect(const TemplateDetailLoaded(_t1), const TemplateDetailLoaded(_t1));
      expect(
        const TemplateDetailFailed(TemplatesServerFailure()),
        const TemplateDetailFailed(TemplatesServerFailure()),
      );
      expect(
        const TemplateDetailFailed(TemplatesServerFailure()) ==
            const TemplateDetailFailed(TemplatesNetworkFailure()),
        isFalse,
      );
    });
  });
}
