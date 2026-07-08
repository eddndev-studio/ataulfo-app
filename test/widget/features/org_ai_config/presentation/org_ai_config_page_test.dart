import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_switch.dart';
import 'package:ataulfo/features/ai_catalog/domain/entities/catalog.dart';
import 'package:ataulfo/features/ai_catalog/presentation/bloc/catalog_bloc.dart';
import 'package:ataulfo/features/billing/domain/entities/entitlement.dart';
import 'package:ataulfo/features/billing/presentation/bloc/entitlement_bloc.dart';
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

class _MockEntitlementBloc extends MockBloc<EntitlementEvent, EntitlementState>
    implements EntitlementBloc {}

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
    when(
      () => catalogBloc.state,
    ).thenReturn(const CatalogLoaded(catalog: _catalog));
  });

  // La página es content-only: el host replica el montaje del router
  // (Scaffold + AppBar planos con la acción Guardar como widget público).
  // El EntitlementBloc es opcional como en el router: sin repo de billing
  // la ruta monta sin él y la página degrada a no filtrar.
  Widget host({EntitlementBloc? entitlementBloc}) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<OrgAiConfigBloc>.value(value: bloc),
        BlocProvider<CatalogBloc>.value(value: catalogBloc),
        if (entitlementBloc != null)
          BlocProvider<EntitlementBloc>.value(value: entitlementBloc),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Configuración de IA'),
          actions: const <Widget>[OrgAiConfigSaveAction()],
        ),
        body: const OrgAiConfigPage(),
      ),
    ),
  );

  testWidgets('Loaded + catálogo: secciones, tile por modelo multi-host y '
      'solo-lectura single-host', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const OrgAiConfigLoaded(saved: _saved, working: _saved));

    await tester.pumpWidget(host());

    expect(find.text('Proveedor por modelo'), findsOneWidget);
    expect(find.text('Valores por defecto'), findsOneWidget);
    // MiniMax-M3 es multi-host ⇒ tile vivo (idioma tile+hoja, como la card
    // de defaults de al lado); sin pin se lee 'Automático'.
    expect(find.byKey(const Key('org_ai.host.MiniMax-M3')), findsOneWidget);
    expect(find.text('Automático'), findsOneWidget);
    // gpt-5.5 es single-host ⇒ tile solo-lectura con nota, sin candado ad-hoc.
    expect(find.byKey(const Key('org_ai.host.gpt-5.5')), findsOneWidget);
    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('Único proveedor disponible'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('el tile de un modelo multi-host abre la hoja de hosts', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const OrgAiConfigLoaded(saved: _saved, working: _saved));

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('org_ai.host.MiniMax-M3')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('org_ai.host.MiniMax-M3.auto')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('org_ai.host.MiniMax-M3.MINIMAX')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('org_ai.host.MiniMax-M3.FIREWORKS')),
      findsOneWidget,
    );
  });

  testWidgets('una caption hace legible que el guardado es explícito', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const OrgAiConfigLoaded(saved: _saved, working: _saved));

    await tester.pumpWidget(host());

    expect(
      find.text('Los cambios se aplican al tocar Guardar.'),
      findsOneWidget,
    );
  });

  testWidgets('el ListView reserva el inset inferior de la gesture-nav', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const OrgAiConfigLoaded(saved: _saved, working: _saved));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(viewPadding: const EdgeInsets.only(bottom: 34)),
            child: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<OrgAiConfigBloc>.value(value: bloc),
                BlocProvider<CatalogBloc>.value(value: catalogBloc),
              ],
              child: const Scaffold(body: OrgAiConfigPage()),
            ),
          ),
        ),
      ),
    );

    final listView = tester.widget<ListView>(find.byType(ListView));
    expect((listView.padding! as EdgeInsets).bottom, AppTokens.sp4 + 34);
  });

  testWidgets('elegir un host en la hoja dispatcha OrgAiConfigHostChanged', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const OrgAiConfigLoaded(saved: _saved, working: _saved));

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('org_ai.host.MiniMax-M3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('org_ai.host.MiniMax-M3.FIREWORKS')));
    await tester.pumpAndSettle();

    verify(
      () => bloc.add(
        const OrgAiConfigHostChanged(model: 'MiniMax-M3', host: 'FIREWORKS'),
      ),
    ).called(1);
    // Tap = elegir y cerrar: la hoja se despide sola.
    expect(
      find.byKey(const Key('org_ai.host.MiniMax-M3.FIREWORKS')),
      findsNothing,
    );
  });

  testWidgets('elegir Automático dispatcha HostChanged con host null', (
    tester,
  ) async {
    // Con FIREWORKS fijado, la hoja marca ese host y "Automático" lo quita.
    final pinned = _saved.withHost('MiniMax-M3', 'FIREWORKS');
    when(
      () => bloc.state,
    ).thenReturn(OrgAiConfigLoaded(saved: pinned, working: pinned));

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('org_ai.host.MiniMax-M3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('org_ai.host.MiniMax-M3.auto')));
    await tester.pumpAndSettle();

    verify(
      () => bloc.add(
        const OrgAiConfigHostChanged(model: 'MiniMax-M3', host: null),
      ),
    ).called(1);
  });

  group('defaults sobre el editor compartido', () {
    setUp(() {
      when(
        () => bloc.state,
      ).thenReturn(const OrgAiConfigLoaded(saved: _saved, working: _saved));
    });

    testWidgets('el toggle de IA activa dispatcha DefaultsChanged', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      final sw = find.byKey(const Key('org_ai.defaults.enabled'));
      await tester.ensureVisible(sw);
      expect(tester.widget<AppSwitch>(sw).value, isFalse);

      await tester.tap(sw);
      await tester.pump();

      verify(
        () => bloc.add(
          OrgAiConfigDefaultsChanged(_defaults.copyWith(enabled: true)),
        ),
      ).called(1);
    });

    testWidgets('elegir modelo en el picker dispatcha DefaultsChanged con '
        'provider y modelo', (tester) async {
      await tester.pumpWidget(host());

      final tile = find.byKey(const Key('org_ai.defaults.tile.model'));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('org_ai.defaults.model.MiniMax-M3')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('org_ai.defaults.model.MiniMax-M3')),
      );
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          OrgAiConfigDefaultsChanged(
            _defaults.copyWith(
              provider: AIProvider.minimax,
              model: 'MiniMax-M3',
            ),
          ),
        ),
      ).called(1);
    });
  });

  testWidgets('Guardar habilitado con cambios → dispatcha SaveRequested', (
    tester,
  ) async {
    // working != saved ⇒ dirty.
    final working = _saved.withHost('MiniMax-M3', 'FIREWORKS');
    when(
      () => bloc.state,
    ).thenReturn(OrgAiConfigLoaded(saved: _saved, working: working));

    await tester.pumpWidget(host());
    final saveBtn = find.byKey(const Key('org_ai.save'));
    expect(tester.widget<AppButton>(saveBtn).onPressed, isNotNull);

    await tester.tap(saveBtn);
    await tester.pump();
    verify(() => bloc.add(const OrgAiConfigSaveRequested())).called(1);
  });

  testWidgets('Guardar deshabilitado sin cambios', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const OrgAiConfigLoaded(saved: _saved, working: _saved));

    await tester.pumpWidget(host());
    expect(
      tester.widget<AppButton>(find.byKey(const Key('org_ai.save'))).onPressed,
      isNull,
    );
  });

  testWidgets('saveError inválido → SnackBar que cubre hosts Y defaults', (
    tester,
  ) async {
    // El PUT valida la config completa: el copy no puede señalar solo al
    // host cuando el campo inválido puede venir de los defaults.
    final controller = StreamController<OrgAiConfigState>.broadcast();
    addTearDown(controller.close);
    whenListen<OrgAiConfigState>(
      bloc,
      controller.stream,
      initialState: const OrgAiConfigLoaded(saved: _saved, working: _saved),
    );

    await tester.pumpWidget(host());
    controller.add(
      const OrgAiConfigLoaded(
        saved: _saved,
        working: _saved,
        saveError: OrgAiConfigInvalidFailure(),
      ),
    );
    await tester.pump();

    expect(
      find.text(
        'Configuración inválida: revisa los valores por defecto o el host '
        'de algún modelo.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('LoadFailed forbidden → mensaje sin permiso, sin reintentar', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const OrgAiConfigLoadFailed(OrgAiConfigForbiddenFailure()));

    await tester.pumpWidget(host());

    expect(find.textContaining('No tienes permiso'), findsOneWidget);
    expect(find.byKey(const Key('org_ai.retry')), findsNothing);
    expect(find.widgetWithText(AppButton, 'Reintentar'), findsNothing);
  });

  testWidgets('LoadFailed no-forbidden → Reintentar dispatcha load', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const OrgAiConfigLoadFailed(OrgAiConfigServerFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('org_ai.retry')), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    await tester.pump();
    verify(() => bloc.add(const OrgAiConfigLoadRequested())).called(1);
  });

  testWidgets('los sheets de valor de la org rematan en Aplicar: elegir '
      'solo acumula, el Guardar real vive en el AppBar', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const OrgAiConfigLoaded(saved: _saved, working: _saved));

    await tester.pumpWidget(host());

    final tile = find.byKey(const Key('org_ai.defaults.tile.temperature'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppButton, 'Aplicar'), findsOneWidget);
    // El único 'Guardar' visible sigue siendo el del AppBar.
    expect(find.widgetWithText(AppButton, 'Guardar'), findsOneWidget);
    expect(find.byKey(const Key('org_ai.save')), findsOneWidget);
  });

  group('guard de descarte (borrador dirty)', () {
    // Empuja la pantalla sobre una pila para observar el pop, con el mismo
    // chrome que monta la ruta real.
    Future<void> pushPage(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => MultiBlocProvider(
                        providers: <BlocProvider<dynamic>>[
                          BlocProvider<OrgAiConfigBloc>.value(value: bloc),
                          BlocProvider<CatalogBloc>.value(value: catalogBloc),
                        ],
                        child: Scaffold(
                          appBar: AppBar(
                            title: const Text('Configuración de IA'),
                            actions: const <Widget>[OrgAiConfigSaveAction()],
                          ),
                          body: const OrgAiConfigPage(),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('back con cambios sin guardar pide confirmación; Cancelar '
        'se queda', (tester) async {
      final working = _saved.withHost('MiniMax-M3', 'FIREWORKS');
      when(
        () => bloc.state,
      ).thenReturn(OrgAiConfigLoaded(saved: _saved, working: working));

      await pushPage(tester);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('¿Descartar los cambios?'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(OrgAiConfigPage), findsOneWidget); // sigue aquí
    });

    testWidgets('back con cambios + Descartar sale de la pantalla', (
      tester,
    ) async {
      final working = _saved.withHost('MiniMax-M3', 'FIREWORKS');
      when(
        () => bloc.state,
      ).thenReturn(OrgAiConfigLoaded(saved: _saved, working: working));

      await pushPage(tester);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Descartar'));
      await tester.pumpAndSettle();

      expect(find.byType(OrgAiConfigPage), findsNothing);
    });

    testWidgets('back sin cambios sale directo, sin diálogo', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(const OrgAiConfigLoaded(saved: _saved, working: _saved));

      await pushPage(tester);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('¿Descartar los cambios?'), findsNothing);
      expect(find.byType(OrgAiConfigPage), findsNothing);
    });
  });

  group('filtro del picker de defaults por plan (entitlement)', () {
    const entitlement = Entitlement(
      planCode: 'trial',
      status: 'trialing',
      usedConversations: 0,
      conversationCap: 50,
      withinQuota: true,
      quotaExceeded: false,
      storageUsedMb: 0,
      storageQuotaMb: 512,
      eligibleProviders: <String>{'MINIMAX'},
      features: <String>[],
    );

    setUp(() {
      when(
        () => bloc.state,
      ).thenReturn(const OrgAiConfigLoaded(saved: _saved, working: _saved));
    });

    Future<void> openDefaultsModelPicker(WidgetTester tester) async {
      final tile = find.byKey(const Key('org_ai.defaults.tile.model'));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }

    testWidgets('entitlement cargado: esconde los proveedores fuera del plan', (
      tester,
    ) async {
      final entitlementBloc = _MockEntitlementBloc();
      when(
        () => entitlementBloc.state,
      ).thenReturn(const EntitlementLoaded(entitlement: entitlement));

      await tester.pumpWidget(host(entitlementBloc: entitlementBloc));
      await openDefaultsModelPicker(tester);

      expect(
        find.byKey(const Key('org_ai.defaults.model.MiniMax-M3')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('org_ai.defaults.model.gpt-5.5')),
        findsNothing,
      );
    });

    testWidgets(
      'sin EntitlementBloc montado: la pantalla funciona sin filtro',
      (tester) async {
        await tester.pumpWidget(host());
        await openDefaultsModelPicker(tester);

        expect(
          find.byKey(const Key('org_ai.defaults.model.MiniMax-M3')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('org_ai.defaults.model.gpt-5.5')),
          findsOneWidget,
        );
      },
    );
  });
}
