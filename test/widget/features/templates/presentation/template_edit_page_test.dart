import 'package:agentic/core/design/app_design_theme.dart';
import 'package:agentic/core/design/widgets/app_button.dart';
import 'package:agentic/core/design/widgets/app_text_field.dart';
import 'package:agentic/features/ai_catalog/domain/entities/catalog.dart';
import 'package:agentic/features/ai_catalog/domain/failures/catalog_failure.dart';
import 'package:agentic/features/ai_catalog/presentation/bloc/catalog_bloc.dart';
import 'package:agentic/features/templates/domain/entities/template.dart';
import 'package:agentic/features/templates/domain/failures/templates_failure.dart';
import 'package:agentic/features/templates/presentation/bloc/template_edit_bloc.dart';
import 'package:agentic/features/templates/presentation/pages/template_edit_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockEditBloc extends MockBloc<TemplateEditEvent, TemplateEditState>
    implements TemplateEditBloc {}

class _MockCatalogBloc extends MockBloc<CatalogEvent, CatalogState>
    implements CatalogBloc {}

const _tpl = Template(
  id: 't1',
  orgId: 'o1',
  name: 'Soporte',
  version: 1,
  ai: AIConfig(
    enabled: false,
    provider: AIProvider.gemini,
    model: 'gemini-3.1-pro-preview',
    temperature: 0.7,
    thinkingLevel: ThinkingLevel.low,
    systemPrompt: 'Prompt actual.',
    contextMessages: 20,
  ),
);

const _gemini = ProviderEntry(
  provider: 'GEMINI',
  defaultModel: 'gemini-3.1-pro-preview',
  models: <AIModel>[
    AIModel(
      id: 'gemini-3.1-pro-preview',
      supportsTemperature: true,
      supportsThinking: true,
    ),
    AIModel(
      id: 'gemini-3.5-flash',
      supportsTemperature: true,
      supportsThinking: true,
    ),
  ],
);
const _openai = ProviderEntry(
  provider: 'OPENAI',
  defaultModel: 'gpt-5.5',
  models: <AIModel>[
    AIModel(id: 'gpt-5.5', supportsTemperature: false, supportsThinking: true),
  ],
);
const _catalog = Catalog(providers: <ProviderEntry>[_gemini, _openai]);

