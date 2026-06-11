import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_switch.dart';
import 'package:ataulfo/features/ai_catalog/domain/entities/catalog.dart';
import 'package:ataulfo/features/ai_catalog/presentation/bloc/catalog_bloc.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:ataulfo/features/templates/domain/failures/templates_failure.dart';
import 'package:ataulfo/features/templates/presentation/bloc/template_detail_bloc.dart';
import 'package:ataulfo/features/templates/presentation/pages/template_ai_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<TemplateDetailEvent, TemplateDetailState>
    implements TemplateDetailBloc {}

class _MockCatalogBloc extends MockBloc<CatalogEvent, CatalogState>
    implements CatalogBloc {}

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

const _catalog = Catalog(
  providers: <ProviderEntry>[
    ProviderEntry(
      provider: 'GEMINI',
      defaultModel: 'gemini-3.1-pro-preview',
      models: <AIModel>[
        AIModel(
          id: 'gemini-3.1-pro-preview',
          supportsTemperature: true,
          supportsThinking: true,
        ),
        AIModel(
          id: 'gemini-3-flash',
          supportsTemperature: true,
          supportsThinking: true,
        ),
      ],
    ),
    ProviderEntry(
      provider: 'OPENAI',
      defaultModel: 'gpt-5-pro',
      models: <AIModel>[
        AIModel(
          id: 'gpt-5-pro',
          supportsTemperature: false,
          supportsThinking: true,
        ),
      ],
    ),
  ],
);

