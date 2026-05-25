import 'package:agentic/features/templates/domain/entities/template.dart';
import 'package:agentic/features/templates/domain/failures/templates_failure.dart';
import 'package:agentic/features/templates/domain/repositories/templates_repository.dart';
import 'package:agentic/features/templates/presentation/bloc/template_detail_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements TemplatesRepository {}

const _t1 = Template(
  id: 't1',
  orgId: 'o1',
  name: 'Soporte',
  version: 1,
  ai: AIConfig(
    enabled: false,
    provider: AIProvider.gemini,
    model: 'gemini-3.1-pro-preview',
    temperature: 0.7,
    thinkingLevel: ThinkingLevel.low,
    systemPrompt: '',
    contextMessages: 20,
  ),
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

    test('value-equality de eventos y estados', () {
      expect(
        const TemplateDetailLoadRequested(),
        const TemplateDetailLoadRequested(),
      );
      expect(const TemplateDetailLoading(), const TemplateDetailLoading());
      expect(
        const TemplateDetailLoaded(_t1),
        const TemplateDetailLoaded(_t1),
      );
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
