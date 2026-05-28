import 'dart:async';

import 'package:agentic/core/design/app_design_theme.dart';
import 'package:agentic/core/design/tokens.dart';
import 'package:agentic/core/design/widgets/app_avatar.dart';
import 'package:agentic/core/design/widgets/app_button.dart';
import 'package:agentic/core/design/widgets/app_card.dart';
import 'package:agentic/core/design/widgets/app_pill.dart';
import 'package:agentic/features/flows/domain/entities/flow.dart' as flows;
import 'package:agentic/features/flows/domain/failures/flows_failure.dart';
import 'package:agentic/features/flows/presentation/bloc/flows_bloc.dart';
import 'package:agentic/features/templates/domain/entities/template.dart';
import 'package:agentic/features/templates/domain/entities/variable_def.dart';
import 'package:agentic/features/templates/domain/failures/templates_failure.dart';
import 'package:agentic/features/templates/presentation/bloc/template_detail_bloc.dart';
import 'package:agentic/features/templates/presentation/bloc/var_defs_bloc.dart';
import 'package:agentic/features/templates/presentation/pages/template_detail_page.dart';
import 'package:agentic/features/templates/presentation/widgets/var_def_form_sheet.dart';
import 'package:agentic/features/triggers/domain/entities/trigger.dart';
import 'package:agentic/features/triggers/presentation/bloc/triggers_bloc.dart';
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