void main() {
  setUpAll(() {
    registerFallbackValue(const TemplateEditLoadRequested());
    registerFallbackValue(const CatalogLoadRequested());
  });

  late _MockEditBloc editBloc;
  late _MockCatalogBloc catalogBloc;

  setUp(() {
    editBloc = _MockEditBloc();
    catalogBloc = _MockCatalogBloc();
    when(() => editBloc.state).thenReturn(const TemplateEditLoading());
    when(() => catalogBloc.state).thenReturn(const CatalogLoading());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<TemplateEditBloc>.value(value: editBloc),
        BlocProvider<CatalogBloc>.value(value: catalogBloc),
      ],
      child: const Scaffold(body: TemplateEditPage()),
    ),
  );

  group('estados combinados de carga', () {
    testWidgets('Template Loading + Catalog Loaded → spinner', (tester) async {
      when(() => editBloc.state).thenReturn(const TemplateEditLoading());
      when(
        () => catalogBloc.state,
      ).thenReturn(const CatalogLoaded(catalog: _catalog));

      await tester.pumpWidget(host());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AppTextField), findsNothing);
    });

    testWidgets('Template Editing + Catalog Loading → spinner', (tester) async {
      // El editor necesita el catálogo para pintar los pickers. Hasta
      // que ambos blocs terminen su load, no se rendera form parcial.
      when(() => editBloc.state).thenReturn(const TemplateEditEditing(_tpl));
      when(() => catalogBloc.state).thenReturn(const CatalogLoading());

      await tester.pumpWidget(host());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AppTextField), findsNothing);
    });

    testWidgets('Template LoadFailed prioriza sobre Catalog (error del template)', (
      tester,
    ) async {
      // Si el template no carga, no hay nada que editar — el error del
      // template gana sobre cualquier estado del catálogo.
      when(
        () => editBloc.state,
      ).thenReturn(const TemplateEditLoadFailed(TemplatesNotFoundFailure()));
      when(
        () => catalogBloc.state,
      ).thenReturn(const CatalogLoaded(catalog: _catalog));

      await tester.pumpWidget(host());

      expect(find.byKey(const Key('template_edit.load_error')), findsOneWidget);
    });

    testWidgets(
      'Template Editing + Catalog Failed → error del catálogo + retry',
      (tester) async {
        // El template está listo pero los pickers necesitan el catálogo
        // para renderizarse. Sin él, mostrar error específico del
        // catálogo con retry — distinto del error de carga del template.
        when(() => editBloc.state).thenReturn(const TemplateEditEditing(_tpl));
        when(
          () => catalogBloc.state,
        ).thenReturn(const CatalogFailed(CatalogNetworkFailure()));

        await tester.pumpWidget(host());

        expect(
          find.byKey(const Key('template_edit.catalog_error')),
          findsOneWidget,
        );
        expect(find.widgetWithText(AppButton, 'Reintentar'), findsOneWidget);
      },
    );

    testWidgets('tap Reintentar del catálogo dispara CatalogLoadRequested', (
      tester,
    ) async {
      when(() => editBloc.state).thenReturn(const TemplateEditEditing(_tpl));
      when(
        () => catalogBloc.state,
      ).thenReturn(const CatalogFailed(CatalogNetworkFailure()));

      await tester.pumpWidget(host());
      await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
      await tester.pump();

      verify(() => catalogBloc.add(const CatalogLoadRequested())).called(1);
    });
  });

  group('Editing + Catalog Loaded → form pre-filled', () {
    Future<void> pumpReady(WidgetTester tester) async {
      when(() => editBloc.state).thenReturn(const TemplateEditEditing(_tpl));
      when(
        () => catalogBloc.state,
      ).thenReturn(const CatalogLoaded(catalog: _catalog));
      await tester.pumpWidget(host());
    }

    testWidgets('name y systemPrompt vienen del template', (tester) async {
      await pumpReady(tester);

      expect(find.text('Soporte'), findsOneWidget);
      expect(find.text('Prompt actual.'), findsOneWidget);
    });

    testWidgets('los pickers del AIConfig están visibles con keys contractuales', (
      tester,
    ) async {
      await pumpReady(tester);

      expect(find.byKey(const Key('template_edit.field.enabled')), findsOneWidget);
      expect(
        find.byKey(const Key('template_edit.field.provider')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('template_edit.field.model')), findsOneWidget);
      expect(
        find.byKey(const Key('template_edit.field.temperature')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('template_edit.field.thinking')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('template_edit.field.context_messages')),
        findsOneWidget,
      );
    });

    testWidgets('contextMessages pre-fillea con el valor del template', (
      tester,
    ) async {
      await pumpReady(tester);

      // contextMessages es numérico (TextField), 20 viene del template.
      expect(find.text('20'), findsOneWidget);
    });
  });

  group('SubmitFailed mantiene form editable', () {
    Future<void> pumpFailed(
      WidgetTester tester,
      TemplatesFailure failure,
    ) async {
      when(() => editBloc.state).thenReturn(
        TemplateEditSubmitFailed(failure: failure, template: _tpl),
      );
      when(
        () => catalogBloc.state,
      ).thenReturn(const CatalogLoaded(catalog: _catalog));
      await tester.pumpWidget(host());
    }

    testWidgets('Conflict muestra copy específico de CAS', (tester) async {
      await pumpFailed(tester, const TemplatesConflictFailure());
      expect(
        find.byKey(const Key('template_edit.error.conflict')),
        findsOneWidget,
      );
      expect(find.text('Soporte'), findsOneWidget);
    });

    testWidgets('InvalidUpdate muestra copy específico de validación', (
      tester,
    ) async {
      await pumpFailed(tester, const TemplatesInvalidUpdateFailure());
      expect(
        find.byKey(const Key('template_edit.error.invalid')),
        findsOneWidget,
      );
    });

    testWidgets('Network muestra copy de red genérico', (tester) async {
      await pumpFailed(tester, const TemplatesNetworkFailure());
      expect(
        find.byKey(const Key('template_edit.error.network')),
        findsOneWidget,
      );
    });
  });

  testWidgets('Submitting muestra el form pero el botón en loading', (tester) async {
    when(() => editBloc.state).thenReturn(const TemplateEditSubmitting(_tpl));
    when(
      () => catalogBloc.state,
    ).thenReturn(const CatalogLoaded(catalog: _catalog));

    await tester.pumpWidget(host());

    expect(find.text('Soporte'), findsOneWidget);
    // Spinner inline del AppButton; el primitivo lo monta cuando loading=true.
    expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
  });

  group('visibility por flags supportsTemperature / supportsThinking', () {
    // GPT-5.5: supportsTemperature=false (modelo de razonamiento), pero
    // supportsThinking=true. Esto fuerza al editor a esconder SOLO el
    // slider de temperature — el dropdown de thinking sigue visible.
    const tplOnOpenAi = Template(
      id: 't1',
      orgId: 'o1',
      name: 'Soporte',
      version: 1,
      ai: AIConfig(
        enabled: true,
        provider: AIProvider.openai,
        model: 'gpt-5.5',
        temperature: 0.7,
        thinkingLevel: ThinkingLevel.medium,
        systemPrompt: 'Prompt.',
        contextMessages: 20,
      ),
    );

    // Catálogo extendido para cubrir el caso supportsThinking=false sin
    // afectar al resto de los tests. MINIMAX nativo razona sin perilla.
    const catalogWithMinimax = Catalog(
      providers: <ProviderEntry>[
        _gemini,
        _openai,
        ProviderEntry(
          provider: 'MINIMAX',
          defaultModel: 'MiniMax-M2.7',
          models: <AIModel>[
            AIModel(
              id: 'MiniMax-M2.7',
              supportsTemperature: true,
              supportsThinking: false,
            ),
          ],
        ),
      ],
    );

    const tplOnMinimax = Template(
      id: 't1',
      orgId: 'o1',
      name: 'Soporte',
      version: 1,
      ai: AIConfig(
        enabled: true,
        provider: AIProvider.minimax,
        model: 'MiniMax-M2.7',
        temperature: 0.9,
        thinkingLevel: ThinkingLevel.high,
        systemPrompt: 'Prompt.',
        contextMessages: 20,
      ),
    );

    testWidgets(
      'modelo con supportsTemperature=false esconde el slider de temperature',
      (tester) async {
        when(() => editBloc.state).thenReturn(const TemplateEditEditing(tplOnOpenAi));
        when(
          () => catalogBloc.state,
        ).thenReturn(const CatalogLoaded(catalog: _catalog));

        await tester.pumpWidget(host());

        expect(
          find.byKey(const Key('template_edit.field.temperature')),
          findsNothing,
        );
        // El dropdown de thinking SIGUE visible (GPT-5.5 sí lo soporta).
        expect(
          find.byKey(const Key('template_edit.field.thinking')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'modelo con supportsThinking=false esconde el dropdown de thinking',
      (tester) async {
        when(
          () => editBloc.state,
        ).thenReturn(const TemplateEditEditing(tplOnMinimax));
        when(() => catalogBloc.state).thenReturn(
          const CatalogLoaded(catalog: catalogWithMinimax),
        );

        await tester.pumpWidget(host());

        expect(
          find.byKey(const Key('template_edit.field.thinking')),
          findsNothing,
        );
        // El slider de temperature SIGUE visible (MiniMax sí lo soporta).
        expect(
          find.byKey(const Key('template_edit.field.temperature')),
          findsOneWidget,
        );
      },
    );
  });

  group('drift: modelo o provider retirado entre releases', () {
    const tplWithRetiredModel = Template(
      id: 't1',
      orgId: 'o1',
      name: 'Soporte',
      version: 1,
      ai: AIConfig(
        enabled: true,
        provider: AIProvider.gemini,
        model: 'gemini-2.0-pro-retirado',
        temperature: 0.7,
        thinkingLevel: ThinkingLevel.low,
        systemPrompt: 'Prompt.',
        contextMessages: 20,
      ),
    );

    testWidgets('modelo retirado muestra badge "Retirado" + warning visible', (
      tester,
    ) async {
      // El template guardado refiere a un modelo que el backend retiró
      // del catálogo entre releases. El editor debe marcarlo visible
      // para que el operador entienda por qué no puede guardar tal cual.
      when(
        () => editBloc.state,
      ).thenReturn(const TemplateEditEditing(tplWithRetiredModel));
      when(
        () => catalogBloc.state,
      ).thenReturn(const CatalogLoaded(catalog: _catalog));

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('template_edit.drift.model_retired')),
        findsOneWidget,
      );
    });

    testWidgets('modelo retirado deshabilita el submit (no se puede guardar)', (
      tester,
    ) async {
      // Submit gate: dejar que el operador suba un modelo retirado le
      // ahorra el 422 del backend pero pierde contexto sobre el porqué.
      // Mejor bloquearlo en cliente con copy claro.
      when(
        () => editBloc.state,
      ).thenReturn(const TemplateEditEditing(tplWithRetiredModel));
      when(
        () => catalogBloc.state,
      ).thenReturn(const CatalogLoaded(catalog: _catalog));

      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('template_edit.submit')));
      await tester.pump();

      verifyNever(() => editBloc.add(any()));
    });

    testWidgets(
      'cambio de provider auto-selecciona defaultModel del nuevo provider',
      (tester) async {
        // UX: cuando el operador cambia provider (Gemini → OpenAI), el
        // modelo actual probablemente no existe en el nuevo catálogo.
        // Auto-seleccionar el defaultModel del nuevo provider es lo
        // más usable (vs. dejar el modelo en estado "Retirado" después
        // de un cambio voluntario, que confunde la causa).
        when(() => editBloc.state).thenReturn(const TemplateEditEditing(_tpl));
        when(
          () => catalogBloc.state,
        ).thenReturn(const CatalogLoaded(catalog: _catalog));

        await tester.pumpWidget(host());

        // Pre-condición: modelo actual es de Gemini.
        expect(find.text('gemini-3.1-pro-preview'), findsOneWidget);

        await tester.tap(find.byKey(const Key('template_edit.field.provider')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OPENAI').last);
        await tester.pumpAndSettle();

        // Post-condición: modelo cambió al defaultModel de OPENAI.
        expect(find.text('gpt-5.5'), findsOneWidget);
      },
    );
  });

  testWidgets(
    'Succeeded apila el detalle por pushReplacement (form ya cumplió)',
    (tester) async {
      whenListen(
        editBloc,
        Stream<TemplateEditState>.fromIterable(<TemplateEditState>[
          const TemplateEditSubmitting(_tpl),
          const TemplateEditSucceeded(_tpl),
        ]),
        initialState: const TemplateEditEditing(_tpl),
      );
      when(
        () => catalogBloc.state,
      ).thenReturn(const CatalogLoaded(catalog: _catalog));

      final canPopAtDestination = <bool>[];
      final router = GoRouter(
        initialLocation: '/templates/t1/edit',
        routes: <RouteBase>[
          GoRoute(
            path: '/templates/t1/edit',
            builder: (_, _) => MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<TemplateEditBloc>.value(value: editBloc),
                BlocProvider<CatalogBloc>.value(value: catalogBloc),
              ],
              child: const Scaffold(body: TemplateEditPage()),
            ),
          ),
          GoRoute(
            path: '/templates/:id',
            builder: (_, _) => Scaffold(
              body: Builder(
                builder: (ctx) {
                  canPopAtDestination.add(Navigator.of(ctx).canPop());
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(
        canPopAtDestination,
        <bool>[false],
        reason:
            'pushReplacement reemplaza /templates/t1/edit con el detalle; '
            'el detalle no debe tener pila local que vuelva al form.',
      );
    },
  );
}
