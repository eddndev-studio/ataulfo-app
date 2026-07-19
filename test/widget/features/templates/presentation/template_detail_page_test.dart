import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_avatar.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/flows/domain/entities/flow.dart' as flows;
import 'package:ataulfo/features/flows/presentation/bloc/flows_bloc.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:ataulfo/features/templates/domain/entities/variable_def.dart';
import 'package:ataulfo/features/templates/domain/failures/templates_failure.dart';
import 'package:ataulfo/features/templates/presentation/bloc/template_detail_bloc.dart';
import 'package:ataulfo/features/templates/presentation/bloc/var_defs_bloc.dart';
import 'package:ataulfo/features/templates/presentation/pages/template_detail_page.dart';
import 'package:ataulfo/features/templates/presentation/widgets/template_rename_sheet.dart';
import 'package:ataulfo/features/triggers/domain/entities/trigger.dart';
import 'package:ataulfo/features/triggers/presentation/bloc/triggers_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<TemplateDetailEvent, TemplateDetailState>
    implements TemplateDetailBloc {}

class _MockVarDefsBloc extends MockBloc<VarDefsEvent, VarDefsState>
    implements VarDefsBloc {}

class _MockFlowsBloc extends MockBloc<FlowsEvent, FlowsState>
    implements FlowsBloc {}

class _MockTriggersBloc extends MockBloc<TriggersEvent, TriggersState>
    implements TriggersBloc {}

const _ai = AIConfig(
  enabled: true,
  provider: AIProvider.gemini,
  model: 'gemini-3.1-pro-preview',
  temperature: 0.7,
  thinkingLevel: ThinkingLevel.medium,
  systemPrompt: 'Eres un asistente de soporte amable.',
  contextMessages: 20,
);

const _tpl = Template(
  id: 't1',
  orgId: 'o1',
  name: 'Soporte',
  version: 3,
  ai: _ai,
);

flows.Flow _flow({
  required String id,
  required String name,
  bool isActive = true,
}) => flows.Flow(
  id: id,
  templateId: 't1',
  name: name,
  isActive: isActive,
  version: 1,
  cooldownMs: 0,
  usageLimit: 0,
  excludesFlows: const <String>[],
);