void main() {
  setUpAll(() {
    registerFallbackValue(const TemplateDetailLoadRequested());
    registerFallbackValue(const CatalogLoadRequested());
  });

  late _MockBloc bloc;
  late _MockCatalogBloc catalogBloc;

  setUp(() {
    bloc = _MockBloc();
    catalogBloc = _MockCatalogBloc();
    when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));
    when(
      () => catalogBloc.state,
    ).thenReturn(const CatalogLoaded(catalog: _catalog));
  });

  // La página posee su Scaffold; el host solo provee blocs.
  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<TemplateDetailBloc>.value(value: bloc),
        BlocProvider<CatalogBloc>.value(value: catalogBloc),
      ],
      child: const TemplateAiPage(),
    ),
  );

  testWidgets('Loading muestra spinner', (tester) async {
    when(() => bloc.state).thenReturn(const TemplateDetailLoading());

    await tester.pumpWidget(host());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('posee AppBar "Motor IA" y muestra los 4 stats', (tester) async {
    await tester.pumpWidget(host());

    expect(find.widgetWithText(AppBar, 'Motor IA'), findsOneWidget);
    expect(find.text('Modelo'), findsOneWidget);
    expect(find.text('gemini-3.1-pro-preview'), findsOneWidget);
    expect(find.text('Temperatura'), findsOneWidget);
    expect(find.text('0.7'), findsOneWidget);
    expect(find.text('Razonamiento'), findsOneWidget);
    expect(find.text('Medio'), findsOneWidget);
    expect(find.text('Mensajes de contexto'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
  });

  group('switch IA habilitada', () {
    testWidgets('refleja el estado y dispatcha el toggle', (tester) async {
      await tester.pumpWidget(host());

      final sw = find.byKey(const Key('template_ai.enabled'));
      expect(sw, findsOneWidget);
      expect(tester.widget<AppSwitch>(sw).value, isTrue);

      await tester.tap(sw);
      await tester.pump();

      verify(
        () => bloc.add(
          TemplateDetailAiUpdateRequested(_ai.copyWith(enabled: false)),
        ),
      ).called(1);
    });

    testWidgets('Mutating: el switch queda inerte', (tester) async {
      when(() => bloc.state).thenReturn(const TemplateDetailMutating(_tpl));

      await tester.pumpWidget(host());

      expect(
        tester
            .widget<AppSwitch>(find.byKey(const Key('template_ai.enabled')))
            .onChanged,
        isNull,
      );
    });
  });

  group('tile Modelo', () {
    testWidgets('abre el picker del catálogo; elegir modelo dispatcha', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      await tester.tap(find.byKey(const Key('template_ai.tile.model')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('template_ai.sheet.model')), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('template_ai.model.gemini-3-flash')),
      );
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          TemplateDetailAiUpdateRequested(
            _ai.copyWith(model: 'gemini-3-flash'),
          ),
        ),
      ).called(1);
      expect(find.byKey(const Key('template_ai.sheet.model')), findsNothing);
    });

    testWidgets('elegir un modelo de OTRO proveedor cambia también provider', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      await tester.tap(find.byKey(const Key('template_ai.tile.model')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('template_ai.model.gpt-5-pro')),
      );
      await tester.tap(find.byKey(const Key('template_ai.model.gpt-5-pro')));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          TemplateDetailAiUpdateRequested(
            _ai.copyWith(provider: AIProvider.openai, model: 'gpt-5-pro'),
          ),
        ),
      ).called(1);
    });

    testWidgets('sin catálogo cargado el tile no abre picker', (tester) async {
      when(() => catalogBloc.state).thenReturn(const CatalogLoading());

      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('template_ai.tile.model')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('template_ai.sheet.model')), findsNothing);
    });
  });

  group('tile Temperatura', () {
    testWidgets('abre el slider; Guardar dispatcha el valor', (tester) async {
      await tester.pumpWidget(host());

      await tester.tap(find.byKey(const Key('template_ai.tile.temperature')));
      await tester.pumpAndSettle();

      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);
      // Arrastra el thumb hasta el extremo derecho (máximo = 2.0).
      await tester.drag(slider, const Offset(400, 0));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('template_ai.sheet.temperature.save')),
      );
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          TemplateDetailAiUpdateRequested(_ai.copyWith(temperature: 2.0)),
        ),
      ).called(1);
    });

    testWidgets(
      'modelo que NO soporta temperatura: el tile no abre slider y avisa '
      '"Fija del modelo"',
      (tester) async {
        const tplGpt = Template(
          id: 't1',
          orgId: 'o1',
          name: 'Soporte',
          version: 3,
          ai: AIConfig(
            enabled: true,
            provider: AIProvider.openai,
            model: 'gpt-5-pro',
            temperature: 1.0,
            thinkingLevel: ThinkingLevel.medium,
            systemPrompt: '',
            contextMessages: 20,
          ),
        );
        when(() => bloc.state).thenReturn(const TemplateDetailLoaded(tplGpt));

        await tester.pumpWidget(host());

        expect(find.textContaining('Fija del modelo'), findsOneWidget);
        await tester.tap(find.byKey(const Key('template_ai.tile.temperature')));
        await tester.pumpAndSettle();
        expect(find.byType(Slider), findsNothing);
      },
    );
  });

  group('tile Razonamiento', () {
    testWidgets('elegir "Alto" dispatcha thinkingLevel high', (tester) async {
      await tester.pumpWidget(host());

      await tester.tap(find.byKey(const Key('template_ai.tile.thinking')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('template_ai.thinking.high')));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          TemplateDetailAiUpdateRequested(
            _ai.copyWith(thinkingLevel: ThinkingLevel.high),
          ),
        ),
      ).called(1);
    });
  });

  group('tile Mensajes de contexto', () {
    testWidgets('número nuevo + Guardar dispatcha contextMessages', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      await tester.tap(find.byKey(const Key('template_ai.tile.context')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('template_ai.sheet.context.field')),
        '30',
      );
      await tester.tap(find.byKey(const Key('template_ai.sheet.context.save')));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          TemplateDetailAiUpdateRequested(_ai.copyWith(contextMessages: 30)),
        ),
      ).called(1);
    });
  });

  testWidgets('MutationFailed muestra SnackBar con el copy del fallo', (
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
    controller.add(
      const TemplateDetailMutationFailed(_tpl, TemplatesConflictFailure()),
    );
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('Loaded muestra el prompt COMPLETO y seleccionable, sin toggle', (
    tester,
  ) async {
    final longPrompt = List<String>.generate(
      40,
      (i) => 'Línea $i del prompt.',
    ).join('\n');
    final tplLong = Template(
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
        systemPrompt: longPrompt,
        contextMessages: 20,
      ),
    );
    when(() => bloc.state).thenReturn(TemplateDetailLoaded(tplLong));

    await tester.pumpWidget(host());

    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text('Ver completo'), findsNothing);
  });

  testWidgets('prompt vacío muestra placeholder', (tester) async {
    const tplEmpty = Template(
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
        systemPrompt: '',
        contextMessages: 20,
      ),
    );
    when(() => bloc.state).thenReturn(const TemplateDetailLoaded(tplEmpty));

    await tester.pumpWidget(host());

    expect(find.text('Sin prompt definido'), findsOneWidget);
  });

  testWidgets('CTA "Entrenar prompt" apila /templates/:id/trainer', (
    tester,
  ) async {
    String? destinationUri;
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<TemplateDetailBloc>.value(value: bloc),
              BlocProvider<CatalogBloc>.value(value: catalogBloc),
            ],
            child: const TemplateAiPage(),
          ),
        ),
        GoRoute(
          path: '/templates/:id/trainer',
          builder: (_, st) {
            destinationUri = st.uri.toString();
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: AppDesignTheme.dark(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('template_ai.train_button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('template_ai.train_button')));
    await tester.pumpAndSettle();

    expect(destinationUri, '/templates/t1/trainer');
  });

  testWidgets('Failed muestra Reintentar que dispatcha load', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const TemplateDetailFailed(TemplatesServerFailure()));

    await tester.pumpWidget(host());

    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    await tester.pump();
    verify(() => bloc.add(const TemplateDetailLoadRequested())).called(1);
  });
}
