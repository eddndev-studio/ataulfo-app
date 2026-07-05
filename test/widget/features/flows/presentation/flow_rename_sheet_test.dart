import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/flows/domain/entities/flow.dart' as fdom;
import 'package:ataulfo/features/flows/domain/failures/flows_failure.dart';
import 'package:ataulfo/features/flows/presentation/bloc/flow_detail_bloc.dart';
import 'package:ataulfo/features/flows/presentation/widgets/flow_rename_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDetailBloc extends MockBloc<FlowDetailEvent, FlowDetailState>
    implements FlowDetailBloc {}

const _flow = fdom.Flow(
  id: 'f1',
  templateId: 't1',
  name: 'Bienvenida',
  isActive: true,
  version: 3,
  cooldownMs: 0,
  usageLimit: 0,
  excludesFlows: <String>[],
);

const _loaded = FlowDetailLoaded(_flow, <fdom.Flow>[], siblingsFailed: false);

void main() {
  setUpAll(() {
    registerFallbackValue(const FlowDetailRenameRequested(''));
  });

  late _MockDetailBloc bloc;

  setUp(() {
    bloc = _MockDetailBloc();
    when(() => bloc.state).thenReturn(_loaded);
  });

  /// Host con un botón que abre la hoja, como lo hace el menú del editor.
  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<FlowDetailBloc>.value(
      value: bloc,
      child: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => FlowRenameSheet.open(context, _flow),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('abre con el nombre actual pre-llenado', (tester) async {
    await open(tester);

    expect(find.text('Renombrar flujo'), findsOneWidget);
    final tf = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('flow_rename.name')),
        matching: find.byType(TextField),
      ),
    );
    expect(tf.controller?.text, 'Bienvenida');
  });

  testWidgets('submit dispatcha FlowDetailRenameRequested con el nombre '
      'trimmeado', (tester) async {
    await open(tester);

    await tester.enterText(
      find.byKey(const Key('flow_rename.name')),
      '  Onboarding  ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('flow_rename.submit')));
    await tester.pump();

    verify(
      () => bloc.add(const FlowDetailRenameRequested('Onboarding')),
    ).called(1);
  });

  testWidgets('nombre vacío deshabilita el submit', (tester) async {
    await open(tester);

    await tester.enterText(find.byKey(const Key('flow_rename.name')), '   ');
    await tester.pump();
    await tester.tap(find.byKey(const Key('flow_rename.submit')));
    await tester.pump();

    verifyNever(() => bloc.add(any()));
  });

  testWidgets('tras submit, la transición a Loaded cierra la hoja', (
    tester,
  ) async {
    final states = StreamController<FlowDetailState>.broadcast();
    addTearDown(states.close);
    whenListen(bloc, states.stream, initialState: _loaded);

    await open(tester);
    await tester.enterText(
      find.byKey(const Key('flow_rename.name')),
      'Onboarding',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('flow_rename.submit')));
    await tester.pump();

    states.add(
      const FlowDetailMutating(_flow, <fdom.Flow>[], siblingsFailed: false),
    );
    await tester.pump();
    states.add(_loaded);
    await tester.pumpAndSettle();

    expect(find.text('Renombrar flujo'), findsNothing);
  });

  testWidgets('MutationFailed muestra copy inline y la hoja sigue abierta', (
    tester,
  ) async {
    final states = StreamController<FlowDetailState>.broadcast();
    addTearDown(states.close);
    whenListen(bloc, states.stream, initialState: _loaded);

    await open(tester);
    await tester.enterText(
      find.byKey(const Key('flow_rename.name')),
      'Onboarding',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('flow_rename.submit')));
    await tester.pump();

    states.add(
      const FlowDetailMutationFailed(
        _flow,
        <fdom.Flow>[],
        FlowsConflictFailure(),
        siblingsFailed: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Renombrar flujo'), findsOneWidget);
    expect(
      find.textContaining('Otro operador editó este flujo'),
      findsOneWidget,
    );
  });

  testWidgets('un rebuild a Loaded SIN submit propio no cierra la hoja', (
    tester,
  ) async {
    final states = StreamController<FlowDetailState>.broadcast();
    addTearDown(states.close);
    whenListen(bloc, states.stream, initialState: _loaded);

    await open(tester);
    states.add(_loaded);
    await tester.pumpAndSettle();

    expect(find.text('Renombrar flujo'), findsOneWidget);
  });
}