void main() {
  setUpAll(() {
    registerFallbackValue(const TemplateDetailLoadRequested());
    registerFallbackValue(const VarDefsLoadRequested());
    registerFallbackValue(const FlowsLoadRequested());
    registerFallbackValue(const TriggersLoadRequested());
  });

  late _MockBloc bloc;
  late _MockVarDefsBloc varDefsBloc;
  late _MockFlowsBloc flowsBloc;
  late _MockTriggersBloc triggersBloc;

  setUp(() {
    bloc = _MockBloc();
    varDefsBloc = _MockVarDefsBloc();
    flowsBloc = _MockFlowsBloc();
    triggersBloc = _MockTriggersBloc();
    when(() => bloc.state).thenReturn(const TemplateDetailLoading());
    // Defaults en Loaded vacío (estado terminal sin animaciones); los tests
    // del launcher sobreescriben estos stubs.
    when(
      () => varDefsBloc.state,
    ).thenReturn(const VarDefsLoaded(<VariableDef>[], 1));
    when(() => flowsBloc.state).thenReturn(const FlowsLoaded(<flows.Flow>[]));
    when(
      () => triggersBloc.state,
    ).thenReturn(const TriggersLoaded(<Trigger>[]));
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<TemplateDetailBloc>.value(value: bloc),
        BlocProvider<VarDefsBloc>.value(value: varDefsBloc),
        BlocProvider<FlowsBloc>.value(value: flowsBloc),
        BlocProvider<TriggersBloc>.value(value: triggersBloc),
      ],
      // TemplateDetailPage es content-only; el host envuelve en Scaffold
      // para dar Material upstream a los widgets internos.
      child: const Scaffold(body: TemplateDetailPage()),
    ),
  );

  /// Monta el detalle bajo un GoRouter con [destinationPath] registrado,
  /// tapea [tapKey] y devuelve la URI alcanzada + canPop en el destino.
  Future<({String? uri, List<bool> canPop})> pushFrom(
    WidgetTester tester, {
    required Key tapKey,
    required String destinationPath,
  }) async {
    final canPopAtDestination = <bool>[];
    String? destinationUri;
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<TemplateDetailBloc>.value(value: bloc),
              BlocProvider<VarDefsBloc>.value(value: varDefsBloc),
              BlocProvider<FlowsBloc>.value(value: flowsBloc),
              BlocProvider<TriggersBloc>.value(value: triggersBloc),
            ],
            child: const Scaffold(body: TemplateDetailPage()),
          ),
        ),
        GoRoute(
          path: destinationPath,
          builder: (_, state) {
            destinationUri = state.uri.toString();
            return Scaffold(
              body: Builder(
                builder: (ctx) {
                  canPopAtDestination.add(Navigator.of(ctx).canPop());
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: AppDesignTheme.dark(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(tapKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(tapKey));
    await tester.pumpAndSettle();
    return (uri: destinationUri, canPop: canPopAtDestination);
  }

  testWidgets('Loading muestra spinner con AppTokens.primary', (tester) async {
    when(() => bloc.state).thenReturn(const TemplateDetailLoading());

    await tester.pumpWidget(host());

    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.valueColor?.value, AppTokens.primary);
  });

  testWidgets(
    'Loaded muestra el header de gradiente: nombre, provider · modelo y '
    'pills glass — sin avatar ni card vieja',
    (tester) async {
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));

      await tester.pumpWidget(host());

      final header = find.byKey(const Key('template_detail.header'));
      expect(header, findsOneWidget);
      expect(
        find.descendant(of: header, matching: find.text('Soporte')),
        findsOneWidget,
      );
      // El subtítulo combina proveedor humanizado y modelo en una línea.
      expect(
        find.descendant(of: header, matching: find.textContaining('Gemini')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: header,
          matching: find.textContaining('gemini-3.1-pro-preview'),
        ),
        findsOneWidget,
      );
      // Versión + estado IA en cápsulas dentro del header.
      expect(
        find.descendant(
          of: header,
          matching: find.widgetWithText(AppPill, 'v3'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: header,
          matching: find.widgetWithText(AppPill, 'IA habilitada'),
        ),
        findsOneWidget,
      );
      // El patrón viejo muere: ni avatar ni header card plana.
      expect(find.byType(AppAvatar), findsNothing);
      expect(
        find.byKey(const Key('template_detail.card.header')),
        findsNothing,
      );
    },
  );

  testWidgets('el header expone retorno y lápiz; los accesos del Asistente '
      'viven en el cuerpo', (tester) async {
    when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));

    await tester.pumpWidget(host());

    final header = find.byKey(const Key('template_detail.header'));
    expect(
      find.descendant(
        of: header,
        matching: find.byKey(const Key('template_detail.back')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: header,
        matching: find.byKey(const Key('template_detail.edit_button')),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('template_detail.link.resources')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('template_detail.link.channels')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('template_detail.link.preview')),
      findsOneWidget,
    );
  });

  testWidgets('Loaded muestra versión como AppPill', (tester) async {
    when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));

    await tester.pumpWidget(host());

    expect(find.widgetWithText(AppPill, 'v3'), findsOneWidget);
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('Loaded(enabled=true) muestra AppPill primary "IA habilitada"', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));

    await tester.pumpWidget(host());

    expect(find.widgetWithText(AppPill, 'IA habilitada'), findsOneWidget);
  });

  testWidgets(
    'Loaded(enabled=false) muestra AppPill neutral "IA deshabilitada"',
    (tester) async {
      const tplOff = Template(
        id: 't2',
        orgId: 'o1',
        name: 'Marketing',
        version: 1,
        ai: AIConfig(
          enabled: false,
          provider: AIProvider.openai,
          model: 'gpt-5-pro',
          temperature: 1.0,
          thinkingLevel: ThinkingLevel.low,
          systemPrompt: '',
          contextMessages: 10,
        ),
      );
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(tplOff));

      await tester.pumpWidget(host());

      // IA off es estado de configuración, no error → neutral (no danger).
      expect(find.widgetWithText(AppPill, 'IA deshabilitada'), findsOneWidget);
      expect(find.textContaining('OpenAI'), findsWidgets);
      // El nivel de razonamiento vive en el caption de la fila Motor IA.
      expect(find.textContaining('razonamiento bajo'), findsOneWidget);
    },
  );

  testWidgets('Failed(NotFound) preserva key y usa AppButton "Reintentar"', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const TemplateDetailFailed(TemplatesNotFoundFailure()));

    await tester.pumpWidget(host());

    expect(
      find.byKey(const Key('template_detail.error.not_found')),
      findsOneWidget,
    );
    expect(find.widgetWithText(AppButton, 'Reintentar'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('Failed(Network) preserva key genérica + AppButton', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const TemplateDetailFailed(TemplatesNetworkFailure()));

    await tester.pumpWidget(host());

    expect(
      find.byKey(const Key('template_detail.error.generic')),
      findsOneWidget,
    );
    expect(find.widgetWithText(AppButton, 'Reintentar'), findsOneWidget);
  });

  testWidgets('tap en Reintentar dispara TemplateDetailLoadRequested', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const TemplateDetailFailed(TemplatesServerFailure()));

    await tester.pumpWidget(host());
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    await tester.pump();

    verify(() => bloc.add(const TemplateDetailLoadRequested())).called(1);
  });

  testWidgets('proveedor MiniMax se humaniza correctamente', (tester) async {
    const tplMx = Template(
      id: 't3',
      orgId: 'o1',
      name: 'X',
      version: 1,
      ai: AIConfig(
        enabled: true,
        provider: AIProvider.minimax,
        model: 'minimax-m1-80k',
        temperature: 0.5,
        thinkingLevel: ThinkingLevel.high,
        systemPrompt: '',
        contextMessages: 5,
      ),
    );
    when(() => bloc.state).thenReturn(const TemplateDetailLoaded(tplMx));

    await tester.pumpWidget(host());

    expect(find.textContaining('MiniMax'), findsWidgets);
    expect(find.textContaining('razonamiento alto'), findsOneWidget);
  });

  testWidgets('proveedor DeepSeek se humaniza correctamente', (tester) async {
    const tplDs = Template(
      id: 't4',
      orgId: 'o1',
      name: 'X',
      version: 1,
      ai: AIConfig(
        enabled: true,
        provider: AIProvider.deepseek,
        model: 'deepseek-chat',
        temperature: 0.8,
        thinkingLevel: ThinkingLevel.medium,
        systemPrompt: '',
        contextMessages: 8,
      ),
    );
    when(() => bloc.state).thenReturn(const TemplateDetailLoaded(tplDs));

    await tester.pumpWidget(host());

    expect(find.textContaining('DeepSeek'), findsWidgets);
  });

  // ── Handoff al asistente org-scoped ────────────────────────────────────────
  group('handoff al asistente', () {
    setUp(() {
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));
    });

    testWidgets('Loaded ofrece un único acceso a Ataúlfo', (tester) async {
      await tester.pumpWidget(host());

      final card = find.byKey(const Key('template_detail.card.assistant'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Trabajar con Ataúlfo')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.byKey(const Key('template_detail.assistant')),
        ),
        findsOneWidget,
      );
      expect(find.text('Workspace'), findsNothing);
      expect(find.text('Probar bot'), findsNothing);
    });

    testWidgets('tap abre /home con plantilla e intención en el borrador', (
      tester,
    ) async {
      final r = await pushFrom(
        tester,
        tapKey: const Key('template_detail.assistant'),
        destinationPath: '/home',
      );
      expect(r.uri, contains('/home?prompt='));
      expect(r.uri, contains('Soporte'));
      expect(r.uri, contains('t1'));
      expect(r.canPop, <bool>[false]);
    });
  });

  // ── Launcher de secciones (hub) ─────────────────────────────────────────────
  group('launcher de secciones', () {
    setUp(() {
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));
    });

    testWidgets('muestra las filas Flujos / Variables / Motor IA', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('template_detail.link.flows')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('template_detail.link.variables')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('template_detail.link.ai')), findsOneWidget);
      expect(find.text('Flujos'), findsOneWidget);
      expect(find.text('Variables'), findsOneWidget);
      expect(find.text('Instrucciones y motor IA'), findsOneWidget);
      // Las listas ya NO viven inline en el detalle.
      expect(find.byKey(const Key('flows.add_button')), findsNothing);
      expect(find.byKey(const Key('var_defs.add_button')), findsNothing);
    });

    testWidgets('fila Flujos: count pill + caption activos/pausados', (
      tester,
    ) async {
      when(() => flowsBloc.state).thenReturn(
        FlowsLoaded(<flows.Flow>[
          _flow(id: 'f1', name: 'Bienvenida'),
          _flow(id: 'f2', name: 'Despedida', isActive: false),
        ]),
      );

      await tester.pumpWidget(host());

      final row = find.byKey(const Key('template_detail.link.flows'));
      expect(
        find.descendant(of: row, matching: find.widgetWithText(AppPill, '2')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('1 activo · 1 pausado')),
        findsOneWidget,
      );
    });

    testWidgets('fila Flujos vacía: caption "Sin flujos aún", sin pill', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      final row = find.byKey(const Key('template_detail.link.flows'));
      expect(
        find.descendant(of: row, matching: find.text('Sin flujos aún')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.widgetWithText(AppPill, '0')),
        findsNothing,
      );
    });

    testWidgets('fila Variables: count pill + caption con placeholders', (
      tester,
    ) async {
      when(() => varDefsBloc.state).thenReturn(
        const VarDefsLoaded(<VariableDef>[
          VariableDef(
            id: 'v1',
            name: 'nombre',
            defaultValue: '',
            description: '',
          ),
          VariableDef(
            id: 'v2',
            name: 'edad',
            defaultValue: '',
            description: '',
          ),
        ], 2),
      );

      await tester.pumpWidget(host());

      final row = find.byKey(const Key('template_detail.link.variables'));
      expect(
        find.descendant(of: row, matching: find.widgetWithText(AppPill, '2')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.textContaining('{{nombre}}')),
        findsOneWidget,
      );
    });

    testWidgets('fila Motor IA: caption con temperatura y razonamiento', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      final row = find.byKey(const Key('template_detail.link.ai'));
      expect(
        find.descendant(of: row, matching: find.textContaining('0.7')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.textContaining('razonamiento medio'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tap Flujos apila /templates/:id/flows', (tester) async {
      final r = await pushFrom(
        tester,
        tapKey: const Key('template_detail.link.flows'),
        destinationPath: '/templates/:id/flows',
      );
      expect(r.uri, '/templates/t1/flows');
      expect(r.canPop, <bool>[true]);
    });

    testWidgets('tap Variables apila /templates/:id/variables', (tester) async {
      final r = await pushFrom(
        tester,
        tapKey: const Key('template_detail.link.variables'),
        destinationPath: '/templates/:id/variables',
      );
      expect(r.uri, '/templates/t1/variables');
      expect(r.canPop, <bool>[true]);
    });

    testWidgets('tap Motor IA apila /templates/:id/ai', (tester) async {
      final r = await pushFrom(
        tester,
        tapKey: const Key('template_detail.link.ai'),
        destinationPath: '/templates/:id/ai',
      );
      expect(r.uri, '/templates/t1/ai');
      expect(r.canPop, <bool>[true]);
    });
  });

  // ── Superficies propias del Asistente ──────────────────────────────────────
  group('recursos, canales y prueba', () {
    setUp(() {
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));
    });

    testWidgets(
      'Loaded expone las tres superficies con vocabulario de producto',
      (tester) async {
        await tester.pumpWidget(host());

        expect(find.text('Recursos disponibles'), findsOneWidget);
        expect(find.text('Canales conectados'), findsOneWidget);
        expect(find.text('Probar Asistente'), findsOneWidget);
        expect(find.text('Crear bot'), findsNothing);
      },
    );

    testWidgets('tap Recursos conserva nombre y apila la ruta de Asistente', (
      tester,
    ) async {
      final r = await pushFrom(
        tester,
        tapKey: const Key('template_detail.link.resources'),
        destinationPath: '/assistants/:id/resources',
      );
      expect(r.uri, '/assistants/t1/resources?name=Soporte');
      expect(r.canPop, <bool>[true]);
    });

    testWidgets('tap Canales apila /assistants/:id/channels', (tester) async {
      final r = await pushFrom(
        tester,
        tapKey: const Key('template_detail.link.channels'),
        destinationPath: '/assistants/:id/channels',
      );
      expect(r.uri, '/assistants/t1/channels');
    });

    testWidgets('tap Probar apila /assistants/:id/preview', (tester) async {
      final r = await pushFrom(
        tester,
        tapKey: const Key('template_detail.link.preview'),
        destinationPath: '/assistants/:id/preview',
      );
      expect(r.uri, '/assistants/t1/preview');
    });
  });

  // ── Botón "Editar plantilla" (TE1) ─────────────────────────────────────────
  group('botón Editar plantilla', () {
    setUp(() {
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));
    });

    testWidgets('Loaded expone el lápiz de editar con key contractual', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('template_detail.edit_button')),
        findsOneWidget,
      );
      // Ya no hay botón ancho "Editar plantilla": la edición vive como
      // lápiz en el header de gradiente.
      expect(find.text('Editar plantilla'), findsNothing);
    });

    testWidgets('tap lápiz abre el sheet de renombrar con el nombre precargado '
        '(NO navega a una pantalla dedicada)', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('template_detail.edit_button')));
      await tester.pumpAndSettle();

      expect(find.byType(TemplateRenameSheet), findsOneWidget);
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(TemplateRenameSheet),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller?.text, 'Soporte');
    });

    testWidgets('Guardar dispatcha RenameRequested con el nombre nuevo', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('template_detail.edit_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('template_rename.name')),
        'Ventas',
      );
      await tester.tap(find.byKey(const Key('template_rename.submit')));
      await tester.pump();

      verify(
        () => bloc.add(const TemplateDetailRenameRequested('Ventas')),
      ).called(1);
    });

    testWidgets('al volver Loaded tras el submit, el sheet se cierra', (
      tester,
    ) async {
      final controller = StreamController<TemplateDetailState>.broadcast();
      addTearDown(controller.close);
      whenListen<TemplateDetailState>(
        bloc,
        controller.stream,
        initialState: const TemplateDetailLoaded(_tpl),
      );

      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('template_detail.edit_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('template_rename.name')),
        'Ventas',
      );
      await tester.tap(find.byKey(const Key('template_rename.submit')));
      await tester.pump();

      controller.add(
        const TemplateDetailLoaded(
          Template(id: 't1', orgId: 'o1', name: 'Ventas', version: 4, ai: _ai),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TemplateRenameSheet), findsNothing);
    });

    testWidgets('MutationFailed muestra copy de error dentro del sheet', (
      tester,
    ) async {
      final controller = StreamController<TemplateDetailState>.broadcast();
      addTearDown(controller.close);
      whenListen<TemplateDetailState>(
        bloc,
        controller.stream,
        initialState: const TemplateDetailLoaded(_tpl),
      );

      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('template_detail.edit_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('template_rename.name')),
        'Ventas',
      );
      await tester.tap(find.byKey(const Key('template_rename.submit')));
      await tester.pump();

      controller.add(
        const TemplateDetailMutationFailed(_tpl, TemplatesConflictFailure()),
      );
      await tester.pumpAndSettle();

      // El sheet sigue abierto con el copy del fallo (el operador corrige
      // y reintenta sin perder contexto).
      expect(find.byType(TemplateRenameSheet), findsOneWidget);
      expect(
        find.textContaining('desactualizada', findRichText: true),
        findsOneWidget,
      );
    });
  });

  // Los disparadores no son sección del TemplateDetailPage — viven en
  // el editor del flujo (`FlowDetailPage`, tab Disparadores). El
  // ownership real es `Trigger ∈ Flow ∈ Template`; el listado por
  // template del wire es atajo de query, no afirmación de pertenencia.
  group('sección Disparadores quitada (vive en el editor del flujo)', () {
    setUp(() {
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));
    });

    testWidgets('NO renderiza la card template_detail.card.triggers', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      expect(
        find.byKey(const Key('template_detail.card.triggers')),
        findsNothing,
      );
    });

    testWidgets('NO renderiza el título "Disparadores"', (tester) async {
      await tester.pumpWidget(host());
      expect(find.text('Disparadores'), findsNothing);
    });

    testWidgets('NO monta nada con keys del namespace triggers.*', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      expect(find.byKey(const Key('triggers.empty')), findsNothing);
      expect(find.byKey(const Key('triggers.add_button')), findsNothing);
    });
  });
}
