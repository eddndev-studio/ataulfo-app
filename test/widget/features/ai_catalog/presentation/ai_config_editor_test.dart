import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_switch.dart';
import 'package:ataulfo/features/ai_catalog/domain/entities/catalog.dart';
import 'package:ataulfo/features/ai_catalog/presentation/widgets/ai_config_editor.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
      defaultModel: 'gpt-5.5',
      models: <AIModel>[
        AIModel(
          id: 'gpt-5.5',
          supportsTemperature: false,
          supportsThinking: true,
        ),
      ],
    ),
  ],
);

const _ai = AIConfig(
  enabled: true,
  provider: AIProvider.gemini,
  model: 'gemini-3.1-pro-preview',
  temperature: 0.7,
  thinkingLevel: ThinkingLevel.medium,
  systemPrompt: '',
  contextMessages: 20,
);

/// Subconjunto sin los campos de plantilla (silencio, tool groups, subagente,
/// seguimiento): la configuración que usa la pantalla de la org.
const _coreFields = <AiConfigField>{
  AiConfigField.enabled,
  AiConfigField.model,
  AiConfigField.temperature,
  AiConfigField.thinking,
  AiConfigField.contextMessages,
  AiConfigField.responseDelay,
};

void main() {
  Widget host({
    AIConfig ai = _ai,
    Catalog? catalog = _catalog,
    Set<AiConfigField> fields = _coreFields,
    bool editable = true,
    required ValueChanged<AIConfig> onChanged,
  }) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: AiConfigEditor(
          keyPrefix: 'cfg',
          ai: ai,
          catalog: catalog,
          fields: fields,
          editable: editable,
          enabledLabel: 'IA activa',
          enabledCaption: 'Enciende o apaga el motor.',
          onChanged: onChanged,
        ),
      ),
    ),
  );

  testWidgets('renderiza solo los campos del set', (tester) async {
    await tester.pumpWidget(host(onChanged: (_) {}));

    expect(find.byKey(const Key('cfg.enabled')), findsOneWidget);
    expect(find.byKey(const Key('cfg.tile.model')), findsOneWidget);
    expect(find.byKey(const Key('cfg.tile.temperature')), findsOneWidget);
    expect(find.byKey(const Key('cfg.tile.thinking')), findsOneWidget);
    expect(find.byKey(const Key('cfg.tile.context')), findsOneWidget);
    expect(find.byKey(const Key('cfg.tile.delay')), findsOneWidget);
    // Los campos de plantilla quedan fuera del set y no se pintan.
    expect(find.byKey(const Key('cfg.tile.silence_labels')), findsNothing);
    expect(find.byKey(const Key('cfg.tile.tool_groups')), findsNothing);
    expect(find.byKey(const Key('cfg.tile.subagent')), findsNothing);
    expect(find.byKey(const Key('cfg.tile.follow_up')), findsNothing);
  });

  testWidgets('el toggle emite onChanged con enabled invertido', (
    tester,
  ) async {
    AIConfig? emitted;
    await tester.pumpWidget(host(onChanged: (c) => emitted = c));

    await tester.tap(find.byKey(const Key('cfg.enabled')));
    await tester.pump();

    expect(emitted, _ai.copyWith(enabled: false));
  });

  testWidgets('elegir un modelo de otro proveedor emite provider y model', (
    tester,
  ) async {
    AIConfig? emitted;
    await tester.pumpWidget(host(onChanged: (c) => emitted = c));

    await tester.tap(find.byKey(const Key('cfg.tile.model')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cfg.sheet.model')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cfg.model.gpt-5.5')));
    await tester.pumpAndSettle();

    expect(
      emitted,
      _ai.copyWith(provider: AIProvider.openai, model: 'gpt-5.5'),
    );
    expect(find.byKey(const Key('cfg.sheet.model')), findsNothing);
  });

  testWidgets(
    'modelo sin supportsTemperature: nota "Fija del modelo" y tile inerte',
    (tester) async {
      final aiGpt = _ai.copyWith(provider: AIProvider.openai, model: 'gpt-5.5');
      await tester.pumpWidget(host(ai: aiGpt, onChanged: (_) {}));

      expect(find.textContaining('Fija del modelo'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cfg.tile.temperature')));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNothing);
    },
  );

  testWidgets('razonamiento: elegir "Alto" emite thinkingLevel high', (
    tester,
  ) async {
    AIConfig? emitted;
    await tester.pumpWidget(host(onChanged: (c) => emitted = c));

    await tester.tap(find.byKey(const Key('cfg.tile.thinking')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cfg.thinking.high')));
    await tester.pumpAndSettle();

    expect(emitted, _ai.copyWith(thinkingLevel: ThinkingLevel.high));
  });

  testWidgets('mensajes de contexto: número nuevo + Guardar emite', (
    tester,
  ) async {
    AIConfig? emitted;
    await tester.pumpWidget(host(onChanged: (c) => emitted = c));

    await tester.tap(find.byKey(const Key('cfg.tile.context')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('cfg.sheet.context.field')),
      '30',
    );
    await tester.tap(find.byKey(const Key('cfg.sheet.context.save')));
    await tester.pumpAndSettle();

    expect(emitted, _ai.copyWith(contextMessages: 30));
  });

  testWidgets('retraso 0 se lee como Inmediato', (tester) async {
    await tester.pumpWidget(host(onChanged: (_) {}));

    expect(find.text('Inmediato'), findsOneWidget);
  });

  testWidgets('editable=false deja los controles inertes', (tester) async {
    await tester.pumpWidget(host(editable: false, onChanged: (_) {}));

    expect(
      tester.widget<AppSwitch>(find.byKey(const Key('cfg.enabled'))).onChanged,
      isNull,
    );
    await tester.tap(find.byKey(const Key('cfg.tile.model')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cfg.sheet.model')), findsNothing);
  });

  testWidgets('sin catálogo el tile de modelo no abre picker', (tester) async {
    await tester.pumpWidget(host(catalog: null, onChanged: (_) {}));

    await tester.tap(find.byKey(const Key('cfg.tile.model')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cfg.sheet.model')), findsNothing);
  });
}
