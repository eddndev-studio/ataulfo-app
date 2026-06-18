import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/executions/domain/entities/execution.dart';
import 'package:ataulfo/features/executions/domain/failures/execution_failure.dart';
import 'package:ataulfo/features/executions/presentation/cubit/executions_cubit.dart';
import 'package:ataulfo/features/executions/presentation/pages/executions_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCubit extends MockCubit<ExecutionsState>
    implements ExecutionsCubit {}

Execution _exe(
  String id,
  ExecutionStatus status,
  String flowId, {
  String error = '',
}) => Execution(
  id: id,
  botId: 'b1',
  chatLid: 'c1',
  flowId: flowId,
  templateId: 'tpl-1',
  status: status,
  error: error,
  currentStep: 1,
  startedAt: DateTime.utc(2026, 6, 14, 9),
  endedAt: status == ExecutionStatus.running
      ? null
      : DateTime.utc(2026, 6, 14, 9, 1),
);

void main() {
  late _MockCubit cubit;

  setUp(() {
    cubit = _MockCubit();
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<ExecutionsCubit>.value(
      value: cubit,
      child: const Scaffold(body: ExecutionsPage()),
    ),
  );

  testWidgets('loading muestra spinner', (tester) async {
    when(() => cubit.state).thenReturn(const ExecutionsLoading());

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('executions.loading')), findsOneWidget);
  });

  testWidgets('loaded pinta nombre del flujo, estado y error', (tester) async {
    when(() => cubit.state).thenReturn(
      ExecutionsLoaded(
        executions: <Execution>[
          _exe(
            'exe-1',
            ExecutionStatus.failed,
            'flw-1',
            error: 'send_failed: upload failed with status code 400',
          ),
        ],
        flowNames: const <String, String>{'flw-1': 'Bienvenida'},
      ),
    );

    await tester.pumpWidget(host());

    expect(find.text('Bienvenida'), findsOneWidget); // nombre resuelto
    expect(find.text('Fallido'), findsOneWidget); // pill de estado
    expect(
      find.textContaining('status code 400'),
      findsOneWidget,
    ); // error inline
  });

  testWidgets('sin nombre resuelto cae al flowId', (tester) async {
    when(() => cubit.state).thenReturn(
      ExecutionsLoaded(
        executions: <Execution>[
          _exe('exe-2', ExecutionStatus.completed, 'flw-9'),
        ],
        flowNames: const <String, String>{},
      ),
    );

    await tester.pumpWidget(host());

    expect(find.textContaining('flw-9'), findsOneWidget);
  });

  testWidgets('empty muestra estado vacío', (tester) async {
    when(() => cubit.state).thenReturn(
      const ExecutionsLoaded(
        executions: <Execution>[],
        flowNames: <String, String>{},
      ),
    );

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('executions.empty')), findsOneWidget);
  });

  testWidgets('failed muestra error y reintentar dispara load', (tester) async {
    when(
      () => cubit.state,
    ).thenReturn(const ExecutionsFailed(ExecutionNetworkFailure()));
    when(() => cubit.load()).thenAnswer((_) async {});

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('executions.error')), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    verify(() => cubit.load()).called(1);
  });
}
