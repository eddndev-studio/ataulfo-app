import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_avatar.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';
import 'package:ataulfo/core/design/widgets/provider_badge.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bot_create_bloc.dart';
import 'package:ataulfo/features/bots/presentation/bot_create_draft.dart';
import 'package:ataulfo/features/bots/presentation/widgets/bot_create_sheet.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:ataulfo/features/templates/domain/failures/templates_failure.dart';
import 'package:ataulfo/features/templates/presentation/bloc/templates_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBotCreateBloc extends MockBloc<BotCreateEvent, BotCreateState>
    implements BotCreateBloc {}

class _MockTemplatesBloc extends MockBloc<TemplatesEvent, TemplatesState>
    implements TemplatesBloc {}

const _ai = AIConfig(
  enabled: false,
  provider: AIProvider.gemini,
  model: 'gemini-3.1-pro-preview',
  temperature: 0.7,
  thinkingLevel: ThinkingLevel.low,
  systemPrompt: '',
  contextMessages: 20,
);

const _t1 = Template(
  id: 't1',
  orgId: 'o1',
  name: 'Soporte ventas',
  version: 3,
  ai: _ai,
);
const _t2 = Template(
  id: 't2',
  orgId: 'o1',
  name: 'Cobranza',
  version: 1,
  ai: _ai,
);

