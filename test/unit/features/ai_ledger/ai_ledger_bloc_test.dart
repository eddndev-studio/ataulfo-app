import 'package:ataulfo/features/ai_ledger/domain/ai_ledger_repository.dart';
import 'package:ataulfo/features/ai_ledger/domain/entities/ledger_action.dart';
import 'package:ataulfo/features/ai_ledger/domain/failures/ai_ledger_failure.dart';
import 'package:ataulfo/features/ai_ledger/presentation/bloc/ai_ledger_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AiLedgerRepository {}

LedgerAction _a(int id) => LedgerAction(
  id: id,
  runId: 'R',
  toolName: 'apply_label',
  action: 'Aplicó una etiqueta',
  detail: 'VIP',
  createdAt: DateTime.utc(2026, 6, 12, 10),
);

void main() {
  late _MockRepo repo;
  setUp(() => repo = _MockRepo());

  blocTest<AiLedgerBloc, AiLedgerState>(
    'LoadRequested → Loading, Loaded(items)',
    build: () => AiLedgerBloc(repo: repo, botId: 'b1', chatLid: 'c1'),
    setUp: () {
      when(() => repo.page(botId: 'b1', chatLid: 'c1')).thenAnswer(
        (_) async => AiLedgerPageResult(
          items: <LedgerAction>[_a(2), _a(1)],
          nextBefore: 1,
        ),
      );
    },
    act: (b) => b.add(const AiLedgerLoadRequested()),
    expect: () => <dynamic>[
      isA<AiLedgerLoaded>()
          .having((s) => s.items.length, 'len', 2)
          .having((s) => s.nextBefore, 'cursor', 1),
    ],
  );

  blocTest<AiLedgerBloc, AiLedgerState>(
    'MoreRequested anexa la siguiente página y avanza el cursor',
    build: () => AiLedgerBloc(repo: repo, botId: 'b1', chatLid: 'c1'),
    seed: () => AiLedgerLoaded(
      items: <LedgerAction>[_a(5)],
      nextBefore: 5,
      isLoadingMore: false,
    ),
    setUp: () {
      when(() => repo.page(botId: 'b1', chatLid: 'c1', before: 5)).thenAnswer(
        (_) async =>
            AiLedgerPageResult(items: <LedgerAction>[_a(4)], nextBefore: null),
      );
    },
    act: (b) => b.add(const AiLedgerMoreRequested()),
    expect: () => <dynamic>[
      isA<AiLedgerLoaded>().having((s) => s.isLoadingMore, 'cargando', true),
      isA<AiLedgerLoaded>()
          .having((s) => s.items.length, 'len', 2)
          .having((s) => s.nextBefore, 'fin', null),
    ],
  );

  blocTest<AiLedgerBloc, AiLedgerState>(
    'fallo → Failed',
    build: () => AiLedgerBloc(repo: repo, botId: 'b1', chatLid: 'c1'),
    setUp: () {
      when(
        () => repo.page(botId: 'b1', chatLid: 'c1'),
      ).thenThrow(const AiLedgerForbiddenFailure());
    },
    act: (b) => b.add(const AiLedgerLoadRequested()),
    expect: () => <dynamic>[isA<AiLedgerFailed>()],
  );
}
