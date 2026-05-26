import 'package:agentic/features/templates/domain/entities/template.dart';
import 'package:agentic/features/templates/domain/failures/templates_failure.dart';
import 'package:agentic/features/templates/domain/repositories/templates_repository.dart';
import 'package:agentic/features/templates/presentation/bloc/template_edit_bloc.dart';
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
    systemPrompt: 'Eres útil.',
    contextMessages: 20,
  ),
);

const _tplUpdated = Template(
  id: 't1',
  orgId: 'o1',
  name: 'Soporte v2',
  version: 2,
  ai: AIConfig(
    enabled: false,
    provider: AIProvider.gemini,
    model: 'gemini-3.1-pro-preview',
    temperature: 0.7,
    thinkingLevel: ThinkingLevel.low,
    systemPrompt: 'Nuevo prompt.',
    contextMessages: 20,
  ),
);

void main() {
  group('TemplateEditBloc', () {
    test('estado inicial = TemplateEditLoading (sin flash de Initial)', () {
      final bloc = TemplateEditBloc(repo: _MockRepo(), id: 't1');
      expect(bloc.state, const TemplateEditLoading());
    });

    group('TemplateEditLoadRequested', () {
      blocTest<TemplateEditBloc, TemplateEditState>(
        'byId ok → [Editing(template)] (no re-emite Loading post-construcción)',
        build: () {
          final repo = _MockRepo();
          when(() => repo.byId('t1')).thenAnswer((_) async => _tpl);
          return TemplateEditBloc(repo: repo, id: 't1');
        },
        act: (bloc) => bloc.add(const TemplateEditLoadRequested()),
        expect: () => const <TemplateEditState>[TemplateEditEditing(_tpl)],
      );

      blocTest<TemplateEditBloc, TemplateEditState>(
        'byId NotFound → [LoadFailed(NotFound)]',
        build: () {
          final repo = _MockRepo();
          when(() => repo.byId('t1')).thenAnswer(
            (_) => Future<Template>.error(const TemplatesNotFoundFailure()),
          );
          return TemplateEditBloc(repo: repo, id: 't1');
        },
        act: (bloc) => bloc.add(const TemplateEditLoadRequested()),
        expect: () => const <TemplateEditState>[
          TemplateEditLoadFailed(TemplatesNotFoundFailure()),
        ],
      );

      blocTest<TemplateEditBloc, TemplateEditState>(
        'retry desde LoadFailed re-emite Loading visible',
        build: () {
          final repo = _MockRepo();
          when(() => repo.byId('t1')).thenAnswer((_) async => _tpl);
          return TemplateEditBloc(repo: repo, id: 't1');
        },
        seed: () => const TemplateEditLoadFailed(TemplatesNetworkFailure()),
        act: (bloc) => bloc.add(const TemplateEditLoadRequested()),
        expect: () => const <TemplateEditState>[
          TemplateEditLoading(),
          TemplateEditEditing(_tpl),
        ],
      );
    });

    group('TemplateEditSubmitted', () {
      blocTest<TemplateEditBloc, TemplateEditState>(
        'submit ok → [Submitting(template), Succeeded(updated)]',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.update(
              id: 't1',
              name: 'Soporte v2',
              version: 1,
              ai: any(named: 'ai'),
            ),
          ).thenAnswer((_) async => _tplUpdated);
          return TemplateEditBloc(repo: repo, id: 't1');
        },
        seed: () => const TemplateEditEditing(_tpl),
        act: (bloc) => bloc.add(
          const TemplateEditSubmitted(
            name: 'Soporte v2',
            systemPrompt: 'Nuevo prompt.',
          ),
        ),
        expect: () => const <TemplateEditState>[
          TemplateEditSubmitting(_tpl),
          TemplateEditSucceeded(_tplUpdated),
        ],
      );

      blocTest<TemplateEditBloc, TemplateEditState>(
        'submit Conflict (CAS) → [Submitting, SubmitFailed(Conflict, template)]',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.update(
              id: 't1',
              name: any(named: 'name'),
              version: 1,
              ai: any(named: 'ai'),
            ),
          ).thenAnswer(
            (_) => Future<Template>.error(const TemplatesConflictFailure()),
          );
          return TemplateEditBloc(repo: repo, id: 't1');
        },
        seed: () => const TemplateEditEditing(_tpl),
        act: (bloc) =>
            bloc.add(const TemplateEditSubmitted(name: 'x', systemPrompt: 'y')),
        expect: () => const <TemplateEditState>[
          TemplateEditSubmitting(_tpl),
          TemplateEditSubmitFailed(
            failure: TemplatesConflictFailure(),
            template: _tpl,
          ),
        ],
      );

      blocTest<TemplateEditBloc, TemplateEditState>(
        'submit InvalidUpdate → SubmitFailed preserva el template (UI re-renderea form)',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.update(
              id: 't1',
              name: any(named: 'name'),
              version: 1,
              ai: any(named: 'ai'),
            ),
          ).thenAnswer(
            (_) =>
                Future<Template>.error(const TemplatesInvalidUpdateFailure()),
          );
          return TemplateEditBloc(repo: repo, id: 't1');
        },
        seed: () => const TemplateEditEditing(_tpl),
        act: (bloc) =>
            bloc.add(const TemplateEditSubmitted(name: 'x', systemPrompt: 'y')),
        expect: () => const <TemplateEditState>[
          TemplateEditSubmitting(_tpl),
          TemplateEditSubmitFailed(
            failure: TemplatesInvalidUpdateFailure(),
            template: _tpl,
          ),
        ],
      );

      test(
        'submit serializa AIConfig con systemPrompt nuevo y demás campos intactos',
        () async {
          // Garantiza que el bloc conserve los 6 campos no-editables del
          // AIConfig al cambiar solo systemPrompt. Sin esto, un bug que
          // pasara un AIConfig recién construido (con defaults) borraría
          // provider/model/temperature/etc. en el PUT.
          final repo = _MockRepo();
          AIConfig? capturedAi;
          when(
            () => repo.update(
              id: 't1',
              name: 'x',
              version: 1,
              ai: any(named: 'ai'),
            ),
          ).thenAnswer((invocation) async {
            capturedAi = invocation.namedArguments[#ai] as AIConfig?;
            return _tplUpdated;
          });
          final bloc = TemplateEditBloc(repo: repo, id: 't1');
          bloc.emit(const TemplateEditEditing(_tpl));

          bloc.add(
            const TemplateEditSubmitted(
              name: 'x',
              systemPrompt: 'Nuevo prompt.',
            ),
          );
          await bloc.stream.firstWhere(
            (s) => s is TemplateEditSucceeded || s is TemplateEditSubmitFailed,
          );

          expect(capturedAi, isNotNull);
          expect(capturedAi!.systemPrompt, 'Nuevo prompt.');
          // Resto del AIConfig original debe estar intacto.
          expect(capturedAi!.enabled, _tpl.ai.enabled);
          expect(capturedAi!.provider, _tpl.ai.provider);
          expect(capturedAi!.model, _tpl.ai.model);
          expect(capturedAi!.temperature, _tpl.ai.temperature);
          expect(capturedAi!.thinkingLevel, _tpl.ai.thinkingLevel);
          expect(capturedAi!.contextMessages, _tpl.ai.contextMessages);
        },
      );
    });
  });
}
