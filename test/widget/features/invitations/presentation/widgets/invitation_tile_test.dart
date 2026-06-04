import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/invitations/domain/entities/invitation.dart';
import 'package:ataulfo/features/invitations/presentation/widgets/invitation_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Invitation _inv({
  String email = 'a@x.com',
  String role = 'WORKER',
  String status = 'PENDING',
  DateTime? expiresAt,
}) => Invitation(
  id: 'i1',
  email: email,
  role: role,
  status: status,
  expiresAt: expiresAt ?? DateTime.utc(2026, 6, 1),
  createdAt: DateTime.utc(2026, 5, 25),
);

final _now = DateTime.utc(2026, 5, 26); // antes de expiry por defecto
final _afterExpiry = DateTime.utc(2026, 6, 2);

Widget _host(Widget child) => MaterialApp(
  theme: AppDesignTheme.dark(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('pinta correo, rol y estado', (tester) async {
    await tester.pumpWidget(
      _host(InvitationTile(invitation: _inv(), now: _now)),
    );

    expect(find.text('a@x.com'), findsOneWidget);
    expect(find.widgetWithText(AppPill, 'WORKER'), findsOneWidget);
    expect(find.widgetWithText(AppPill, 'PENDING'), findsWidgets);
  });

  testWidgets('PENDING no caducada NO muestra badge de expirada', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(InvitationTile(invitation: _inv(), now: _now)),
    );

    expect(find.byKey(const Key('invitation_tile.expired')), findsNothing);
  });

  testWidgets('PENDING caducada muestra el badge "Expirada"', (tester) async {
    await tester.pumpWidget(
      _host(InvitationTile(invitation: _inv(), now: _afterExpiry)),
    );

    expect(find.byKey(const Key('invitation_tile.expired')), findsOneWidget);
  });

  testWidgets('ACCEPTED no muestra badge de expirada aunque pasó la fecha', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        InvitationTile(
          invitation: _inv(status: 'ACCEPTED'),
          now: _afterExpiry,
        ),
      ),
    );

    expect(find.byKey(const Key('invitation_tile.expired')), findsNothing);
  });

  testWidgets('con onCancel muestra la acción de cancelar y la dispara', (
    tester,
  ) async {
    var canceled = 0;
    await tester.pumpWidget(
      _host(
        InvitationTile(
          invitation: _inv(),
          now: _now,
          onCancel: () => canceled++,
        ),
      ),
    );

    final btn = find.byKey(const Key('invitation_tile.cancel'));
    expect(btn, findsOneWidget);
    await tester.tap(btn);
    await tester.pump();
    expect(canceled, 1);
  });

  testWidgets('sin onCancel NO muestra la acción de cancelar (terminal)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        InvitationTile(
          invitation: _inv(status: 'ACCEPTED'),
          now: _now,
        ),
      ),
    );

    expect(find.byKey(const Key('invitation_tile.cancel')), findsNothing);
  });
}
