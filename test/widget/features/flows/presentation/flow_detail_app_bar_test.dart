import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/flows/domain/entities/flow.dart' as fdom;
import 'package:ataulfo/features/flows/domain/failures/flows_failure.dart';
import 'package:ataulfo/features/flows/presentation/bloc/flow_detail_bloc.dart';
import 'package:ataulfo/features/flows/presentation/widgets/flow_detail_app_bar.dart';
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

const _paused = fdom.Flow(
  id: 'f1',
  templateId: 't1',
  name: 'Bienvenida',
  isActive: false,
  version: 3,
  cooldownMs: 0,
  usageLimit: 0,
  excludesFlows: <String>[],
);

const _loaded = FlowDetailLoaded(_flow, <fdom.Flow>[], siblingsFailed: false);

void main() {
  setUpAll(() {
    registerFallbackValue(const FlowDetailSetActiveRequested(false));
  });

  late _MockDetailBloc bloc;

  setUp(() {
    bloc = _MockDetailBloc();
    when(() => bloc.state).thenReturn(_loaded);
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<FlowDetailBloc>.value(
      value: bloc,
      child: Scaffold(
        appBar: AppBar(
          title: const FlowDetailTitle(),
          actions: const <Widget>[FlowDetailMenuAction()],
        ),
        body: const SizedBox.shrink(),
      ),
    ),
  );

  group('FlowDetailTitle', () {
    testWidgets('con snapshot muestra el NOMBRE del flujo', (tester) async {
      await tester.pumpWidget(host());

      expect(find.widgetWithText(AppBar, 'Bienvenida'), findsOneWidget);
    });

    testWidgets('sin snapshot (Loading) cae al rótulo neutro', (tester) async {
      when(() => bloc.state).thenReturn(const FlowDetailLoading());

      await tester.pumpWidget(host());

      expect(find.widgetWithText(AppBar, 'Flujo'), findsOneWidget);
    });
  });

  group('FlowDetailMenuAction', () {
    testWidgets('sin snapshot no ofrece menú (no hay flujo que operar)', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(const FlowDetailFailed(FlowsServerFailure()));

      await tester.pumpWidget(host());

      expect(find.byKey(const Key('flow_detail.menu')), findsNothing);
    });

    testWidgets('ofrece Renombrar; elegirlo abre el form-sheet', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('flow_detail.menu')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('flow_detail.menu.rename')));
      await tester.pumpAndSettle();

      expect(find.text('Renombrar flujo'), findsOneWidget);
      final tf = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('flow_rename.name')),
          matching: find.byType(TextField),
        ),
      );
      expect(tf.controller?.text, 'Bienvenida');
    });

    testWidgets('flujo activo ofrece "Pausar" y dispatcha SetActive(false)', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('flow_detail.menu')));
      await tester.pumpAndSettle();

      expect(find.text('Pausar'), findsOneWidget);
      expect(find.text('Activar'), findsNothing);

      await tester.tap(find.byKey(const Key('flow_detail.menu.toggle_active')));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(const FlowDetailSetActiveRequested(false)),
      ).called(1);
    });

    testWidgets('flujo pausado ofrece "Activar" y dispatcha SetActive(true)', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const FlowDetailLoaded(_paused, <fdom.Flow>[], siblingsFailed: false),
      );

      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('flow_detail.menu')));
      await tester.pumpAndSettle();

      expect(find.text('Activar'), findsOneWidget);

      await tester.tap(find.byKey(const Key('flow_detail.menu.toggle_active')));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(const FlowDetailSetActiveRequested(true)),
      ).called(1);
    });
  });
}
