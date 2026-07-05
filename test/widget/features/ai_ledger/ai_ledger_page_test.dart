import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/features/ai_ledger/domain/entities/ledger_action.dart';
import 'package:ataulfo/features/ai_ledger/domain/failures/ai_ledger_failure.dart';
import 'package:ataulfo/features/ai_ledger/presentation/bloc/ai_ledger_bloc.dart';
import 'package:ataulfo/features/ai_ledger/presentation/pages/ai_ledger_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<AiLedgerEvent, AiLedgerState>
    implements AiLedgerBloc {}

LedgerAction _a(int id, String tool, String action, String detail) =>
    LedgerAction(
      id: id,
      runId: 'R',
      toolName: tool,
      action: action,
      detail: detail,
      createdAt: DateTime.utc(2026, 6, 12, 10),
    );

void main() {
  late _MockBloc bloc;
  setUp(() => bloc = _MockBloc());

  Future<void> pump(WidgetTester tester, AiLedgerState state) async {
    whenListen(bloc, const Stream<AiLedgerState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: BlocProvider<AiLedgerBloc>.value(
            value: bloc,
            child: const AiLedgerPage(),
          ),
        ),
      ),
    );
  }

  testWidgets('Loaded pinta las acciones (frase + detalle) y cargar más', (
    tester,
  ) async {
    await pump(
      tester,
      AiLedgerLoaded(
        items: <LedgerAction>[
          _a(2, 'apply_label', 'Aplicó una etiqueta', 'VIP'),
          _a(1, 'run_flow', 'Corrió un flujo', 'bienvenida'),
        ],
        nextBefore: 1,
        isLoadingMore: false,
      ),
    );
    expect(find.text('Aplicó una etiqueta'), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('Corrió un flujo'), findsOneWidget);
    expect(find.byKey(const Key('ai_ledger.load_more')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai_ledger.load_more')));
    verify(() => bloc.add(const AiLedgerMoreRequested())).called(1);
  });

  testWidgets('vacío muestra el aviso', (tester) async {
    await pump(
      tester,
      const AiLedgerLoaded(
        items: <LedgerAction>[],
        nextBefore: null,
        isLoadingMore: false,
      ),
    );
    expect(find.byKey(const Key('ai_ledger.empty')), findsOneWidget);
  });

  testWidgets('error muestra copy + reintentar', (tester) async {
    await pump(tester, const AiLedgerFailed(AiLedgerForbiddenFailure()));
    expect(find.byKey(const Key('ai_ledger.error')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai_ledger.retry')));
    verify(() => bloc.add(const AiLedgerLoadRequested())).called(1);
  });

  testWidgets('la lista reserva el inset inferior del sistema en su padding', (
    tester,
  ) async {
    whenListen(
      bloc,
      const Stream<AiLedgerState>.empty(),
      initialState: AiLedgerLoaded(
        items: <LedgerAction>[
          _a(1, 'run_flow', 'Corrió un flujo', 'bienvenida'),
        ],
        nextBefore: null,
        isLoadingMore: false,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(viewPadding: const EdgeInsets.only(bottom: 34)),
              child: BlocProvider<AiLedgerBloc>.value(
                value: bloc,
                child: const AiLedgerPage(),
              ),
            ),
          ),
        ),
      ),
    );

    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.padding?.resolve(TextDirection.ltr).bottom, AppTokens.sp4 + 34);
  });
}
