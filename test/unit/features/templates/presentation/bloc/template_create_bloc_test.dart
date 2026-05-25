import 'package:agentic/features/templates/domain/entities/template.dart';
import 'package:agentic/features/templates/domain/failures/templates_failure.dart';
import 'package:agentic/features/templates/domain/repositories/templates_repository.dart';
import 'package:agentic/features/templates/presentation/bloc/template_create_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements TemplatesRepository {}

const _tpl = Template(
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

  group('TemplateCreateBloc', () {
    test('estado inicial = TemplateCreateInitial', () {
      final bloc = TemplateCreateBloc(repo: repo);
      expect(bloc.state, const TemplateCreateInitial());
      bloc.close();
    });

    blocTest<TemplateCreateBloc, TemplateCreateState>(
      'Submitted ok → [Submitting, Succeeded(template)]',
      build: () {
        when(() => repo.create('Soporte')).thenAnswer((_) async => _tpl);
        return TemplateCreateBloc(repo: repo);
      },
      act: (bloc) => bloc.add(const TemplateCreateSubmitted(name: 'Soporte')),
      expect: () => const <TemplateCreateState>[
        TemplateCreateSubmitting(),
        TemplateCreateSucceeded(_tpl),
      ],
      verify: (_) => verify(() => repo.create('Soporte')).called(1),
    );

    blocTest<TemplateCreateBloc, TemplateCreateState>(
      '422 → [Submitting, Failed(InvalidName)]',
      build: () {
        when(() => repo.create('')).thenAnswer(
          (_) => Future<Template>.error(const TemplatesInvalidNameFailure()),
        );
        return TemplateCreateBloc(repo: repo);
      },
      act: (bloc) => bloc.add(const TemplateCreateSubmitted(name: '')),
      expect: () => const <TemplateCreateState>[
        TemplateCreateSubmitting(),
        TemplateCreateFailed(TemplatesInvalidNameFailure()),
      ],
    );

    blocTest<TemplateCreateBloc, TemplateCreateState>(
      '403 → [Submitting, Failed(Forbidden)]',
      build: () {
        when(() => repo.create('X')).thenAnswer(
          (_) => Future<Template>.error(const TemplatesForbiddenFailure()),
        );
        return TemplateCreateBloc(repo: repo);
      },
      act: (bloc) => bloc.add(const TemplateCreateSubmitted(name: 'X')),
      expect: () => const <TemplateCreateState>[
        TemplateCreateSubmitting(),
        TemplateCreateFailed(TemplatesForbiddenFailure()),
      ],
    );

    blocTest<TemplateCreateBloc, TemplateCreateState>(
      'retry desde Failed: Submitted vuelve a pasar por Submitting',
      build: () {
        // Primer intento falla, segundo intento ok. La UI puede dejar el
        // botón habilitado en Failed para permitir reintento.
        var calls = 0;
        when(() => repo.create('Soporte')).thenAnswer((_) {
          calls++;
          if (calls == 1) {
            return Future<Template>.error(const TemplatesServerFailure());
          }
          return Future<Template>.value(_tpl);
        });
        return TemplateCreateBloc(repo: repo);
      },
      act: (bloc) async {
        bloc.add(const TemplateCreateSubmitted(name: 'Soporte'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TemplateCreateSubmitted(name: 'Soporte'));
      },
      expect: () => const <TemplateCreateState>[
        TemplateCreateSubmitting(),
        TemplateCreateFailed(TemplatesServerFailure()),
        TemplateCreateSubmitting(),
        TemplateCreateSucceeded(_tpl),
      ],
    );

    test('value-equality de los estados', () {
      expect(
        const TemplateCreateInitial(),
        equals(const TemplateCreateInitial()),
      );
      expect(
        const TemplateCreateSubmitting(),
        equals(const TemplateCreateSubmitting()),
      );
      expect(
        const TemplateCreateSucceeded(_tpl),
        equals(const TemplateCreateSucceeded(_tpl)),
      );
      expect(
        const TemplateCreateFailed(TemplatesNetworkFailure()),
        equals(const TemplateCreateFailed(TemplatesNetworkFailure())),
      );
    });
  });
}
