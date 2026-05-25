import 'dart:async';

import 'package:agentic/core/design/app_design_theme.dart';
import 'package:agentic/core/design/widgets/app_button.dart';
import 'package:agentic/core/design/widgets/app_text_field.dart';
import 'package:agentic/features/bots/domain/entities/bot.dart';
import 'package:agentic/features/bots/domain/failures/bots_failure.dart';
import 'package:agentic/features/bots/presentation/bloc/bot_create_bloc.dart';
import 'package:agentic/features/bots/presentation/pages/bot_create_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<BotCreateEvent, BotCreateState>
    implements BotCreateBloc {}

const _bot = Bot(
  id: 'b9',
  orgId: 'o1',
  templateId: 't1',
  name: 'Soporte',
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
  });

  late _MockBloc bloc;

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.state).thenReturn(const BotCreateInitial());
  });

  Widget host({String? templateName = 'Soporte ventas'}) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<BotCreateBloc>.value(
      value: bloc,
      // Página content-only: el shell de la ruta aporta Scaffold/AppBar.
      child: Scaffold(
        body: BotCreatePage(templateId: 't1', templateName: templateName),
      ),
    ),
  );

  AppButton submitButton(WidgetTester tester) =>
      tester.widget<AppButton>(find.byKey(const Key('bot_create.submit')));

  testWidgets(
    'Initial muestra chip con nombre de plantilla, AppTextField y submit OFF',
    (tester) async {
      await tester.pumpWidget(host());

      expect(find.byKey(const Key('bot_create.template_chip')), findsOneWidget);
      expect(find.text('Soporte ventas'), findsOneWidget);
      // El icono description_outlined del chip sobrevive a la migración:
      // sigue siendo el indicador visual de "plantilla seleccionada".
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      // El form usa AppTextField (no TextField raw) y la key se conserva.
      expect(find.byType(AppTextField), findsOneWidget);
      expect(find.byKey(const Key('bot_create.field.name')), findsOneWidget);
      final btn = submitButton(tester);
      expect(btn.onPressed, isNull, reason: 'name vacío deshabilita el submit');
      expect(btn.loading, false);
    },
  );

  testWidgets(
    'chip muestra "Plantilla seleccionada" cuando templateName es null',
    (tester) async {
      // Caso de deep-link directo sin templateName en la URL: no exponemos
      // el UUID al operador (es ruido); mostramos un copy neutro.
      await tester.pumpWidget(host(templateName: null));

      expect(find.byKey(const Key('bot_create.template_chip')), findsOneWidget);
      expect(find.text('Plantilla seleccionada'), findsOneWidget);
    },
  );

  testWidgets('al escribir texto, el botón se habilita', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(
      find.byKey(const Key('bot_create.field.name')),
      'Bot soporte',
    );
    await tester.pump();

    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets(
    'tap "Crear" dispara BotCreateSubmitted con (templateId, name trim, '
    'WA_UNOFFICIAL)',
    (tester) async {
      await tester.pumpWidget(host());

      await tester.enterText(
        find.byKey(const Key('bot_create.field.name')),
        '  Bot soporte  ',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('bot_create.submit')));
      await tester.pump();

      verify(
        () => bloc.add(
          const BotCreateSubmitted(
            templateId: 't1',
            name: 'Bot soporte',
            channel: BotChannel.waUnofficial,
          ),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'Submitting pone el AppButton en loading=true (spinner + tap bloqueado)',
    (tester) async {
      when(() => bloc.state).thenReturn(const BotCreateSubmitting());

      await tester.pumpWidget(host());

      expect(submitButton(tester).loading, true);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets('Failed(InvalidCreate) muestra error específico', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const BotCreateFailed(BotsInvalidCreateFailure()));

    await tester.pumpWidget(host());

    expect(
      find.byKey(const Key('bot_create.error.invalid_create')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('bot_create.error.generic')), findsNothing);
  });

  testWidgets('Failed(Forbidden) muestra error de permisos', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const BotCreateFailed(BotsForbiddenFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('bot_create.error.forbidden')), findsOneWidget);
  });

  testWidgets('Failed(Network) muestra error de red', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const BotCreateFailed(BotsNetworkFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('bot_create.error.network')), findsOneWidget);
  });

  testWidgets('Failed(Timeout) agrupa con copy de red', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const BotCreateFailed(BotsTimeoutFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('bot_create.error.network')), findsOneWidget);
  });

  testWidgets('Failed(Server) colapsa al copy genérico', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const BotCreateFailed(BotsServerFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('bot_create.error.generic')), findsOneWidget);
  });

  testWidgets('Failed(NotFound) cae al genérico (dead-code defensivo)', (
    tester,
  ) async {
    // POST /bots no devuelve 404 — el sealed BotsFailure lo incluye porque
    // GET /bots/:id sí lo usa. Cubrimos el caso para asegurar que el switch
    // del page no rompe si el sealed lo arrastra.
    when(
      () => bloc.state,
    ).thenReturn(const BotCreateFailed(BotsNotFoundFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('bot_create.error.generic')), findsOneWidget);
  });

  testWidgets(
    'Succeeded reemplaza /templates/:id/bots/new con /bots/:id sobre la '
    'pila del shell (back vuelve al shell, no al formulario)',
    (tester) async {
      whenListen(
        bloc,
        Stream<BotCreateState>.fromIterable(const <BotCreateState>[
          BotCreateSucceeded(_bot),
        ]),
        initialState: const BotCreateInitial(),
      );

      final canPopAtDestination = <bool>[];
      final router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('SHELL')),
          ),
          GoRoute(
            path: '/templates/:templateId/bots/new',
            builder: (_, _) => BlocProvider<BotCreateBloc>.value(
              value: bloc,
              child: const Scaffold(
                body: BotCreatePage(templateId: 't1', templateName: 'Soporte'),
              ),
            ),
          ),
          GoRoute(
            path: '/bots/:id',
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

      await tester.pumpWidget(
        MaterialApp.router(theme: AppDesignTheme.dark(), routerConfig: router),
      );
      unawaited(router.push<void>('/templates/t1/bots/new'));
      await tester.pumpAndSettle();

      expect(
        canPopAtDestination,
        <bool>[true],
        reason:
            'tras Succeeded, el detalle del bot debe quedar sobre la pila '
            'del shell; pushReplacement reemplaza el form pero preserva el '
            'shell debajo (back vuelve al shell)',
      );
    },
  );

  testWidgets('Succeeded navega a /bots/{id} (registra la url)', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const BotCreateSucceeded(_bot));
    whenListen(
      bloc,
      Stream<BotCreateState>.fromIterable(const <BotCreateState>[
        BotCreateSucceeded(_bot),
      ]),
      initialState: const BotCreateInitial(),
    );

    final navigated = <String>[];
    final router = GoRouter(
      initialLocation: '/templates/t1/bots/new',
      routes: <RouteBase>[
        GoRoute(
          path: '/templates/:templateId/bots/new',
          builder: (_, _) => BlocProvider<BotCreateBloc>.value(
            value: bloc,
            child: const Scaffold(
              body: BotCreatePage(templateId: 't1', templateName: 'Soporte'),
            ),
          ),
        ),
        GoRoute(
          path: '/bots/:id',
          builder: (_, state) {
            navigated.add('/bots/${state.pathParameters['id']}');
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: AppDesignTheme.dark(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(navigated, <String>['/bots/b9']);
  });
}
