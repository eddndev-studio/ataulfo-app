import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/entities/session_status.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bot_session_status_bloc.dart';
import 'package:ataulfo/features/bots/presentation/widgets/bot_connection_card.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockStatusBloc
    extends MockBloc<BotSessionStatusEvent, BotSessionStatusState>
    implements BotSessionStatusBloc {}

const _bot = Bot(
  id: 'b1',
  orgId: 'o1',
  templateId: 't1',
  name: 'Soporte',
  channel: BotChannel.waUnofficial,
  identifier: null,
  version: 1,
  paused: false,
  aiDisabled: false,
);

void main() {
  late _MockStatusBloc bloc;

  setUp(() {
    bloc = _MockStatusBloc();
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(
      body: BlocProvider<BotSessionStatusBloc>.value(
        value: bloc,
        child: const BotConnectionCard(bot: _bot),
      ),
    ),
  );

  void seed(BotSessionStatusState state) =>
      when(() => bloc.state).thenReturn(state);

  testWidgets('CONNECTED: "En línea" + CTA tonal "Gestionar conexión"', (
    tester,
  ) async {
    seed(
      const BotSessionStatusLoaded(
        SessionStatus(state: SessionState.connected),
      ),
    );

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('bot_detail.connection')), findsOneWidget);
    expect(find.text('En línea'), findsOneWidget);
    expect(
      find.widgetWithText(AppButton, 'Gestionar conexión'),
      findsOneWidget,
    );
  });

  testWidgets('DISCONNECTED: "Sin conexión" + CTA "Conectar WhatsApp"', (
    tester,
  ) async {
    seed(
      const BotSessionStatusLoaded(
        SessionStatus(state: SessionState.disconnected),
      ),
    );

    await tester.pumpWidget(host());

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Conectar WhatsApp'), findsOneWidget);
  });

  testWidgets('PAIRING: "Emparejando…" + CTA "Abrir emparejamiento"', (
    tester,
  ) async {
    seed(
      const BotSessionStatusLoaded(SessionStatus(state: SessionState.pairing)),
    );

    await tester.pumpWidget(host());

    expect(find.text('Emparejando…'), findsOneWidget);
    expect(
      find.widgetWithText(AppButton, 'Abrir emparejamiento'),
      findsOneWidget,
    );
  });

  testWidgets('Loading: comprueba el estado sin esconder el CTA', (
    tester,
  ) async {
    seed(const BotSessionStatusLoading());

    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.textContaining('Comprobando'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Conectar WhatsApp'), findsOneWidget);
  });

  testWidgets('Failed: degrada honesto ("Estado no disponible"), CTA intacto', (
    tester,
  ) async {
    seed(const BotSessionStatusFailed());

    await tester.pumpWidget(host());

    expect(find.text('Estado no disponible'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Conectar WhatsApp'), findsOneWidget);
  });

  testWidgets('tap del CTA apila /bots/:id/connect con el channel del bot', (
    tester,
  ) async {
    seed(
      const BotSessionStatusLoaded(
        SessionStatus(state: SessionState.disconnected),
      ),
    );
    final router = GoRouter(
      initialLocation: '/host',
      routes: <RouteBase>[
        GoRoute(
          path: '/host',
          builder: (_, _) => Scaffold(
            body: BlocProvider<BotSessionStatusBloc>.value(
              value: bloc,
              child: const BotConnectionCard(bot: _bot),
            ),
          ),
        ),
        GoRoute(
          path: '/bots/:id/connect',
          builder: (_, state) => Scaffold(
            body: Text(
              'connect:${state.pathParameters['id']}'
              ':${state.uri.queryParameters['channel']}',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: AppDesignTheme.dark(), routerConfig: router),
    );
    await tester.tap(find.byKey(const Key('bot_detail.connection.cta')));
    await tester.pumpAndSettle();

    expect(find.text('connect:b1:WA_UNOFFICIAL'), findsOneWidget);
  });
}
