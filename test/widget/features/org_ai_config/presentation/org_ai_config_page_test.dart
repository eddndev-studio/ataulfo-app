import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/ai_catalog/domain/entities/catalog.dart';
import 'package:ataulfo/features/ai_catalog/presentation/bloc/catalog_bloc.dart';
import 'package:ataulfo/features/org_ai_config/domain/entities/org_ai_config.dart';
import 'package:ataulfo/features/org_ai_config/domain/failures/org_ai_config_failure.dart';
import 'package:ataulfo/features/org_ai_config/presentation/bloc/org_ai_config_bloc.dart';
import 'package:ataulfo/features/org_ai_config/presentation/pages/org_ai_config_page.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<OrgAiConfigEvent, OrgAiConfigState>
    implements OrgAiConfigBloc {}

class _MockCatalogBloc extends MockBloc<CatalogEvent, CatalogState>
    implements CatalogBloc {}

const _defaults = AIConfig(
  enabled: false,
  provider: AIProvider.gemini,
  model: 'gemini-3.1-pro-preview',
  temperature: 0.7,
  thinkingLevel: ThinkingLevel.low,
  systemPrompt: '',
  contextMessages: 20,
);

const _catalog = Catalog(
  providers: <ProviderEntry>[
    ProviderEntry(
      provider: 'MINIMAX',
      defaultModel: 'MiniMax-M3',
      models: <AIModel>[
        AIModel(
          id: 'MiniMax-M3',
          supportsTemperature: true,
          supportsThinking: true,
          hosts: <String>['MINIMAX', 'FIREWORKS'],
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
          hosts: <String>['OPENAI'],
        ),
      ],
    ),
  ],
);

const _saved = OrgAiConfig(hosts: <String, String>{}, defaults: _defaults);

void main() {
  setUpAll(() {
    registerFallbackValue(const OrgAiConfigLoadRequested());
    registerFallbackValue(const CatalogLoadRequested());
  });

  late _MockBloc bloc;
  late _MockCatalogBloc catalogBloc;

  setUp(() {
    bloc = _MockBloc();
    catalogBloc = _MockCatalogBloc();
    when(() => catalogBloc.state)
        .thenReturn(const CatalogLoaded(catalog: _catalog));
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<OrgAiConfigBloc>.value(value: bloc),
        BlocProvider<CatalogBloc>.value(value: catalogBloc),
      ],
      child: const OrgAiConfigPage(),
    ),
  );

  testWidgets('Loaded + catálogo: secciones, chips multi-host y lock single',
      (tester) async {
    when(() => bloc.state)
        .thenReturn(const OrgAiConfigLoaded(saved: _saved, working: _saved));

    await tester.pumpWidget(host());

    expect(find.text('Proveedor por modelo'), findsOneWidget);
    expect(find.text('Valores por defecto'), findsOneWidget);
    // MiniMax-M3 es multi-host ⇒ chips MINIMAX/FIREWORKS/Automático.
    expect(find.byKey(const Key('org_ai.host.MiniMax-M3.MINIMAX')), findsOneWidget);
    expect(find.byKey(const Key('org_ai.host.MiniMax-M3.FIREWORKS')), findsOneWidget);
    expect(find.byKey(const Key('org_ai.host.MiniMax-M3.auto')), findsOneWidget);
    // gpt-5.5 es single-host ⇒ fila bloqueada, sin chips.
    expect(find.byKey(const Key('org_ai.host.gpt-5.5.OPENAI')), findsNothing);
    expect(find.text('Corre en OpenAI'), findsOneWidget);
  });

  testWidgets('tocar un chip de host dispatcha OrgAiConfigHostChanged',
      (tester) async {
    when(() => bloc.state)
        .thenReturn(const OrgAiConfigLoaded(saved: _saved, working: _saved));

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('org_ai.host.MiniMax-M3.FIREWORKS')));
    await tester.pump();

    verify(
      () => bloc.add(
        const OrgAiConfigHostChanged(model: 'MiniMax-M3', host: 'FIREWORKS'),
      ),
    ).called(1);
  });

  testWidgets('Guardar habilitado con cambios → dispatcha SaveRequested',
      (tester) async {
    // working != saved ⇒ dirty.
    final working = _saved.withHost('MiniMax-M3', 'FIREWORKS');
    when(() => bloc.state)
        .thenReturn(OrgAiConfigLoaded(saved: _saved, working: working));

    await tester.pumpWidget(host());
    final saveBtn = find.byKey(const Key('org_ai.save'));
    expect(tester.widget<TextButton>(saveBtn).onPressed, isNotNull);

    await tester.tap(saveBtn);
    await tester.pump();
    verify(() => bloc.add(const OrgAiConfigSaveRequested())).called(1);
  });

  testWidgets('Guardar deshabilitado sin cambios', (tester) async {
    when(() => bloc.state)
        .thenReturn(const OrgAiConfigLoaded(saved: _saved, working: _saved));

    await tester.pumpWidget(host());
    expect(
      tester.widget<TextButton>(find.byKey(const Key('org_ai.save'))).onPressed,
      isNull,
    );
  });

  testWidgets('LoadFailed forbidden → mensaje sin permiso, sin reintentar',
      (tester) async {
    when(() => bloc.state)
        .thenReturn(const OrgAiConfigLoadFailed(OrgAiConfigForbiddenFailure()));

    await tester.pumpWidget(host());

    expect(
      find.textContaining('No tienes permiso'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('org_ai.retry')), findsNothing);
  });
}
