import 'package:agentic/core/design/app_design_theme.dart';
import 'package:agentic/features/flows/domain/entities/flow.dart' as fdom;
import 'package:agentic/features/triggers/domain/entities/trigger.dart';
import 'package:agentic/features/triggers/domain/failures/triggers_failure.dart';
import 'package:agentic/features/triggers/presentation/bloc/triggers_bloc.dart';
import 'package:agentic/features/triggers/presentation/widgets/flow_triggers_tab.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTriggersBloc extends MockBloc<TriggersEvent, TriggersState>
    implements TriggersBloc {}

fdom.Flow _flow({String id = 'f1', String name = 'Bienvenida'}) => fdom.Flow(
  id: id,
  templateId: 'tpl1',
  name: name,
  isActive: true,
  version: 1,
  cooldownMs: 0,
  usageLimit: 0,
  excludesFlows: const <String>[],
);

Trigger _text({
  String id = 't1',
  String keyword = 'menu',
  String flowId = 'f1',
}) => Trigger(
  id: id,
  templateId: 'tpl1',
  flowId: flowId,
  triggerType: TriggerType.text,
  matchType: MatchType.contains,
  keyword: keyword,
  labelId: '',
  labelAction: null,
  scope: TriggerScope.both,
  isActive: true,
  createdAt: DateTime.utc(2026, 5, 1),
  updatedAt: DateTime.utc(2026, 5, 1),
);

/// `FlowTriggersBody` es la unidad bajo prueba: consumer-only, espera
/// el `TriggersBloc` en el árbol. El wrapper `FlowTriggersTab` que
/// construye el bloc se cubre por separado en el cycle de cableado del
/// FlowDetailPage.
Widget _harness({
  required _MockTriggersBloc triggers,
  required fdom.Flow flow,
}) => MaterialApp(
  theme: AppDesignTheme.dark(),
  home: BlocProvider<TriggersBloc>.value(
    value: triggers,
    child: Scaffold(body: FlowTriggersBody(flow: flow)),
  ),
);

void main() {
  late _MockTriggersBloc triggers;

  setUp(() {
    triggers = _MockTriggersBloc();
  });

  testWidgets('Loading muestra spinner con key flow_triggers.loading', (
    tester,
  ) async {
    when(() => triggers.state).thenReturn(const TriggersLoading());

    await tester.pumpWidget(_harness(triggers: triggers, flow: _flow()));

    expect(find.byKey(const Key('flow_triggers.loading')), findsOneWidget);
  });

  testWidgets('Loaded con lista vacía muestra empty state flow-scope', (
    tester,
  ) async {
    when(() => triggers.state).thenReturn(const TriggersLoaded(<Trigger>[]));

    await tester.pumpWidget(_harness(triggers: triggers, flow: _flow()));

    expect(find.byKey(const Key('flow_triggers.empty')), findsOneWidget);
    expect(
      find.textContaining('Este flujo aún no tiene disparadores'),
      findsOneWidget,
    );
    // El add button SÍ está presente aunque la lista esté vacía.
    expect(find.byKey(const Key('flow_triggers.add_button')), findsOneWidget);
  });

  testWidgets(
    'Loaded filtra los triggers: solo los que matchean flow.id se renderizan',
    (tester) async {
      // Mezcla deliberada: el endpoint /templates/:id/triggers devuelve
      // todos los triggers de la template; el tab debe ocultar los que
      // no pertenezcan al flow del scope.
      when(() => triggers.state).thenReturn(
        TriggersLoaded(<Trigger>[
          _text(id: 'mine-a', keyword: 'hola', flowId: 'f1'),
          _text(id: 'other', keyword: 'pagos', flowId: 'f2'),
          _text(id: 'mine-b', keyword: 'menu', flowId: 'f1'),
        ]),
      );

      await tester.pumpWidget(
        _harness(
          triggers: triggers,
          flow: _flow(id: 'f1'),
        ),
      );

      expect(find.byKey(const Key('flow_triggers.row.mine-a')), findsOneWidget);
      expect(find.byKey(const Key('flow_triggers.row.mine-b')), findsOneWidget);
      expect(find.byKey(const Key('flow_triggers.row.other')), findsNothing);
      // Ningún row debe mostrar la pill "→ flow", redundante en scope.
      expect(find.textContaining('→'), findsNothing);
    },
  );

  testWidgets('Failed muestra copy flow-scope + retry', (tester) async {
    when(
      () => triggers.state,
    ).thenReturn(const TriggersFailed(TriggersNetworkFailure()));

    await tester.pumpWidget(_harness(triggers: triggers, flow: _flow()));

    expect(find.byKey(const Key('flow_triggers.failed')), findsOneWidget);
  });

  testWidgets(
    'Failed NotFound del template padre cae a copy flow-scope sin retry',
    (tester) async {
      when(
        () => triggers.state,
      ).thenReturn(const TriggersFailed(TriggersNotFoundFailure()));

      await tester.pumpWidget(_harness(triggers: triggers, flow: _flow()));

      expect(find.byKey(const Key('flow_triggers.failed')), findsOneWidget);
      // No queremos botón "Reintentar" cuando el template ya no existe.
      expect(find.text('Reintentar'), findsNothing);
    },
  );

  testWidgets('Mutating preserva la lista visible (snapshot)', (tester) async {
    when(
      () => triggers.state,
    ).thenReturn(TriggersMutating(<Trigger>[_text(id: 'a', flowId: 'f1')]));

    await tester.pumpWidget(
      _harness(
        triggers: triggers,
        flow: _flow(id: 'f1'),
      ),
    );

    expect(find.byKey(const Key('flow_triggers.row.a')), findsOneWidget);
  });

  testWidgets('tap en add_button abre el TriggerEditSheet con scopedFlow', (
    tester,
  ) async {
    when(() => triggers.state).thenReturn(const TriggersLoaded(<Trigger>[]));

    await tester.pumpWidget(
      _harness(
        triggers: triggers,
        flow: _flow(id: 'f1', name: 'Bienvenida'),
      ),
    );
    await tester.tap(find.byKey(const Key('flow_triggers.add_button')));
    await tester.pumpAndSettle();

    // El sheet aparece — verificamos la presencia del título de create
    // y que la línea fija renderiza el nombre del flow (no el dropdown).
    expect(find.text('Nuevo disparador'), findsOneWidget);
    expect(find.byKey(const Key('trigger_edit.flow_fixed')), findsOneWidget);
    expect(find.byKey(const Key('trigger_edit.flow_dropdown')), findsNothing);
  });

  testWidgets('tap en una row abre el sheet en modo edit con scopedFlow', (
    tester,
  ) async {
    when(() => triggers.state).thenReturn(
      TriggersLoaded(<Trigger>[
        _text(id: 'mine', keyword: 'hola', flowId: 'f1'),
      ]),
    );

    await tester.pumpWidget(
      _harness(
        triggers: triggers,
        flow: _flow(id: 'f1', name: 'Bienvenida'),
      ),
    );
    await tester.tap(find.byKey(const Key('flow_triggers.row.mine.tap')));
    await tester.pumpAndSettle();

    expect(find.text('Editar disparador'), findsOneWidget);
    expect(find.byKey(const Key('trigger_edit.flow_fixed')), findsOneWidget);
  });
}
