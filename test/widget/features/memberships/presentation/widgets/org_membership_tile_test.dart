import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_entity_icon.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/memberships/domain/entities/membership.dart';
import 'package:ataulfo/features/memberships/presentation/widgets/org_membership_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _membership = Membership(orgId: 'o-1', orgName: 'Acme', role: 'OWNER');

Widget _host(Widget child) => MaterialApp(
  theme: AppDesignTheme.dark(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('pinta glifo de entidad, nombre y pill de rol (look del tile)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const OrgMembershipTile(membership: _membership, isActive: false)),
    );

    // Una organización no es una persona: glifo de entidad, nunca avatar.
    expect(find.byType(AppEntityIcon), findsOneWidget);
    expect(find.byIcon(Icons.apartment_outlined), findsOneWidget);
    expect(find.text('Acme'), findsOneWidget);
    // El rol se humaniza (roleLabel), como en MemberTile/InvitationTile: antes
    // esta fila pintaba el código crudo 'OWNER'.
    expect(find.widgetWithText(AppPill, 'Propietario'), findsOneWidget);
  });

  testWidgets('isActive muestra el badge "Activa" con su key contractual', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const OrgMembershipTile(membership: _membership, isActive: true)),
    );

    expect(find.byKey(const Key('memberships.active_badge')), findsOneWidget);
  });

  testWidgets('sin isActive NO muestra el badge "Activa"', (tester) async {
    await tester.pumpWidget(
      _host(const OrgMembershipTile(membership: _membership, isActive: false)),
    );

    expect(find.byKey(const Key('memberships.active_badge')), findsNothing);
  });

  testWidgets(
    'onTap != null Y !isActive: el tile es tappable y dispara el callback',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          OrgMembershipTile(
            membership: _membership,
            isActive: false,
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.byType(AppCard));
      await tester.pump();

      expect(taps, 1);
    },
  );

  testWidgets(
    'el tile activo NO es tappable aunque reciba onTap (no doble-switch)',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          OrgMembershipTile(
            membership: _membership,
            isActive: true,
            onTap: () => taps++,
          ),
        ),
      );

      // El AppCard expone su InkWell; con la org activa el onTap se anula, así
      // que tocarlo no debe disparar el callback.
      final card = tester.widget<AppCard>(find.byType(AppCard));
      expect(card.onTap, isNull);

      await tester.tap(find.byType(AppCard), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
    },
  );

  testWidgets('sin onTap el tile no es tappable (lista de solo lectura)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const OrgMembershipTile(membership: _membership, isActive: false)),
    );

    final card = tester.widget<AppCard>(find.byType(AppCard));
    expect(card.onTap, isNull);
  });
}
