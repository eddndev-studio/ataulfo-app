import 'dart:async';

import 'package:agentic/features/flows/domain/entities/flow.dart' as fdom;
import 'package:agentic/features/flows/domain/repositories/flows_repository.dart';
import 'package:agentic/features/flows/presentation/bloc/flows_bloc.dart';
import 'package:agentic/features/triggers/domain/entities/trigger.dart';
import 'package:agentic/features/triggers/domain/failures/triggers_failure.dart';
import 'package:agentic/features/triggers/domain/repositories/triggers_repository.dart';
import 'package:agentic/features/triggers/presentation/bloc/triggers_bloc.dart';
import 'package:agentic/features/triggers/presentation/widgets/triggers_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTriggersRepo extends Mock implements TriggersRepository {}

class _MockFlowsRepo extends Mock implements FlowsRepository {}

Trigger _text({
  String id = 't1',
  String keyword = 'menu',
  String flowId = 'f1',
  MatchType match = MatchType.contains,
  TriggerScope scope = TriggerScope.both,
  bool isActive = true,
}) => Trigger(
  id: id,
  templateId: 'tpl1',
  flowId: flowId,
  triggerType: TriggerType.text,
  matchType: match,
  keyword: keyword,
  labelId: '',
  labelAction: null,
  scope: scope,
  isActive: isActive,
  createdAt: DateTime.utc(2026, 5, 1),
  updatedAt: DateTime.utc(2026, 5, 1),
);

Trigger _label({
  String id = 't2',
  String labelId = 'lbl_vip',
  String flowId = 'f1',
  LabelAction action = LabelAction.add,
}) => Trigger(
  id: id,
  templateId: 'tpl1',
  flowId: flowId,
  triggerType: TriggerType.label,
  matchType: null,
  keyword: '',
  labelId: labelId,
  labelAction: action,
  scope: TriggerScope.both,
  isActive: true,
  createdAt: DateTime.utc(2026, 5, 1),
  updatedAt: DateTime.utc(2026, 5, 1),
);

fdom.Flow _flow({String id = 'f1', String name = 'Bienvenida'}) =>
    fdom.Flow(id: id, templateId: 'tpl1', name: name, isActive: true, version: 1);

Widget _harness({
  required TriggersBloc triggersBloc,
  required FlowsBloc flowsBloc,
}) => MaterialApp(
  home: Scaffold(
    body: MultiBlocProvider(
      providers: <BlocProvider<Object?>>[
        BlocProvider<TriggersBloc>.value(value: triggersBloc),
        BlocProvider<FlowsBloc>.value(value: flowsBloc),
      ],
      child: const TriggersSection(),
    ),
  ),
);

