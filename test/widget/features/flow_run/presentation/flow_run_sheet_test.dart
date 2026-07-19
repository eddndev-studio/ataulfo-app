import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_action_row.dart';
import 'package:ataulfo/features/flow_run/domain/entities/runnable_flow.dart';
import 'package:ataulfo/features/flow_run/domain/failures/flow_run_failure.dart';
import 'package:ataulfo/features/flow_run/presentation/bloc/flow_run_cubit.dart';
import 'package:ataulfo/features/flow_run/presentation/widgets/flow_run_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFlowRunCubit extends MockCubit<FlowRunState>
    implements FlowRunCubit {}

void main() {
  late _MockFlowRunCubit cubit;

  setUp(() {
    cubit = _MockFlowRunCubit();
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(
      body: BlocProvider<FlowRunCubit>.value(
        value: cubit,
        child: const FlowRunSheet(chatLid: 'lid-1'),
      ),
    ),
  );

  testWidgets('fallo transitorio: muestra el error y Reintentar recarga', (
    tester,
  ) async {
    when(
      () => cubit.state,
    ).thenReturn(const FlowRunFailed(FlowRunNetworkFailure()));
    when(() => cubit.load()).thenAnswer((_) async {});

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('flow_run.error')), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pump();

    verify(() => cubit.load()).called(1);
  });

  testWidgets('fallo terminal (Forbidden): sin botón Reintentar', (
    tester,
  ) async {
    // Reintentar un 403 devolvería el mismo 403: ofrecerlo es ruido.
    when(
      () => cubit.state,
    ).thenReturn(const FlowRunFailed(FlowRunForbiddenFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('flow_run.error')), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  group('anatomía de menú-sheet', () {
    testWidgets('H1 titleLarge y filas de acción del kit', (tester) async {
      when(() => cubit.state).thenReturn(
        const FlowRunLoaded(<RunnableFlow>[
          RunnableFlow(id: 'f1', name: 'Bienvenida'),
        ]),
      );
      await tester.pumpWidget(host());

      final h1 = tester.widget<Text>(find.text('Correr un flujo'));
      expect(h1.style?.fontSize, AppTokens.titleLSize);

      final tile = tester.widget<AppActionRow>(
        find.byKey(const Key('flow_run.item.f1')),
      );
      expect(tile.tone, AppActionRowTone.primary);
      expect(tile.title, 'Bienvenida');
    });
  });
}