const _tpl = Template(
  id: 't1',
  orgId: 'o1',
  name: 'Soporte',
  version: 3,
  ai: AIConfig(
    enabled: true,
    provider: AIProvider.gemini,
    model: 'gemini-3.1-pro-preview',
    temperature: 0.7,
    thinkingLevel: ThinkingLevel.medium,
    systemPrompt: 'Eres un asistente de soporte amable.',
    contextMessages: 20,
  ),
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
    // Default: var-defs Loaded vacío (estado terminal sin animaciones).
    // Tests específicos de la sección Variables sobreescriben este stub.
    when(
      () => varDefsBloc.state,
    ).thenReturn(const VarDefsLoaded(<VariableDef>[], 1));
    // Default: flows Loaded vacío para que la sección Flujos no flashee
    // Loading en los tests que no la ejercen.
    when(() => flowsBloc.state).thenReturn(const FlowsLoaded(<flows.Flow>[]));
    // Default: triggers Loaded vacío. Mismo motivo que flows.
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

  testWidgets('Loading muestra spinner con AppTokens.primary', (tester) async {
    when(() => bloc.state).thenReturn(const TemplateDetailLoading());

    await tester.pumpWidget(host());

    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.valueColor?.value, AppTokens.primary);
  });

  testWidgets(
    'Loaded muestra header con AppAvatar(size: 64), nombre y provider',
    (tester) async {
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));

      await tester.pumpWidget(host());

      expect(find.text('Soporte'), findsOneWidget);
      expect(find.text('Gemini'), findsOneWidget);
      final avatar = tester.widget<AppAvatar>(find.byType(AppAvatar));
      expect(avatar.size, 64);
      expect(avatar.name, 'Soporte');
      expect(find.byType(CircleAvatar), findsNothing);
    },
  );

  testWidgets(
    'Loaded agrupa header + acciones en AppCard con key contractual',
    (tester) async {
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));

      await tester.pumpWidget(host());

      final cardFinder = find.byKey(const Key('template_detail.card.header'));
      expect(cardFinder, findsOneWidget);
      // Avatar + name viven dentro de la header card.
      expect(
        find.descendant(of: cardFinder, matching: find.text('Soporte')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cardFinder, matching: find.byType(AppAvatar)),
        findsOneWidget,
      );
      // La pill de versión y la pill de estado IA están en el header.
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.widgetWithText(AppPill, 'v3'),
        ),
        findsOneWidget,
      );
      // Las acciones (Editar plantilla / Crear bot) viven en el header,
      // no en el bottom-stack del scroll.
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.byKey(const Key('template_detail.edit_button')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.byKey(const Key('template_detail.create_bot_button')),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Loaded muestra versión como AppPill.outline', (tester) async {
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
      expect(find.text('OpenAI'), findsOneWidget);
      expect(find.text('Bajo'), findsOneWidget);
    },
  );

  testWidgets('Loaded muestra los 4 stats AIConfig en AppCard individuales '
      '(modelo/temp/razonamiento/contexto)', (tester) async {
    when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));

    await tester.pumpWidget(host());

    // Cuatro stat tiles, uno por campo. Cada uno es un AppCard con
    // label caption + valor titleM — reemplaza al _FieldRow del shape
    // pre-DS (label 180px fijo). El page tiene además cards de sección
    // (Flujos / Disparadores / Variables / etc.), así que verificamos
    // las tarjetas de stats por contenido y no por conteo global.
    expect(find.widgetWithText(AppCard, 'Modelo'), findsOneWidget);
    expect(
      find.widgetWithText(AppCard, 'gemini-3.1-pro-preview'),
      findsOneWidget,
    );
    expect(find.widgetWithText(AppCard, 'Temperatura'), findsOneWidget);
    expect(find.widgetWithText(AppCard, '0.7'), findsOneWidget);
    expect(find.widgetWithText(AppCard, 'Razonamiento'), findsOneWidget);
    expect(find.widgetWithText(AppCard, 'Medio'), findsOneWidget);
    expect(
      find.widgetWithText(AppCard, 'Mensajes de contexto'),
      findsOneWidget,
    );
    expect(find.widgetWithText(AppCard, '20'), findsOneWidget);
  });

  testWidgets('Loaded con systemPrompt no vacío lo muestra (SelectableText)', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));

    await tester.pumpWidget(host());

    // El system prompt es contenido del usuario; debe ser seleccionable
    // para que se pueda copiar.
    expect(find.text('Eres un asistente de soporte amable.'), findsOneWidget);
  });

  testWidgets(
    'Loaded agrupa stats + prompt en card Configuración IA con key contractual',
    (tester) async {
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));

      await tester.pumpWidget(host());

      final cardFinder = find.byKey(
        const Key('template_detail.card.ai_config'),
      );
      expect(cardFinder, findsOneWidget);

      // La card combina el grid de stats + el system prompt: ambos deben
      // estar dentro del mismo ancestro AppCard.
      expect(
        find.descendant(of: cardFinder, matching: find.text('Modelo')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cardFinder, matching: find.text('Temperatura')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cardFinder, matching: find.text('Razonamiento')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text('Mensajes de contexto'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text('Eres un asistente de soporte amable.'),
        ),
        findsOneWidget,
      );
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

    expect(find.text('MiniMax'), findsOneWidget);
    expect(find.text('Alto'), findsOneWidget);
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

    expect(find.text('DeepSeek'), findsOneWidget);
  });

  // ── Sección Variables ──────────────────────────────────────────────────────
  group('sección Variables', () {
    setUp(() {
      // Sin Template no se renderiza el resto de la página; las pruebas de
      // var-defs necesitan el detalle ya en Loaded para que la sección sea
      // visible debajo del prompt.
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));
    });

    testWidgets('vive dentro de AppCard con key contractual', (tester) async {
      await tester.pumpWidget(host());

      final cardFinder = find.byKey(
        const Key('template_detail.card.variables'),
      );
      expect(cardFinder, findsOneWidget);
      expect(
        find.descendant(of: cardFinder, matching: find.text('Variables')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.byKey(const Key('var_defs.add_button')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('siempre muestra el título "Variables"', (tester) async {
      await tester.pumpWidget(host());
      expect(find.text('Variables'), findsOneWidget);
    });

    testWidgets('VarDefsLoading muestra spinner inline', (tester) async {
      when(() => varDefsBloc.state).thenReturn(const VarDefsLoading());

      await tester.pumpWidget(host());

      expect(find.byKey(const Key('var_defs.loading')), findsOneWidget);
    });

    testWidgets('VarDefsLoaded([]) muestra empty state italic', (tester) async {
      when(
        () => varDefsBloc.state,
      ).thenReturn(const VarDefsLoaded(<VariableDef>[], 1));

      await tester.pumpWidget(host());

      expect(find.byKey(const Key('var_defs.empty')), findsOneWidget);
    });

    testWidgets(
      'VarDefsLoaded con defs muestra una fila por variable (name + default)',
      (tester) async {
        when(() => varDefsBloc.state).thenReturn(
          const VarDefsLoaded(<VariableDef>[
            VariableDef(
              id: 'v1',
              name: 'nombre',
              type: VarType.text,
              defaultValue: 'cliente',
              description: 'Saludo personalizado',
            ),
            VariableDef(
              id: 'v2',
              name: 'edad',
              type: VarType.text,
              defaultValue: '',
              description: '',
            ),
          ], 2),
        );

        await tester.pumpWidget(host());

        expect(find.text('{{nombre}}'), findsOneWidget);
        expect(find.text('cliente'), findsOneWidget);
        expect(find.text('Saludo personalizado'), findsOneWidget);
        expect(find.text('{{edad}}'), findsOneWidget);
      },
    );

    testWidgets(
      'row de variable multimedia muestra pill humanizada del tipo (set v1)',
      (tester) async {
        // Pill por tipo: visible para label/multimedia (informativa); para
        // text (default semántico) se omite — el operador asume text si
        // no hay pill, reduciendo ruido visual en el caso más común.
        when(() => varDefsBloc.state).thenReturn(
          const VarDefsLoaded(<VariableDef>[
            VariableDef(
              id: 'v1',
              name: 'foto',
              type: VarType.image,
              defaultValue: '',
              description: '',
            ),
            VariableDef(
              id: 'v2',
              name: 'cancion',
              type: VarType.audio,
              defaultValue: '',
              description: '',
            ),
            VariableDef(
              id: 'v3',
              name: 'tipo_cliente',
              type: VarType.label,
              defaultValue: '',
              description: '',
            ),
            VariableDef(
              id: 'v4',
              name: 'comentario',
              type: VarType.text,
              defaultValue: '',
              description: '',
            ),
          ], 4),
        );

        await tester.pumpWidget(host());

        expect(
          find.byKey(const Key('var_defs.row.v1.type_pill')),
          findsOneWidget,
        );
        expect(find.text('Imagen'), findsOneWidget);
        expect(
          find.byKey(const Key('var_defs.row.v2.type_pill')),
          findsOneWidget,
        );
        expect(find.text('Audio'), findsOneWidget);
        expect(
          find.byKey(const Key('var_defs.row.v3.type_pill')),
          findsOneWidget,
        );
        expect(find.text('Etiqueta'), findsOneWidget);
        // text es el default semántico: sin pill (reduce ruido).
        expect(
          find.byKey(const Key('var_defs.row.v4.type_pill')),
          findsNothing,
        );
      },
    );

    testWidgets('VarDefsFailed muestra mensaje + AppButton "Reintentar"', (
      tester,
    ) async {
      when(
        () => varDefsBloc.state,
      ).thenReturn(const VarDefsFailed(TemplatesServerFailure()));

      await tester.pumpWidget(host());

      expect(find.byKey(const Key('var_defs.failed')), findsOneWidget);
      // El retry inline usa AppButton.text (consistente con DS); el
      // TextButton de Material desaparece de la página.
      expect(find.widgetWithText(AppButton, 'Reintentar'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('tap Reintentar dispara VarDefsLoadRequested', (tester) async {
      when(
        () => varDefsBloc.state,
      ).thenReturn(const VarDefsFailed(TemplatesNetworkFailure()));

      await tester.pumpWidget(host());
      await tester.ensureVisible(find.byKey(const Key('var_defs.failed')));
      await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
      await tester.pump();

      verify(() => varDefsBloc.add(const VarDefsLoadRequested())).called(1);
    });

    testWidgets(
      'VarDefsMutating conserva la lista visible (no flash a Loading)',
      (tester) async {
        when(() => varDefsBloc.state).thenReturn(
          const VarDefsMutating(<VariableDef>[
            VariableDef(
              id: 'v1',
              name: 'nombre',
              type: VarType.text,
              defaultValue: 'cliente',
              description: '',
            ),
          ], 2),
        );

        await tester.pumpWidget(host());

        expect(find.text('{{nombre}}'), findsOneWidget);
        // El spinner inline NO debe aparecer durante la mutación — el
        // contexto del operador se conserva; el overlay/disable del
        // botón lo gestiona el form que disparó la mutación.
        expect(find.byKey(const Key('var_defs.loading')), findsNothing);
      },
    );

    testWidgets(
      'VarDefsMutationFailed mantiene lista visible (feedback va por listener)',
      (tester) async {
        when(() => varDefsBloc.state).thenReturn(
          const VarDefsMutationFailed(
            <VariableDef>[
              VariableDef(
                id: 'v1',
                name: 'nombre',
                type: VarType.text,
                defaultValue: 'cliente',
                description: '',
              ),
            ],
            2,
            TemplatesConflictFailure(),
          ),
        );

        await tester.pumpWidget(host());

        expect(find.text('{{nombre}}'), findsOneWidget);
        // No es el terminal de Failed (que apaga la lista) — el snapshot
        // sigue intacto y el operador puede reintentar sin perder
        // contexto.
        expect(find.byKey(const Key('var_defs.failed')), findsNothing);
      },
    );

    testWidgets('VarDefsMutating con lista vacía muestra empty state', (
      tester,
    ) async {
      when(
        () => varDefsBloc.state,
      ).thenReturn(const VarDefsMutating(<VariableDef>[], 1));

      await tester.pumpWidget(host());

      expect(find.byKey(const Key('var_defs.empty')), findsOneWidget);
    });

    testWidgets('Loaded muestra botón "Agregar variable" con key contractual', (
      tester,
    ) async {
      when(
        () => varDefsBloc.state,
      ).thenReturn(const VarDefsLoaded(<VariableDef>[], 1));

      await tester.pumpWidget(host());

      expect(find.byKey(const Key('var_defs.add_button')), findsOneWidget);
      expect(find.text('Agregar variable'), findsOneWidget);
    });

    testWidgets('MutationFailed mantiene visible el botón "Agregar variable"', (
      tester,
    ) async {
      // Tras un 409, el operador puede corregir el form y reintentar
      // desde el mismo sheet; el botón debe seguir visible.
      when(() => varDefsBloc.state).thenReturn(
        const VarDefsMutationFailed(
          <VariableDef>[],
          1,
          TemplatesConflictFailure(),
        ),
      );

      await tester.pumpWidget(host());

      expect(find.byKey(const Key('var_defs.add_button')), findsOneWidget);
    });

    testWidgets(
      'Mutating oculta el botón "Agregar variable" (no doble dispatch)',
      (tester) async {
        when(
          () => varDefsBloc.state,
        ).thenReturn(const VarDefsMutating(<VariableDef>[], 1));

        await tester.pumpWidget(host());

        // El sheet está abierto y mostrando su propio spinner; el botón
        // del detail page no debe coexistir o el operador puede
        // dispararlo dos veces.
        expect(find.byKey(const Key('var_defs.add_button')), findsNothing);
      },
    );

    testWidgets(
      'tap "Agregar variable" abre el VarDefFormSheet (modal bottom sheet)',
      (tester) async {
        when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));
        when(() => varDefsBloc.state).thenReturn(
          const VarDefsLoaded(<VariableDef>[
            VariableDef(
              id: 'v1',
              name: 'nombre',
              type: VarType.text,
              defaultValue: 'cliente',
              description: '',
            ),
          ], 2),
        );

        await tester.pumpWidget(host());
        // ensureVisible: con var-defs en la lista + trash icon el botón
        // puede caer fuera del viewport en el tester.
        await tester.ensureVisible(
          find.byKey(const Key('var_defs.add_button')),
        );
        await tester.tap(find.byKey(const Key('var_defs.add_button')));
        await tester.pumpAndSettle();

        expect(find.byType(VarDefFormSheet), findsOneWidget);
      },
    );

    testWidgets(
      'tap row de variable abre el sheet en modo edit (editing pre-fillado)',
      (tester) async {
        const defs = <VariableDef>[
          VariableDef(
            id: 'v1',
            name: 'nombre',
            type: VarType.text,
            defaultValue: 'cliente',
            description: 'Saludo personalizado',
          ),
        ];
        when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));
        when(() => varDefsBloc.state).thenReturn(const VarDefsLoaded(defs, 2));

        await tester.pumpWidget(host());
        // El row del var-def es tappeable. Cualquier descendant
        // tappable que arranque el flujo está bien — clave: end-to-end
        // el sheet se monta con el editing pre-fillado.
        await tester.ensureVisible(find.text('{{nombre}}'));
        await tester.tap(find.text('{{nombre}}'));
        await tester.pumpAndSettle();

        expect(find.byType(VarDefFormSheet), findsOneWidget);
        // El sheet refleja modo edit (title + valores pre-fillados).
        expect(find.text('Editar variable'), findsOneWidget);
        // El name está en el field name del sheet (descendiente del sheet).
        expect(
          find.descendant(
            of: find.byType(VarDefFormSheet),
            matching: find.text('Saludo personalizado'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('cada row expone un trash icon con key contractual', (
      tester,
    ) async {
      const defs = <VariableDef>[
        VariableDef(
          id: 'v1',
          name: 'nombre',
          type: VarType.text,
          defaultValue: '',
          description: '',
        ),
        VariableDef(
          id: 'v2',
          name: 'edad',
          type: VarType.text,
          defaultValue: '',
          description: '',
        ),
      ];
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));
      when(() => varDefsBloc.state).thenReturn(const VarDefsLoaded(defs, 2));

      await tester.pumpWidget(host());

      expect(find.byKey(const Key('var_defs.row.v1.delete')), findsOneWidget);
      expect(find.byKey(const Key('var_defs.row.v2.delete')), findsOneWidget);
    });

    testWidgets('tap trash icon abre confirm dialog (no dispatch inmediato)', (
      tester,
    ) async {
      const defs = <VariableDef>[
        VariableDef(
          id: 'v1',
          name: 'nombre',
          type: VarType.text,
          defaultValue: '',
          description: '',
        ),
      ];
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));
      when(() => varDefsBloc.state).thenReturn(const VarDefsLoaded(defs, 2));

      await tester.pumpWidget(host());
      await tester.ensureVisible(
        find.byKey(const Key('var_defs.row.v1.delete')),
      );
      await tester.tap(find.byKey(const Key('var_defs.row.v1.delete')));
      await tester.pumpAndSettle();

      // Confirm dialog visible — operador debe confirmar la acción
      // destructiva. Key contractual del dialog.
      expect(find.byKey(const Key('var_defs.delete_confirm')), findsOneWidget);
      // No se dispatchó nada todavía.
      verifyNever(() => varDefsBloc.add(any()));
    });

    testWidgets(
      'tap Cancelar en confirm dialog: no dispatcha, cierra el dialog',
      (tester) async {
        const defs = <VariableDef>[
          VariableDef(
            id: 'v1',
            name: 'nombre',
            type: VarType.text,
            defaultValue: '',
            description: '',
          ),
        ];
        when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));
        when(() => varDefsBloc.state).thenReturn(const VarDefsLoaded(defs, 2));

        await tester.pumpWidget(host());
        await tester.ensureVisible(
          find.byKey(const Key('var_defs.row.v1.delete')),
        );
        await tester.tap(find.byKey(const Key('var_defs.row.v1.delete')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('var_defs.delete_confirm')), findsNothing);
        verifyNever(() => varDefsBloc.add(any()));
      },
    );

    testWidgets(
      'tap Eliminar en confirm dialog: dispatcha VarDefsDeleteRequested + cierra',
      (tester) async {
        const defs = <VariableDef>[
          VariableDef(
            id: 'v1',
            name: 'nombre',
            type: VarType.text,
            defaultValue: '',
            description: '',
          ),
        ];
        when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));
        when(() => varDefsBloc.state).thenReturn(const VarDefsLoaded(defs, 2));

        await tester.pumpWidget(host());
        await tester.ensureVisible(
          find.byKey(const Key('var_defs.row.v1.delete')),
        );
        await tester.tap(find.byKey(const Key('var_defs.row.v1.delete')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar'));
        await tester.pumpAndSettle();

        verify(
          () => varDefsBloc.add(const VarDefsDeleteRequested(varDefId: 'v1')),
        ).called(1);
        expect(find.byKey(const Key('var_defs.delete_confirm')), findsNothing);
      },
    );

    testWidgets(
      'MutationFailed muestra SnackBar con copy de "intenta recargar"',
      (tester) async {
        // El parent del sheet es quien muestra feedback de error — el
        // sheet sigue montado para permitir reintento, pero el operador
        // necesita verbalización del fallo. Genérico cubre los 3 buckets
        // del 409 (duplicate / stale CAS / in-use) sin precisión que no
        // tenemos.
        when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));
        final controller = StreamController<VarDefsState>.broadcast();
        addTearDown(controller.close);
        whenListen<VarDefsState>(
          varDefsBloc,
          controller.stream,
          initialState: const VarDefsLoaded(<VariableDef>[], 1),
        );

        await tester.pumpWidget(host());
        controller.add(
          const VarDefsMutationFailed(
            <VariableDef>[],
            1,
            TemplatesConflictFailure(),
          ),
        );
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        // Copy genérico: no se distingue duplicado/stale/in-use porque
        // el backend conflación 409.
        expect(
          find.textContaining('plantilla cambió', findRichText: true),
          findsOneWidget,
        );
      },
    );
  });

  // ── Botón "Crear bot" (mini-S04a) ──────────────────────────────────────────
  group('botón Crear bot', () {
    setUp(() {
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));
    });

    testWidgets('Loaded expone botón con key contractual y AppButton', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      final keyFinder = find.byKey(
        const Key('template_detail.create_bot_button'),
      );
      expect(keyFinder, findsOneWidget);
      // El botón es AppButton.filled (no FilledButton.icon Material).
      expect(find.widgetWithText(AppButton, 'Crear bot'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets(
      'tap navega a /templates/:id/bots/new?name=... preservando el shell '
      '(canPop=true en destino)',
      (tester) async {
        // El nombre de la plantilla viaja en query param para que el form
        // pueda mostrar el chip sin volver a golpear el backend.
        // La aserción canPop() == true en el destino es el guard
        // contractual que detecta regresiones a context.go() sin pasar por
        // device.
        when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));

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
              path: '/templates/:templateId/bots/new',
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
          MaterialApp.router(
            theme: AppDesignTheme.dark(),
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        // El detalle migrado al DS es más alto que el test surface (800×600);
        // el botón vive después del scroll. ensureVisible scrollea el
        // SingleChildScrollView hasta que el botón sea hit-testable.
        await tester.ensureVisible(
          find.byKey(const Key('template_detail.create_bot_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('template_detail.create_bot_button')),
        );
        await tester.pumpAndSettle();

        expect(
          destinationUri,
          '/templates/t1/bots/new?name=Soporte',
          reason:
              'la URL debe llevar templateId como path y templateName como '
              'query param URL-encoded',
        );
        expect(
          canPopAtDestination,
          <bool>[true],
          reason:
              'el botón debe usar push (no go) para que el back físico '
              'vuelva al detalle de plantilla en lugar de salir de la app',
        );
        unawaited(Future<void>.value());
      },
    );
  });

  // ── Botón "Editar plantilla" (TE1) ─────────────────────────────────────────
  group('botón Editar plantilla', () {
    setUp(() {
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));
    });

    testWidgets('Loaded expone botón con key contractual y AppButton', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('template_detail.edit_button')),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(AppButton, 'Editar plantilla'),
        findsOneWidget,
      );
    });

    testWidgets(
      'tap apila /templates/:id/edit preservando el detalle (canPop=true)',
      (tester) async {
        when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));

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
              path: '/templates/:id/edit',
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
          MaterialApp.router(
            theme: AppDesignTheme.dark(),
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('template_detail.edit_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('template_detail.edit_button')));
        await tester.pumpAndSettle();

        expect(destinationUri, '/templates/t1/edit');
        expect(
          canPopAtDestination,
          <bool>[true],
          reason:
              'el botón debe usar push (no go) para que el back físico '
              'vuelva al detalle de plantilla, no salga de la app',
        );
      },
    );
  });

  // ── Sección Flujos (F1) ────────────────────────────────────────────────────
  group('sección Flujos', () {
    setUp(() {
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));
    });

    testWidgets('vive dentro de AppCard con key contractual', (tester) async {
      await tester.pumpWidget(host());

      final cardFinder = find.byKey(const Key('template_detail.card.flows'));
      expect(cardFinder, findsOneWidget);
      expect(
        find.descendant(of: cardFinder, matching: find.text('Flujos')),
        findsOneWidget,
      );
      // El AppCard debe contener la sección Flujos completa, incluyendo
      // el botón de "Nuevo flujo" que es el affordance de creación.
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.byKey(const Key('flows.add_button')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('siempre muestra el título "Flujos"', (tester) async {
      await tester.pumpWidget(host());
      expect(find.text('Flujos'), findsOneWidget);
    });

    testWidgets('FlowsLoading muestra spinner inline', (tester) async {
      when(() => flowsBloc.state).thenReturn(const FlowsLoading());

      await tester.pumpWidget(host());
      await tester.ensureVisible(find.byKey(const Key('flows.loading')));

      expect(find.byKey(const Key('flows.loading')), findsOneWidget);
    });

    testWidgets('FlowsLoaded([]) muestra empty state italic', (tester) async {
      when(() => flowsBloc.state).thenReturn(const FlowsLoaded(<flows.Flow>[]));

      await tester.pumpWidget(host());
      await tester.ensureVisible(find.byKey(const Key('flows.empty')));

      expect(find.byKey(const Key('flows.empty')), findsOneWidget);
    });

    testWidgets(
      'FlowsLoaded con flows muestra una fila por flow (name visible)',
      (tester) async {
        when(() => flowsBloc.state).thenReturn(
          const FlowsLoaded(<flows.Flow>[
            flows.Flow(
              id: 'f1',
              templateId: 't1',
              name: 'Bienvenida',
              isActive: true,
              version: 1,
              cooldownMs: 0,
              usageLimit: 0,
              excludesFlows: <String>[],
            ),
            flows.Flow(
              id: 'f2',
              templateId: 't1',
              name: 'Despedida',
              isActive: false,
              version: 2,
              cooldownMs: 0,
              usageLimit: 0,
              excludesFlows: <String>[],
            ),
          ]),
        );

        await tester.pumpWidget(host());
        await tester.ensureVisible(find.byKey(const Key('flows.row.f1')));

        expect(find.byKey(const Key('flows.row.f1')), findsOneWidget);
        expect(find.byKey(const Key('flows.row.f2')), findsOneWidget);
        expect(find.text('Bienvenida'), findsOneWidget);
        expect(find.text('Despedida'), findsOneWidget);
      },
    );

    testWidgets(
      'row de flow activo muestra pill primary; pausado muestra pill neutral',
      (tester) async {
        when(() => flowsBloc.state).thenReturn(
          const FlowsLoaded(<flows.Flow>[
            flows.Flow(
              id: 'f1',
              templateId: 't1',
              name: 'Bienvenida',
              isActive: true,
              version: 1,
              cooldownMs: 0,
              usageLimit: 0,
              excludesFlows: <String>[],
            ),
            flows.Flow(
              id: 'f2',
              templateId: 't1',
              name: 'Despedida',
              isActive: false,
              version: 2,
              cooldownMs: 0,
              usageLimit: 0,
              excludesFlows: <String>[],
            ),
          ]),
        );

        await tester.pumpWidget(host());
        await tester.ensureVisible(find.byKey(const Key('flows.row.f1')));

        expect(
          find.byKey(const Key('flows.row.f1.status_pill')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('flows.row.f2.status_pill')),
          findsOneWidget,
        );
        expect(find.text('Activo'), findsOneWidget);
        expect(find.text('Pausado'), findsOneWidget);
      },
    );

    testWidgets('FlowsFailed muestra fila de error con botón Reintentar', (
      tester,
    ) async {
      when(
        () => flowsBloc.state,
      ).thenReturn(const FlowsFailed(FlowsServerFailure()));

      await tester.pumpWidget(host());
      await tester.ensureVisible(find.byKey(const Key('flows.failed')));

      expect(find.byKey(const Key('flows.failed')), findsOneWidget);
      // Tap del Reintentar dispatcha LoadRequested al bloc.
      await tester.tap(find.widgetWithText(AppButton, 'Reintentar').last);
      await tester.pump();
      verify(() => flowsBloc.add(const FlowsLoadRequested())).called(1);
    });

    testWidgets(
      'tap del row apila /flows/:id preservando el detalle (canPop=true)',
      (tester) async {
        when(() => flowsBloc.state).thenReturn(
          const FlowsLoaded(<flows.Flow>[
            flows.Flow(
              id: 'f1',
              templateId: 't1',
              name: 'Bienvenida',
              isActive: true,
              version: 1,
              cooldownMs: 0,
              usageLimit: 0,
              excludesFlows: <String>[],
            ),
          ]),
        );

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
              path: '/flows/:id',
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
          MaterialApp.router(
            theme: AppDesignTheme.dark(),
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('flows.row.f1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('flows.row.f1')));
        await tester.pumpAndSettle();

        expect(destinationUri, '/flows/f1');
        expect(
          canPopAtDestination,
          <bool>[true],
          reason:
              'el row debe usar push (no go) para que el back físico '
              'vuelva al detalle de plantilla, no salga de la app',
        );
      },
    );

    testWidgets('expone botón "Nuevo flujo" con key contractual en Loaded', (
      tester,
    ) async {
      when(() => flowsBloc.state).thenReturn(const FlowsLoaded(<flows.Flow>[]));
      await tester.pumpWidget(host());
      await tester.ensureVisible(find.byKey(const Key('flows.add_button')));
      expect(find.byKey(const Key('flows.add_button')), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Nuevo flujo'), findsOneWidget);
    });

    testWidgets(
      'tap "Nuevo flujo" apila /templates/:id/flows/new (canPop=true en destino)',
      (tester) async {
        when(
          () => flowsBloc.state,
        ).thenReturn(const FlowsLoaded(<flows.Flow>[]));
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
              path: '/templates/:templateId/flows/new',
              builder: (_, st) {
                destinationUri = st.uri.toString();
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
          MaterialApp.router(
            theme: AppDesignTheme.dark(),
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('flows.add_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('flows.add_button')));
        await tester.pumpAndSettle();

        expect(destinationUri, '/templates/t1/flows/new');
        expect(
          canPopAtDestination,
          <bool>[true],
          reason:
              'el botón debe usar push (no go) para que el back físico '
              'vuelva al detalle de plantilla',
        );
      },
    );
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
