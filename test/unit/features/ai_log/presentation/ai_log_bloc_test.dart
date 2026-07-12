import 'package:ataulfo/features/ai_log/domain/ai_log_repository.dart';
import 'package:ataulfo/features/ai_log/domain/entities/ai_log_entry.dart';
import 'package:ataulfo/features/ai_log/domain/entities/ai_run_outcome.dart';
import 'package:ataulfo/features/ai_log/domain/failures/ai_log_failure.dart';
import 'package:ataulfo/features/ai_log/presentation/bloc/ai_log_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AiLogRepository {}

AiLogEntry e(int id) => AiLogEntry(
  id: id,
  runId: 'r1',
  role: AiLogRole.user,
  content: 'c$id',
  reasoning: '',
  toolCalls: const <AiToolCall>[],
  toolCallId: '',
  toolName: '',
  model: '',
  promptTokens: 0,
  completionTokens: 0,
  totalTokens: 0,
  createdAt: DateTime.utc(2026, 6, 12),
);

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  blocTest<AiLogBloc, AiLogState>(
    'load inicial → Loaded con entries y cursor',
    build: () {
      when(() => repo.page(botId: 'b1', chatLid: 'c1')).thenAnswer(
        (_) async =>
            AiLogPageResult(items: <AiLogEntry>[e(42), e(41)], nextBefore: 41),
      );
      return AiLogBloc(repo: repo, botId: 'b1', chatLid: 'c1');
    },
    act: (bloc) => bloc.add(const AiLogLoadRequested()),
    expect: () => <Matcher>[
      isA<AiLogLoaded>()
          .having((s) => s.entries.length, 'entries', 2)
          .having((s) => s.nextBefore, 'nextBefore', 41),
    ],
  );

  blocTest<AiLogBloc, AiLogState>(
    'load more → acumula al final y actualiza cursor',
    build: () {
      when(() => repo.page(botId: 'b1', chatLid: 'c1', before: 41)).thenAnswer(
        (_) async =>
            AiLogPageResult(items: <AiLogEntry>[e(40)], nextBefore: null),
      );
      return AiLogBloc(repo: repo, botId: 'b1', chatLid: 'c1');
    },
    seed: () => AiLogLoaded(
      entries: <AiLogEntry>[e(42), e(41)],
      nextBefore: 41,
      isLoadingMore: false,
    ),
    act: (bloc) => bloc.add(const AiLogMoreRequested()),
    expect: () => <Matcher>[
      isA<AiLogLoaded>().having((s) => s.isLoadingMore, 'loadingMore', true),
      isA<AiLogLoaded>()
          .having((s) => s.entries.map((x) => x.id), 'ids', <int>[42, 41, 40])
          .having((s) => s.nextBefore, 'nextBefore', isNull)
          .having((s) => s.isLoadingMore, 'loadingMore', false),
    ],
  );

  blocTest<AiLogBloc, AiLogState>(
    'load more sin cursor → no-op (última página ya cargada)',
    build: () => AiLogBloc(repo: repo, botId: 'b1', chatLid: 'c1'),
    seed: () => AiLogLoaded(
      entries: <AiLogEntry>[e(42)],
      nextBefore: null,
      isLoadingMore: false,
    ),
    act: (bloc) => bloc.add(const AiLogMoreRequested()),
    expect: () => const <AiLogState>[],
    verify: (_) {
      verifyNever(
        () => repo.page(
          botId: any(named: 'botId'),
          chatLid: any(named: 'chatLid'),
          before: any(named: 'before'),
        ),
      );
    },
  );

  blocTest<AiLogBloc, AiLogState>(
    'drill-through: resuelve el wamid → corrida y carga sus entries (sin cursor)',
    build: () {
      when(
        () =>
            repo.runForMessage(botId: 'b1', chatLid: 'c1', externalId: 'WAM9'),
      ).thenAnswer((_) async => 'run-7');
      when(
        () => repo.byRun(botId: 'b1', chatLid: 'c1', runId: 'run-7'),
      ).thenAnswer(
        (_) async => AiLogRunResult(items: <AiLogEntry>[e(7)], run: null),
      );
      return AiLogBloc(
        repo: repo,
        botId: 'b1',
        chatLid: 'c1',
        targetExternalId: 'WAM9',
      );
    },
    act: (bloc) => bloc.add(const AiLogLoadRequested()),
    expect: () => <Matcher>[
      isA<AiLogLoaded>()
          .having((s) => s.entries.length, 'entries', 1)
          .having((s) => s.nextBefore, 'nextBefore', isNull)
          .having((s) => s.drill, 'drill', isTrue)
          .having((s) => s.run, 'run{} omitido', isNull),
    ],
    verify: (_) {
      verifyNever(
        () => repo.page(
          botId: any(named: 'botId'),
          chatLid: any(named: 'chatLid'),
        ),
      );
    },
  );

  blocTest<AiLogBloc, AiLogState>(
    'drill-through: sin corrida (mensaje ajeno a la IA) → Loaded vacío',
    build: () {
      when(
        () =>
            repo.runForMessage(botId: 'b1', chatLid: 'c1', externalId: 'WAM9'),
      ).thenAnswer((_) async => null);
      return AiLogBloc(
        repo: repo,
        botId: 'b1',
        chatLid: 'c1',
        targetExternalId: 'WAM9',
      );
    },
    act: (bloc) => bloc.add(const AiLogLoadRequested()),
    expect: () => <Matcher>[
      isA<AiLogLoaded>().having((s) => s.entries, 'entries', isEmpty),
    ],
    verify: (_) {
      verifyNever(
        () => repo.byRun(
          botId: any(named: 'botId'),
          chatLid: any(named: 'chatLid'),
          runId: any(named: 'runId'),
        ),
      );
    },
  );

  blocTest<AiLogBloc, AiLogState>(
    'drill ?run=: carga la corrida DIRECTO por runId con su desenlace '
    '(sin resolver wamid)',
    build: () {
      when(
        () => repo.byRun(botId: 'b1', chatLid: 'c1', runId: 'run-7'),
      ).thenAnswer(
        (_) async => AiLogRunResult(
          items: <AiLogEntry>[e(7)],
          run: AiRunOutcome(
            status: 'COMPLETED',
            error: '',
            iterations: 3,
            tokensIn: 100,
            tokensOut: 40,
            startedAt: DateTime.utc(2026, 7, 1, 10),
            endedAt: DateTime.utc(2026, 7, 1, 10, 0, 12),
          ),
        ),
      );
      return AiLogBloc(
        repo: repo,
        botId: 'b1',
        chatLid: 'c1',
        targetRunId: 'run-7',
      );
    },
    act: (bloc) => bloc.add(const AiLogLoadRequested()),
    expect: () => <Matcher>[
      isA<AiLogLoaded>()
          .having((s) => s.entries.length, 'entries', 1)
          .having((s) => s.drill, 'drill', isTrue)
          .having((s) => s.run?.failed, 'desenlace ok', isFalse),
    ],
    verify: (_) {
      verifyNever(
        () => repo.runForMessage(
          botId: any(named: 'botId'),
          chatLid: any(named: 'chatLid'),
          externalId: any(named: 'externalId'),
        ),
      );
      verifyNever(
        () => repo.page(
          botId: any(named: 'botId'),
          chatLid: any(named: 'chatLid'),
        ),
      );
    },
  );

  blocTest<AiLogBloc, AiLogState>(
    'fallo del load → Failed',
    build: () {
      when(
        () => repo.page(botId: 'b1', chatLid: 'c1'),
      ).thenThrow(const AiLogNetworkFailure());
      return AiLogBloc(repo: repo, botId: 'b1', chatLid: 'c1');
    },
    act: (bloc) => bloc.add(const AiLogLoadRequested()),
    expect: () => <Matcher>[isA<AiLogFailed>()],
  );
}
