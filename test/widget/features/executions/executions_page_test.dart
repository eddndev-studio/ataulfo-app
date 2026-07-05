import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_empty_state.dart';
import 'package:ataulfo/core/design/widgets/app_error_state.dart';
import 'package:ataulfo/core/design/widgets/app_loading_indicator.dart';
import 'package:ataulfo/core/util/smart_timestamp.dart';
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
    // El spinner de página es el primitivo canónico del kit.
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
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

  testWidgets('la fila usa la tipografía del theme (título y timestamp)', (
    tester,
  ) async {
    final exe = _exe('exe-1', ExecutionStatus.completed, 'flw-1');
    when(() => cubit.state).thenReturn(
      ExecutionsLoaded(
        executions: <Execution>[exe],
        flowNames: const <String, String>{'flw-1': 'Bienvenida'},
      ),
    );

    await tester.pumpWidget(host());

    // Título con titleMedium (paridad con BotTile/TemplateTile), no un
    // TextStyle crudo calcado a mano.
    final theme = Theme.of(tester.element(find.text('Bienvenida')));
    final title = tester.widget<Text>(find.text('Bienvenida'));
    expect(title.style, theme.textTheme.titleMedium);

    // Timestamp con labelSmall atenuado, no un calco manual de captionSize.
    final ts = tester.widget<Text>(
      find.text(smartTimestamp(exe.startedAt.millisecondsSinceEpoch)),
    );
    expect(
      ts.style,
      theme.textTheme.labelSmall?.copyWith(color: AppTokens.textDisabled),
    );
  });

  testWidgets('loaded ofrece pull-to-refresh que dispara load', (tester) async {
    when(() => cubit.state).thenReturn(
      ExecutionsLoaded(
        executions: <Execution>[
          _exe('exe-1', ExecutionStatus.completed, 'flw-1'),
        ],
        flowNames: const <String, String>{'flw-1': 'Bienvenida'},
      ),
    );
    when(() => cubit.load()).thenAnswer((_) async {});

    await tester.pumpWidget(host());

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    verify(() => cubit.load()).called(1);
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
    // El vacío rico canónico del kit, en su variante informativa (sin CTA).
    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.byType(AppButton), findsNothing);
  });

  testWidgets('el vacío ofrece pull-to-refresh que dispara load', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const ExecutionsLoaded(
        executions: <Execution>[],
        flowNames: <String, String>{},
      ),
    );
    when(() => cubit.load()).thenAnswer((_) async {});

    await tester.pumpWidget(host());

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    verify(() => cubit.load()).called(1);
  });

  testWidgets('failed muestra error y reintentar dispara load', (tester) async {
    when(
      () => cubit.state,
    ).thenReturn(const ExecutionsFailed(ExecutionNetworkFailure()));
    when(() => cubit.load()).thenAnswer((_) async {});

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('executions.error')), findsOneWidget);
    // La card de error es el primitivo canónico del kit.
    expect(find.byType(AppErrorState), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    verify(() => cubit.load()).called(1);
  });

  testWidgets('forbidden explica el permiso y NO ofrece reintento', (
    tester,
  ) async {
    when(
      () => cubit.state,
    ).thenReturn(const ExecutionsFailed(ExecutionForbiddenFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('executions.error')), findsOneWidget);
    expect(find.textContaining('permisos de administrador'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Reintentar'), findsNothing);
  });

  testWidgets('el error ofrece pull-to-refresh que dispara load', (
    tester,
  ) async {
    when(
      () => cubit.state,
    ).thenReturn(const ExecutionsFailed(ExecutionNetworkFailure()));
    when(() => cubit.load()).thenAnswer((_) async {});

    await tester.pumpWidget(host());

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    verify(() => cubit.load()).called(1);
  });
}