const _bot = Bot(
  id: 'b9',
  orgId: 'o1',
  templateId: 't1',
  name: 'Bot soporte',
  channel: BotChannel.waUnofficial,
  identifier: null,
  version: 0,
  paused: false,
  aiDisabled: false,
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const BotCreateSubmitted(
        templateId: 't1',
        name: '',
        channel: BotChannel.waUnofficial,
      ),
    );
    registerFallbackValue(const TemplatesLoadRequested());
  });

  late _MockBotCreateBloc botBloc;
  late _MockTemplatesBloc tplBloc;

  setUp(() {
    botBloc = _MockBotCreateBloc();
    when(() => botBloc.state).thenReturn(const BotCreateInitial());
    tplBloc = _MockTemplatesBloc();
    when(() => tplBloc.state).thenReturn(
      const TemplatesLoaded(items: <Template>[_t1, _t2], isRefreshing: false),
    );
  });

  // Viewport alto: el form completo (título + chip + 2 campos + botón) y la
  // lista del picker pueden superar el alto default de flutter_test (600).
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // Hoja abierta con plantilla preseleccionada → arranca en el paso de nombre,
  // sin necesidad del TemplatesBloc.
  Widget nameHost({Template template = _t1}) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<BotCreateBloc>.value(
      value: botBloc,
      child: Scaffold(body: BotCreateSheet(initialTemplate: template)),
    ),
  );

  // Hoja sin plantilla → arranca en el paso de selección (consume el
  // TemplatesBloc del shell, aquí inyectado).
  Widget pickHost() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<BotCreateBloc>.value(value: botBloc),
        BlocProvider<TemplatesBloc>.value(value: tplBloc),
      ],
      child: const Scaffold(body: BotCreateSheet()),
    ),
  );

  // Hoja del flujo libre CON store de borrador inyectado (lo que hace `.open`
  // en el flujo del FAB / empty-state, dentro del subárbol del shell).
  Widget draftHost({required BotCreateDraftStore store}) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<BotCreateBloc>.value(value: botBloc),
        BlocProvider<TemplatesBloc>.value(value: tplBloc),
      ],
      child: Scaffold(body: BotCreateSheet(draftStore: store)),
    ),
  );

  // Empuja la hoja sobre una ruta real (Navigator con pila) para poder cerrar
  // con pop. `onClose` recibe el resultado del pop.
  Widget pushHost(Widget sheet, {void Function(Bot?)? onClose}) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Builder(
      builder: (ctx) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              final result = await Navigator.of(
                ctx,
              ).push<Bot>(MaterialPageRoute<Bot>(builder: (_) => sheet));
              onClose?.call(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  AppButton submitButton(WidgetTester tester) =>
      tester.widget<AppButton>(find.byKey(const Key('bot_create.submit')));

  group('paso nombre (plantilla preseleccionada)', () {
    testWidgets(
      'muestra chip de plantilla, 2 campos, submit OFF y sin "volver"',
      (tester) async {
        tall(tester);
        await tester.pumpWidget(nameHost());

        expect(find.text('Nuevo bot'), findsOneWidget);
        expect(
          find.byKey(const Key('bot_create.template_chip')),
          findsOneWidget,
        );
        expect(find.text('Soporte ventas'), findsOneWidget);
        expect(find.byIcon(Icons.description_outlined), findsOneWidget);
        expect(find.byType(AppTextField), findsNWidgets(2));
        expect(find.byKey(const Key('bot_create.field.name')), findsOneWidget);
        expect(
          find.byKey(const Key('bot_create.field.identifier')),
          findsOneWidget,
        );
        // Entró bloqueada (desde el detalle de la plantilla): no hay paso de
        // selección al cual volver.
        expect(find.byKey(const Key('bot_create.back')), findsNothing);
        final btn = submitButton(tester);
        expect(btn.onPressed, isNull);
        expect(btn.loading, false);
      },
    );

    testWidgets(
      'tap "Crear" dispara BotCreateSubmitted (templateId, name trim, '
      'WA_UNOFFICIAL)',
      (tester) async {
        tall(tester);
        await tester.pumpWidget(nameHost());

        await tester.enterText(
          find.byKey(const Key('bot_create.field.name')),
          '  Bot soporte  ',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('bot_create.submit')));
        await tester.pump();

        verify(
          () => botBloc.add(
            const BotCreateSubmitted(
              templateId: 't1',
              name: 'Bot soporte',
              channel: BotChannel.waUnofficial,
            ),
          ),
        ).called(1);
      },
    );

    testWidgets('identifier opcional viaja en el evento si se escribe', (
      tester,
    ) async {
      tall(tester);
      await tester.pumpWidget(nameHost());

      await tester.enterText(
        find.byKey(const Key('bot_create.field.name')),
        'Bot soporte',
      );
      await tester.enterText(
        find.byKey(const Key('bot_create.field.identifier')),
        '5215512345678',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('bot_create.submit')));
      await tester.pump();

      verify(
        () => botBloc.add(
          const BotCreateSubmitted(
            templateId: 't1',
            name: 'Bot soporte',
            channel: BotChannel.waUnofficial,
            identifier: '5215512345678',
          ),
        ),
      ).called(1);
    });

    testWidgets('Submitting pone el AppButton en loading', (tester) async {
      tall(tester);
      when(() => botBloc.state).thenReturn(const BotCreateSubmitting());

      await tester.pumpWidget(nameHost());

      expect(submitButton(tester).loading, true);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Failed(InvalidCreate) muestra error específico', (
      tester,
    ) async {
      tall(tester);
      when(
        () => botBloc.state,
      ).thenReturn(const BotCreateFailed(BotsInvalidCreateFailure()));

      await tester.pumpWidget(nameHost());

      expect(
        find.byKey(const Key('bot_create.error.invalid_create')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('bot_create.error.generic')), findsNothing);
    });

    testWidgets('Failed(Network) agrupa con copy de red', (tester) async {
      tall(tester);
      when(
        () => botBloc.state,
      ).thenReturn(const BotCreateFailed(BotsNetworkFailure()));

      await tester.pumpWidget(nameHost());

      expect(find.byKey(const Key('bot_create.error.network')), findsOneWidget);
    });

    testWidgets('Failed(Server) colapsa al copy genérico', (tester) async {
      tall(tester);
      when(
        () => botBloc.state,
      ).thenReturn(const BotCreateFailed(BotsServerFailure()));

      await tester.pumpWidget(nameHost());

      expect(find.byKey(const Key('bot_create.error.generic')), findsOneWidget);
    });
  });

  group('paso selección de plantilla', () {
    testWidgets('Loaded lista una AppCard con AppAvatar + ProviderBadge por '
        'plantilla', (tester) async {
      tall(tester);
      await tester.pumpWidget(pickHost());

      expect(find.text('Elegir plantilla'), findsOneWidget);
      expect(find.text('Soporte ventas'), findsOneWidget);
      expect(find.text('Cobranza'), findsOneWidget);
      expect(find.byType(AppCard), findsNWidgets(2));
      expect(find.byType(AppAvatar), findsNWidgets(2));
      expect(find.byType(ProviderBadge), findsNWidgets(2));
    });

    testWidgets('Loading muestra spinner', (tester) async {
      tall(tester);
      when(() => tplBloc.state).thenReturn(const TemplatesLoading());

      await tester.pumpWidget(pickHost());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('vacío muestra copy que apunta a la tab Plantillas', (
      tester,
    ) async {
      tall(tester);
      when(() => tplBloc.state).thenReturn(
        const TemplatesLoaded(items: <Template>[], isRefreshing: false),
      );

      await tester.pumpWidget(pickHost());

      expect(find.byKey(const Key('bot_create.pick.empty')), findsOneWidget);
    });

    testWidgets('Failed muestra retry que dispara TemplatesLoadRequested', (
      tester,
    ) async {
      tall(tester);
      when(
        () => tplBloc.state,
      ).thenReturn(const TemplatesFailed(TemplatesNetworkFailure()));

      await tester.pumpWidget(pickHost());

      expect(find.byKey(const Key('bot_create.pick.error')), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
      await tester.pump();
      verify(() => tplBloc.add(const TemplatesLoadRequested())).called(1);
    });

    testWidgets('tap en una plantilla avanza al paso de nombre con esa '
        'plantilla y botón "volver"', (tester) async {
      tall(tester);
      await tester.pumpWidget(pickHost());

      await tester.tap(find.byKey(const Key('bot_create.pick.t2')));
      await tester.pumpAndSettle();

      expect(find.text('Nuevo bot'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('bot_create.template_chip')),
          matching: find.text('Cobranza'),
        ),
        findsOneWidget,
      );
      // Hubo paso de selección: el "volver" está disponible.
      expect(find.byKey(const Key('bot_create.back')), findsOneWidget);
    });

    testWidgets('"volver" desde el paso de nombre regresa al selector', (
      tester,
    ) async {
      tall(tester);
      await tester.pumpWidget(pickHost());

      await tester.tap(find.byKey(const Key('bot_create.pick.t1')));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo bot'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bot_create.back')));
      await tester.pumpAndSettle();

      expect(find.text('Elegir plantilla'), findsOneWidget);
      expect(find.byType(AppCard), findsNWidgets(2));
    });
  });

  testWidgets('Succeeded cierra la hoja devolviendo el Bot creado', (
    tester,
  ) async {
    tall(tester);
    final controller = StreamController<BotCreateState>();
    addTearDown(controller.close);
    whenListen(
      botBloc,
      controller.stream,
      initialState: const BotCreateInitial(),
    );

    Bot? returned;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  returned = await Navigator.of(ctx).push<Bot>(
                    MaterialPageRoute<Bot>(
                      builder: (_) => BlocProvider<BotCreateBloc>.value(
                        value: botBloc,
                        child: const Scaffold(
                          body: BotCreateSheet(initialTemplate: _t1),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo bot'), findsOneWidget);

    controller.add(const BotCreateSucceeded(_bot));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo bot'), findsNothing, reason: 'cerró');
    expect(returned, _bot);
  });

  group('borrador (draft) del wizard', () {
    testWidgets('restaura plantilla + nombre + identificador al abrir', (
      tester,
    ) async {
      tall(tester);
      final store = BotCreateDraftStore()
        ..save(
          const BotCreateDraft(template: _t1, name: 'Bot X', identifier: '55'),
        );

      await tester.pumpWidget(draftHost(store: store));

      // Con plantilla restaurada arranca directo en el paso de nombre.
      expect(find.text('Nuevo bot'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('bot_create.template_chip')),
          matching: find.text('Soporte ventas'),
        ),
        findsOneWidget,
      );
      expect(find.text('Bot X'), findsOneWidget);
      expect(find.text('55'), findsOneWidget);
      expect(submitButton(tester).onPressed, isNotNull);
    });

    testWidgets('persiste el progreso y sobrevive al cierre del modal', (
      tester,
    ) async {
      tall(tester);
      final store = BotCreateDraftStore();
      await tester.pumpWidget(draftHost(store: store));

      await tester.tap(find.byKey(const Key('bot_create.pick.t2')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('bot_create.field.name')),
        'Bot Y',
      );
      await tester.pump();

      // Cierre del modal: la hoja se desmonta. El borrador debe sobrevivir.
      await tester.pumpWidget(const SizedBox());

      expect(store.current?.template, _t2);
      expect(store.current?.name, 'Bot Y');
    });

    testWidgets('limpia el borrador al crear con éxito', (tester) async {
      tall(tester);
      final store = BotCreateDraftStore()
        ..save(const BotCreateDraft(template: _t1, name: 'Bot'));
      final controller = StreamController<BotCreateState>();
      addTearDown(controller.close);
      whenListen(
        botBloc,
        controller.stream,
        initialState: const BotCreateInitial(),
      );

      await tester.pumpWidget(
        pushHost(
          MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<BotCreateBloc>.value(value: botBloc),
              BlocProvider<TemplatesBloc>.value(value: tplBloc),
            ],
            child: Scaffold(body: BotCreateSheet(draftStore: store)),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      controller.add(const BotCreateSucceeded(_bot));
      await tester.pumpAndSettle();

      expect(store.current, isNull);
    });

    testWidgets('"Descartar" limpia el borrador y cierra la hoja', (
      tester,
    ) async {
      tall(tester);
      final store = BotCreateDraftStore()
        ..save(const BotCreateDraft(template: _t1, name: 'Bot'));

      Bot? returned;
      var popped = false;
      await tester.pumpWidget(
        pushHost(
          MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<BotCreateBloc>.value(value: botBloc),
              BlocProvider<TemplatesBloc>.value(value: tplBloc),
            ],
            child: Scaffold(body: BotCreateSheet(draftStore: store)),
          ),
          onClose: (r) {
            returned = r;
            popped = true;
          },
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo bot'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bot_create.discard')));
      await tester.pumpAndSettle();

      expect(store.current, isNull);
      expect(find.text('Nuevo bot'), findsNothing, reason: 'cerró');
      expect(popped, isTrue);
      expect(returned, isNull);
    });

    testWidgets('"Descartar" aparece sólo cuando hay contenido', (
      tester,
    ) async {
      tall(tester);
      final store = BotCreateDraftStore();
      await tester.pumpWidget(draftHost(store: store));

      // Paso de selección sin nada elegido → nada que descartar.
      expect(find.text('Elegir plantilla'), findsOneWidget);
      expect(find.byKey(const Key('bot_create.discard')), findsNothing);

      // Al elegir plantilla ya hay contenido → aparece "Descartar".
      await tester.tap(find.byKey(const Key('bot_create.pick.t1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bot_create.discard')), findsOneWidget);
    });

    testWidgets('flujo bloqueado no usa borrador ni ofrece "Descartar"', (
      tester,
    ) async {
      tall(tester);
      // nameHost NO inyecta store: el flujo bloqueado (desde el detalle de la
      // plantilla) no lee ni escribe borradores.
      await tester.pumpWidget(nameHost());

      expect(
        find.descendant(
          of: find.byKey(const Key('bot_create.template_chip')),
          matching: find.text('Soporte ventas'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('bot_create.discard')), findsNothing);
    });
  });
}
