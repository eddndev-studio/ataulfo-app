import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_avatar.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/members/domain/entities/member.dart';
import 'package:ataulfo/features/members/presentation/widgets/member_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _verified = Member(
  id: 'm1',
  userId: 'u1',
  email: 'a@x.com',
  emailVerified: true,
  role: 'OWNER',
);
const _unverified = Member(
  id: 'm2',
  userId: 'u2',
  email: 'b@x.com',
  emailVerified: false,
  role: 'WORKER',
);

Widget _host(Widget child) => MaterialApp(
  theme: AppDesignTheme.dark(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('pinta avatar, email y pill de rol (look del tile)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const MemberTile(member: _verified)));

    expect(find.byType(AppAvatar), findsOneWidget);
    expect(find.text('a@x.com'), findsOneWidget);
    expect(find.widgetWithText(AppPill, 'OWNER'), findsOneWidget);
  });

  testWidgets('miembro confirmado muestra el badge "Verificado"', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const MemberTile(member: _verified)));

    expect(find.byKey(const Key('members.verified_badge')), findsOneWidget);
    expect(find.byKey(const Key('members.unverified_badge')), findsNothing);
  });

  testWidgets('miembro sin confirmar muestra el badge "Sin confirmar"', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const MemberTile(member: _unverified)));

    expect(find.byKey(const Key('members.unverified_badge')), findsOneWidget);
    expect(find.byKey(const Key('members.verified_badge')), findsNothing);
  });

  testWidgets('con onTap el tile es tappable y dispara el callback', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(MemberTile(member: _verified, onTap: () => taps++)),
    );

    await tester.tap(find.byType(AppCard));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('sin onTap el tile no es tappable (look de solo lectura)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const MemberTile(member: _verified)));

    final card = tester.widget<AppCard>(find.byType(AppCard));
    expect(card.onTap, isNull);
  });
}
