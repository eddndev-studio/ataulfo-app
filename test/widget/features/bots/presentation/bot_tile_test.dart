import 'package:ataulfo/core/design/app_design_theme.dart';
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

Widget _host(Bot bot, {SessionState? session}) => MaterialApp(
  theme: AppDesignTheme.dark(),
  home: Scaffold(
    body: BotTile(bot: bot, sessionState: session),
  ),
);

void main() {
  testWidgets('sin dato de sesión → solo la pill de estado, sin la de sesión', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_bot));

    expect(find.widgetWithText(AppPill, 'Activo'), findsOneWidget);
    expect(find.widgetWithText(AppPill, 'Enlazado'), findsNothing);
    expect(find.widgetWithText(AppPill, 'Sin enlazar'), findsNothing);
    expect(find.widgetWithText(AppPill, 'Conectando…'), findsNothing);
  });

  testWidgets('CONNECTED → pill "Enlazado"', (tester) async {
    await tester.pumpWidget(_host(_bot, session: SessionState.connected));
    expect(find.widgetWithText(AppPill, 'Enlazado'), findsOneWidget);
  });

  testWidgets('DISCONNECTED → pill "Sin enlazar"', (tester) async {
    await tester.pumpWidget(_host(_bot, session: SessionState.disconnected));
    expect(find.widgetWithText(AppPill, 'Sin enlazar'), findsOneWidget);
  });

  testWidgets('estados de transición → pill honesta "Conectando…"', (
    tester,
  ) async {
    for (final s in <SessionState>[
      SessionState.pairing,
      SessionState.connecting,
      SessionState.reconnecting,
    ]) {
      await tester.pumpWidget(_host(_bot, session: s));
      expect(
        find.widgetWithText(AppPill, 'Conectando…'),
        findsOneWidget,
        reason: 'estado $s debe leerse como Conectando…',
      );
    }
  });

  testWidgets('la key del tile se conserva (bots.tile.<id>)', (tester) async {
    await tester.pumpWidget(_host(_bot));
    expect(find.byKey(const Key('bots.tile.b1')), findsOneWidget);
  });
}
