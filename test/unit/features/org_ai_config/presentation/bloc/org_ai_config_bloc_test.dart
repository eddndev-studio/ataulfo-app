import 'package:ataulfo/features/org_ai_config/domain/entities/org_ai_config.dart';
import 'package:ataulfo/features/org_ai_config/domain/failures/org_ai_config_failure.dart';
import 'package:ataulfo/features/org_ai_config/domain/repositories/org_ai_config_repository.dart';
import 'package:ataulfo/features/org_ai_config/presentation/bloc/org_ai_config_bloc.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements OrgAiConfigRepository {}

const _defaults = AIConfig(
  enabled: false,
  provider: AIProvider.gemini,
  model: 'gemini-3.1-pro-preview',
  temperature: 0.7,
  thinkingLevel: ThinkingLevel.low,
  systemPrompt: '',
  contextMessages: 20,
);

const _saved = OrgAiConfig(hosts: <String, String>{}, defaults: _defaults);

void main() {
  setUpAll(() => registerFallbackValue(_saved));

  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  blocTest<OrgAiConfigBloc, OrgAiConfigState>(
    'LoadRequested ok → [Loading, Loaded(saved==working, no dirty)]',
    build: () {
      when(repo.get).thenAnswer((_) async => _saved);
      return OrgAiConfigBloc(repo);
    },
    act: (b) => b.add(const OrgAiConfigLoadRequested()),
    expect: () => <Object>[
      const OrgAiConfigLoading(),
      const OrgAiConfigLoaded(saved: _saved, working: _saved),
    ],
    verify: (_) {
      // baseline == working ⇒ no dirty al cargar.
      expect((_saved == _saved), isTrue);
    },
  );

  blocTest<OrgAiConfigBloc, OrgAiConfigState>(
    'LoadRequested 403 → [Loading, LoadFailed]',
    build: () {
      when(repo.get).thenThrow(const OrgAiConfigForbiddenFailure());
      return OrgAiConfigBloc(repo);
    },
    act: (b) => b.add(const OrgAiConfigLoadRequested()),
    expect: () => <Object>[
      const OrgAiConfigLoading(),
      const OrgAiConfigLoadFailed(OrgAiConfigForbiddenFailure()),
    ],
  );

  blocTest<OrgAiConfigBloc, OrgAiConfigState>(
    'HostChanged marca dirty (working != saved)',
    build: () {
      when(repo.get).thenAnswer((_) async => _saved);
      return OrgAiConfigBloc(repo);
    },
    act: (b) async {
      b.add(const OrgAiConfigLoadRequested());
      await Future<void>.delayed(Duration.zero);
      b.add(
        const OrgAiConfigHostChanged(model: 'MiniMax-M3', host: 'FIREWORKS'),
      );
    },
    skip: 2,
    expect: () => <Matcher>[
      isA<OrgAiConfigLoaded>()
          .having((s) => s.dirty, 'dirty', isTrue)
          .having((s) => s.working.hostFor('MiniMax-M3'), 'host', 'FIREWORKS'),
    ],
  );

  blocTest<OrgAiConfigBloc, OrgAiConfigState>(
    'SaveRequested ok → [saving, Loaded(saved=result, no dirty)]',
    build: () {
      when(repo.get).thenAnswer((_) async => _saved);
      final result = _saved.withHost('MiniMax-M3', 'FIREWORKS');
      when(() => repo.update(any())).thenAnswer((_) async => result);
      return OrgAiConfigBloc(repo);
    },
    act: (b) async {
      b.add(const OrgAiConfigLoadRequested());
      await Future<void>.delayed(Duration.zero);
      b.add(
        const OrgAiConfigHostChanged(model: 'MiniMax-M3', host: 'FIREWORKS'),
      );
      b.add(const OrgAiConfigSaveRequested());
    },
    skip: 3,
    expect: () => <Matcher>[
      isA<OrgAiConfigLoaded>().having((s) => s.saving, 'saving', isTrue),
      isA<OrgAiConfigLoaded>()
          .having((s) => s.saving, 'saving', isFalse)
          .having((s) => s.dirty, 'dirty', isFalse)
          .having((s) => s.saved.hostFor('MiniMax-M3'), 'saved host', 'FIREWORKS'),
    ],
    verify: (_) => verify(() => repo.update(any())).called(1),
  );

  blocTest<OrgAiConfigBloc, OrgAiConfigState>(
    'SaveRequested 422 → Loaded(saving:false, saveError) y conserva working',
    build: () {
      when(repo.get).thenAnswer((_) async => _saved);
      when(() => repo.update(any()))
          .thenThrow(const OrgAiConfigInvalidFailure());
      return OrgAiConfigBloc(repo);
    },
    act: (b) async {
      b.add(const OrgAiConfigLoadRequested());
      await Future<void>.delayed(Duration.zero);
      b.add(
        const OrgAiConfigHostChanged(model: 'MiniMax-M3', host: 'FIREWORKS'),
      );
      b.add(const OrgAiConfigSaveRequested());
    },
    skip: 3,
    expect: () => <Matcher>[
      isA<OrgAiConfigLoaded>().having((s) => s.saving, 'saving', isTrue),
      isA<OrgAiConfigLoaded>()
          .having((s) => s.saving, 'saving', isFalse)
          .having((s) => s.saveError, 'saveError', isA<OrgAiConfigInvalidFailure>())
          .having((s) => s.working.hostFor('MiniMax-M3'), 'working keeps edit', 'FIREWORKS'),
    ],
  );
}
