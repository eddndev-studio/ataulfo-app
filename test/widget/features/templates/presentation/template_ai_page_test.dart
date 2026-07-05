import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_switch.dart';
import 'package:ataulfo/features/ai_catalog/domain/entities/catalog.dart';
import 'package:ataulfo/features/ai_catalog/presentation/bloc/catalog_bloc.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/failures/labels_failure.dart';
import 'package:ataulfo/features/labels/presentation/bloc/labels_bloc.dart';
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

class _MockLabelsBloc extends MockBloc<LabelsEvent, LabelsState>
    implements LabelsBloc {}

const _labels = <Label>[
  Label(id: 'l1', name: 'VIP', color: '#FF0000', description: ''),
  Label(id: 'l2', name: 'Moroso', color: '#00C853', description: ''),
];

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
          supportsImageInput: true,
          supportsAudioInput: true,
          supportsDocumentInput: true,
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
    ProviderEntry(
      provider: 'NEMOTRON',
      defaultModel: 'nemotron-3-super',
      models: <AIModel>[
        AIModel(
          id: 'nemotron-3-super',
          supportsTemperature: true,
          supportsThinking: true,
        ),
        AIModel(
          id: 'nemotron-3-ultra',
          supportsTemperature: true,
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
    registerFallbackValue(const LabelsLoadRequested());
  });

  late _MockBloc bloc;
  late _MockCatalogBloc catalogBloc;
  late _MockLabelsBloc labelsBloc;

  setUp(() {
    bloc = _MockBloc();
    catalogBloc = _MockCatalogBloc();
    labelsBloc = _MockLabelsBloc();
    when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));
    when(
      () => catalogBloc.state,
    ).thenReturn(const CatalogLoaded(catalog: _catalog));
    when(() => labelsBloc.state).thenReturn(const LabelsLoaded(_labels));
  });

  // La página es content-only: el host replica el montaje del router
  // (Scaffold + AppBar planos con el título 'Motor IA').
  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<TemplateDetailBloc>.value(value: bloc),
        BlocProvider<CatalogBloc>.value(value: catalogBloc),
        BlocProvider<LabelsBloc>.value(value: labelsBloc),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('Motor IA')),
        body: const TemplateAiPage(),
      ),
    ),
  );

  testWidgets('Loading muestra spinner', (tester) async {
    when(() => bloc.state).thenReturn(const TemplateDetailLoading());

    await tester.pumpWidget(host());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('bajo el AppBar "Motor IA" del router, muestra los 4 stats', (
    tester,
  ) async {
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

  testWidgets('el editor va en una card con encabezado de sección', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    expect(find.text('Parámetros del motor'), findsOneWidget);
    expect(find.text('Cada cambio se guarda al momento.'), findsOneWidget);
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

    testWidgets('el picker muestra badges de modalidad por modelo', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('template_ai.tile.model')));
      await tester.pumpAndSettle();

      // gemini-3.1: imagen+audio+documento.
      final richRow = find.byKey(
        const Key('template_ai.model.gemini-3.1-pro-preview'),
      );
      expect(
        find.descendant(
          of: richRow,
          matching: find.byIcon(Icons.image_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: richRow, matching: find.byIcon(Icons.mic_none)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: richRow,
          matching: find.byIcon(Icons.description_outlined),
        ),
        findsOneWidget,
      );
      // gpt-5-pro: solo texto — sin badges.
      final plainRow = find.byKey(const Key('template_ai.model.gpt-5-pro'));
      expect(
        find.descendant(
          of: plainRow,
          matching: find.byIcon(Icons.image_outlined),
        ),
        findsNothing,
      );
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

  group('tile Retraso de respuesta', () {
    testWidgets('0 se lee como Inmediato', (tester) async {
      await tester.pumpWidget(host());
      expect(find.text('Retraso de respuesta'), findsOneWidget);
      expect(find.text('Inmediato'), findsOneWidget);
    });

    testWidgets('segundos nuevos + Guardar dispatcha responseDelaySeconds', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      await tester.tap(find.byKey(const Key('template_ai.tile.delay')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('template_ai.sheet.delay.field')),
        '30',
      );
      await tester.tap(find.byKey(const Key('template_ai.sheet.delay.save')));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          TemplateDetailAiUpdateRequested(
            _ai.copyWith(responseDelaySeconds: 30),
          ),
        ),
      ).called(1);
    });

    testWidgets('más de 120 deshabilita Guardar (tope del backend)', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      await tester.tap(find.byKey(const Key('template_ai.tile.delay')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('template_ai.sheet.delay.field')),
        '121',
      );
      await tester.pump();

      final save = tester.widget<AppButton>(
        find.byKey(const Key('template_ai.sheet.delay.save')),
      );
      expect(save.onPressed, isNull);
    });
  });

  group('tile Etiquetas de silencio', () {
    const tplSilenced = Template(
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
        silenceLabelIds: <String>['l1'],
      ),
    );

    testWidgets('vacío se lee como "Ninguna"', (tester) async {
      await tester.pumpWidget(host());
      expect(find.text('Etiquetas de silencio'), findsOneWidget);
      expect(find.text('Ninguna'), findsOneWidget);
    });

    testWidgets('con etiquetas muestra el conteo', (tester) async {
      const tpl2 = Template(
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
          silenceLabelIds: <String>['l1', 'l2'],
        ),
      );
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(tpl2));

      await tester.pumpWidget(host());

      expect(find.text('2 etiquetas'), findsOneWidget);
    });

    testWidgets('abre el sheet; marcar etiqueta + Guardar dispatcha', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      await tester.tap(
        find.byKey(const Key('template_ai.tile.silence_labels')),
      );
      await tester.pumpAndSettle();

      // El catálogo org-scoped se renderiza en el sheet.
      expect(
        find.byKey(const Key('template_ai.sheet.silence.option.l1')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('template_ai.sheet.silence.option.l1')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('template_ai.sheet.silence.save')));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          TemplateDetailAiUpdateRequested(
            _ai.copyWith(silenceLabelIds: const <String>['l1']),
          ),
        ),
      ).called(1);
    });

    testWidgets('una etiqueta ya elegida aparece marcada; desmarcar la quita', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(const TemplateDetailLoaded(tplSilenced));

      await tester.pumpWidget(host());

      await tester.tap(
        find.byKey(const Key('template_ai.tile.silence_labels')),
      );
      await tester.pumpAndSettle();

      final l1Row = find.byKey(
        const Key('template_ai.sheet.silence.option.l1'),
      );
      expect(
        find.descendant(of: l1Row, matching: find.byIcon(Icons.check_box)),
        findsOneWidget,
      );

      await tester.tap(l1Row);
      await tester.pump();
      await tester.tap(find.byKey(const Key('template_ai.sheet.silence.save')));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          TemplateDetailAiUpdateRequested(
            tplSilenced.ai.copyWith(silenceLabelIds: const <String>[]),
          ),
        ),
      ).called(1);
    });

    testWidgets('Mutating: el tile queda inerte', (tester) async {
      when(() => bloc.state).thenReturn(const TemplateDetailMutating(_tpl));

      await tester.pumpWidget(host());
      await tester.tap(
        find.byKey(const Key('template_ai.tile.silence_labels')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('template_ai.sheet.silence.save')),
        findsNothing,
      );
    });

    testWidgets('una etiqueta seleccionada que ya no existe se conserva', (
      tester,
    ) async {
      // 'gone' no está en el catálogo [l1, l2]: el sheet la muestra como
      // huérfana y, si no se quita, sobrevive al guardar (no se descarta).
      const tplOrphan = Template(
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
          silenceLabelIds: <String>['l1', 'gone'],
        ),
      );
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(tplOrphan));

      await tester.pumpWidget(host());
      await tester.tap(
        find.byKey(const Key('template_ai.tile.silence_labels')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('template_ai.sheet.silence.orphan.gone')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('template_ai.sheet.silence.save')));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          TemplateDetailAiUpdateRequested(
            tplOrphan.ai.copyWith(
              silenceLabelIds: const <String>['l1', 'gone'],
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('catálogo vacío muestra el empty state', (tester) async {
      when(() => labelsBloc.state).thenReturn(const LabelsLoaded(<Label>[]));

      await tester.pumpWidget(host());
      await tester.tap(
        find.byKey(const Key('template_ai.tile.silence_labels')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('template_ai.sheet.silence.empty')),
        findsOneWidget,
      );
    });

    testWidgets('error del catálogo: muestra reintento y Guardar inerte', (
      tester,
    ) async {
      when(
        () => labelsBloc.state,
      ).thenReturn(const LabelsFailed(LabelsServerFailure()));

      await tester.pumpWidget(host());
      await tester.tap(
        find.byKey(const Key('template_ai.tile.silence_labels')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('template_ai.sheet.silence.error')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<AppButton>(
              find.byKey(const Key('template_ai.sheet.silence.save')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('el copy de error sale del textTheme, no de un estilo crudo', (
      tester,
    ) async {
      when(
        () => labelsBloc.state,
      ).thenReturn(const LabelsFailed(LabelsServerFailure()));

      await tester.pumpWidget(host());
      await tester.tap(
        find.byKey(const Key('template_ai.tile.silence_labels')),
      );
      await tester.pumpAndSettle();

      final finder = find.descendant(
        of: find.byKey(const Key('template_ai.sheet.silence.error')),
        matching: find.text('No pudimos cargar las etiquetas.'),
      );
      final ctx = tester.element(finder);
      expect(
        tester.widget<Text>(finder).style,
        Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
      );
    });
  });

  group('tile Modelo de subagentes', () {
    testWidgets('sin subagente configurado se lee como "Heredado"', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      expect(find.text('Modelo de subagentes'), findsOneWidget);
      expect(find.text('Heredado'), findsOneWidget);
    });

    testWidgets('con subagente muestra el id del modelo', (tester) async {
      const tplSub = Template(
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
          subagent: SubagentModel(
            provider: AIProvider.nemotron,
            model: 'nemotron-3-super',
          ),
        ),
      );
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(tplSub));

      await tester.pumpWidget(host());
      expect(find.text('nemotron-3-super'), findsOneWidget);
    });

    testWidgets('abre el sheet; elegir un modelo fija el subagente', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      await tester.ensureVisible(
        find.byKey(const Key('template_ai.tile.subagent')),
      );
      await tester.tap(find.byKey(const Key('template_ai.tile.subagent')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('template_ai.sheet.subagent')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('template_ai.subagent.model.nemotron-3-super')),
      );
      await tester.tap(
        find.byKey(const Key('template_ai.subagent.model.nemotron-3-super')),
      );
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          TemplateDetailAiUpdateRequested(
            _ai.copyWith(
              subagent: const SubagentModel(
                provider: AIProvider.nemotron,
                model: 'nemotron-3-super',
              ),
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('elegir "Heredar" limpia el subagente (dispatcha null)', (
      tester,
    ) async {
      const tplSub = Template(
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
          subagent: SubagentModel(
            provider: AIProvider.nemotron,
            model: 'nemotron-3-super',
          ),
        ),
      );
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(tplSub));

      await tester.pumpWidget(host());

      await tester.ensureVisible(
        find.byKey(const Key('template_ai.tile.subagent')),
      );
      await tester.tap(find.byKey(const Key('template_ai.tile.subagent')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('template_ai.subagent.inherit')));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          TemplateDetailAiUpdateRequested(tplSub.ai.copyWith(subagent: null)),
        ),
      ).called(1);
    });

    testWidgets('sin catálogo cargado el tile no abre sheet', (tester) async {
      when(() => catalogBloc.state).thenReturn(const CatalogLoading());

      await tester.pumpWidget(host());
      await tester.ensureVisible(
        find.byKey(const Key('template_ai.tile.subagent')),
      );
      await tester.tap(find.byKey(const Key('template_ai.tile.subagent')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('template_ai.sheet.subagent')), findsNothing);
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

  testWidgets(
    'Loaded: el prompt va en card colapsada; el completo vive en un sheet',
    (tester) async {
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

      // Colapsado: encabezado + acción, sin volcar el prompt entero inline.
      expect(find.text('Prompt del sistema'), findsOneWidget);
      expect(find.text('Ver completo'), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);

      // "Ver completo" abre el sheet con el texto completo seleccionable.
      await tester.ensureVisible(find.text('Ver completo'));
      await tester.tap(find.text('Ver completo'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
    },
  );

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
            child: const Scaffold(body: TemplateAiPage()),
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
