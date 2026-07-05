import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_dot_label.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/entities/session_status.dart';
import 'package:ataulfo/features/bots/presentation/widgets/bot_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _bot = Bot(
  id: 'b1',
  orgId: 'o1',
  templateId: 't1',
  name: 'Soporte',
  channel: BotChannel.waUnofficial,
  identifier: '52155...',
  version: 3,
  paused: false,
  aiDisabled: false,
);

final _paused = Bot(
  id: _bot.id,
  orgId: _bot.orgId,
  templateId: _bot.templateId,
  name: _bot.name,
  channel: _bot.channel,
  identifier: _bot.identifier,
  version: _bot.version,
  paused: true,
  aiDisabled: _bot.aiDisabled,
);

Widget _host(Bot bot, {SessionState? session}) => MaterialApp(
  theme: AppDesignTheme.dark(),
  home: Scaffold(
    body: BotTile(bot: bot, sessionState: session),
  ),
);

Color _dotColorOf(WidgetTester tester) {
  final dot = tester.widget<Container>(
    find.byKey(const ValueKey('app_dot_label.dot')),
  );
  return (dot.decoration as BoxDecoration).color!;
}

void main() {
  testWidgets('bot activo NO pinta pill de estado: activo es el default', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_bot));

    expect(find.widgetWithText(AppPill, 'Activo'), findsNothing);
    expect(find.byType(AppPill), findsNothing);
  });

  testWidgets('bot pausado → pill "Pausado" (el estado excepcional sí habla)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_paused));

    expect(find.widgetWithText(AppPill, 'Pausado'), findsOneWidget);
  });

  testWidgets('sin dato de sesión → sin indicador de sesión', (tester) async {
    await tester.pumpWidget(_host(_bot));

    expect(find.byType(AppDotLabel), findsNothing);
  });

  testWidgets('CONNECTED → "Enlazado" quieto con dot success', (tester) async {
    await tester.pumpWidget(_host(_bot, session: SessionState.connected));

    expect(find.widgetWithText(AppDotLabel, 'Enlazado'), findsOneWidget);
    expect(_dotColorOf(tester), AppTokens.success);
  });

  testWidgets('DISCONNECTED → "Sin enlazar" con dot danger (accionable)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_bot, session: SessionState.disconnected));

    expect(find.widgetWithText(AppDotLabel, 'Sin enlazar'), findsOneWidget);
    expect(_dotColorOf(tester), AppTokens.danger);
  });

  testWidgets('estados de transición → "Conectando…" con dot neutro', (
    tester,
  ) async {
    for (final s in <SessionState>[
      SessionState.pairing,
      SessionState.connecting,
      SessionState.reconnecting,
    ]) {
      await tester.pumpWidget(_host(_bot, session: s));
      expect(
        find.widgetWithText(AppDotLabel, 'Conectando…'),
        findsOneWidget,
        reason: 'estado $s debe leerse como Conectando…',
      );
      expect(
        _dotColorOf(tester),
        AppTokens.text2,
        reason: 'transición es ambiental, no alarma',
      );
    }
  });

  testWidgets('pausado Y sin enlazar conviven (pill + dot)', (tester) async {
    await tester.pumpWidget(_host(_paused, session: SessionState.disconnected));

    expect(find.widgetWithText(AppPill, 'Pausado'), findsOneWidget);
    expect(find.widgetWithText(AppDotLabel, 'Sin enlazar'), findsOneWidget);
  });

  testWidgets('la key del tile se conserva (bots.tile.<id>)', (tester) async {
    await tester.pumpWidget(_host(_bot));
    expect(find.byKey(const Key('bots.tile.b1')), findsOneWidget);
  });
}