void main() {
  late _MockTriggersRepo triggersRepo;
  late _MockFlowsRepo flowsRepo;

  setUp(() {
    triggersRepo = _MockTriggersRepo();
    flowsRepo = _MockFlowsRepo();
  });

  testWidgets('Loading inicial muestra spinner', (tester) async {
    // Completer que nunca completa: mantiene el bloc en Loading sin
    // dejar timers pendientes que rompen el invariante post-dispose.
    final pending = Completer<List<Trigger>>();
    when(() => triggersRepo.listTriggers('tpl1')).thenAnswer((_) => pending.future);
    when(() => flowsRepo.listFlows('tpl1'))
        .thenAnswer((_) async => <fdom.Flow>[_flow()]);

    final tBloc = TriggersBloc(repo: triggersRepo, templateId: 'tpl1');
    final fBloc = FlowsBloc(repo: flowsRepo, templateId: 'tpl1')
      ..add(const FlowsLoadRequested());

    await tester.pumpWidget(_harness(triggersBloc: tBloc, flowsBloc: fBloc));
    expect(find.byKey(const Key('triggers.loading')), findsOneWidget);

    tBloc.close();
    fBloc.close();
    pending.complete(const <Trigger>[]);
  });

  testWidgets('Loaded vacío muestra empty state inline', (tester) async {
    when(() => triggersRepo.listTriggers('tpl1'))
        .thenAnswer((_) async => const <Trigger>[]);
    when(() => flowsRepo.listFlows('tpl1'))
        .thenAnswer((_) async => <fdom.Flow>[_flow()]);

    final tBloc = TriggersBloc(repo: triggersRepo, templateId: 'tpl1')
      ..add(const TriggersLoadRequested());
    final fBloc = FlowsBloc(repo: flowsRepo, templateId: 'tpl1')
      ..add(const FlowsLoadRequested());

    await tester.pumpWidget(_harness(triggersBloc: tBloc, flowsBloc: fBloc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('triggers.empty')), findsOneWidget);

    tBloc.close();
    fBloc.close();
  });

  testWidgets(
    'Loaded con TEXT trigger renderiza keyword + matchType + scope + flow name',
    (tester) async {
      when(() => triggersRepo.listTriggers('tpl1')).thenAnswer(
        (_) async => <Trigger>[
          _text(keyword: 'comprar', match: MatchType.exact, scope: TriggerScope.incoming),
        ],
      );
      when(() => flowsRepo.listFlows('tpl1')).thenAnswer(
        (_) async => <fdom.Flow>[_flow(name: 'Bienvenida')],
      );

      final tBloc = TriggersBloc(repo: triggersRepo, templateId: 'tpl1')
        ..add(const TriggersLoadRequested());
      final fBloc = FlowsBloc(repo: flowsRepo, templateId: 'tpl1')
        ..add(const FlowsLoadRequested());

      await tester.pumpWidget(_harness(triggersBloc: tBloc, flowsBloc: fBloc));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('triggers.row.t1')), findsOneWidget);
      expect(find.text('comprar'), findsOneWidget);
      // chips de matchType y scope humanizados
      expect(find.text('Exacto'), findsOneWidget);
      expect(find.text('Entrante'), findsOneWidget);
      // flow target resuelto por nombre (con prefijo de flecha), no por id
      expect(find.textContaining('Bienvenida'), findsOneWidget);
      expect(find.byKey(const Key('triggers.row.t1.flow_fallback')), findsNothing);

      tBloc.close();
      fBloc.close();
    },
  );

  testWidgets(
    'Loaded con LABEL trigger renderiza labelId + labelAction humanizada',
    (tester) async {
      when(() => triggersRepo.listTriggers('tpl1')).thenAnswer(
        (_) async => <Trigger>[_label(labelId: 'lbl_vip', action: LabelAction.remove)],
      );
      when(() => flowsRepo.listFlows('tpl1')).thenAnswer(
        (_) async => <fdom.Flow>[_flow(name: 'Bienvenida')],
      );

      final tBloc = TriggersBloc(repo: triggersRepo, templateId: 'tpl1')
        ..add(const TriggersLoadRequested());
      final fBloc = FlowsBloc(repo: flowsRepo, templateId: 'tpl1')
        ..add(const FlowsLoadRequested());

      await tester.pumpWidget(_harness(triggersBloc: tBloc, flowsBloc: fBloc));
      await tester.pumpAndSettle();

      expect(find.text('lbl_vip'), findsOneWidget);
      // Acción "Quitar etiqueta" en chip
      expect(find.text('Quitar etiqueta'), findsOneWidget);

      tBloc.close();
      fBloc.close();
    },
  );

  testWidgets(
    'flowId no resuelto (FlowsBloc todavía Loading) muestra id truncado en monospace',
    (tester) async {
      when(() => triggersRepo.listTriggers('tpl1')).thenAnswer(
        (_) async => <Trigger>[_text(flowId: 'flow-xyz-9999')],
      );
      final pendingFlows = Completer<List<fdom.Flow>>();
      when(
        () => flowsRepo.listFlows('tpl1'),
      ).thenAnswer((_) => pendingFlows.future);

      final tBloc = TriggersBloc(repo: triggersRepo, templateId: 'tpl1')
        ..add(const TriggersLoadRequested());
      final fBloc = FlowsBloc(repo: flowsRepo, templateId: 'tpl1')
        ..add(const FlowsLoadRequested());

      await tester.pumpWidget(_harness(triggersBloc: tBloc, flowsBloc: fBloc));
      // pump suficiente para que triggers cargue pero flows quede Loading
      await tester.pump();
      await tester.pump();

      // El widget muestra el id del flow como fallback (sin nombre resuelto)
      expect(find.byKey(const Key('triggers.row.t1.flow_fallback')), findsOneWidget);
      expect(find.text('flow-xyz-9999'), findsOneWidget);

      tBloc.close();
      fBloc.close();
      pendingFlows.complete(const <fdom.Flow>[]);
    },
  );

  testWidgets('Failed reintentable muestra botón Reintentar', (tester) async {
    var calls = 0;
    when(() => triggersRepo.listTriggers('tpl1')).thenAnswer((_) async {
      calls += 1;
      if (calls == 1) throw const TriggersNetworkFailure();
      return <Trigger>[_text()];
    });
    when(() => flowsRepo.listFlows('tpl1'))
        .thenAnswer((_) async => <fdom.Flow>[_flow()]);

    final tBloc = TriggersBloc(repo: triggersRepo, templateId: 'tpl1')
      ..add(const TriggersLoadRequested());
    final fBloc = FlowsBloc(repo: flowsRepo, templateId: 'tpl1')
      ..add(const FlowsLoadRequested());

    await tester.pumpWidget(_harness(triggersBloc: tBloc, flowsBloc: fBloc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('triggers.failed')), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    // Tras retry, llega Loaded
    expect(find.byKey(const Key('triggers.row.t1')), findsOneWidget);

    tBloc.close();
    fBloc.close();
  });

  testWidgets('Failed NotFound es terminal — sin botón Reintentar', (tester) async {
    when(() => triggersRepo.listTriggers('tpl1'))
        .thenThrow(const TriggersNotFoundFailure());
    when(() => flowsRepo.listFlows('tpl1'))
        .thenAnswer((_) async => <fdom.Flow>[_flow()]);

    final tBloc = TriggersBloc(repo: triggersRepo, templateId: 'tpl1')
      ..add(const TriggersLoadRequested());
    final fBloc = FlowsBloc(repo: flowsRepo, templateId: 'tpl1')
      ..add(const FlowsLoadRequested());

    await tester.pumpWidget(_harness(triggersBloc: tBloc, flowsBloc: fBloc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('triggers.failed')), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);

    tBloc.close();
    fBloc.close();
  });
}
