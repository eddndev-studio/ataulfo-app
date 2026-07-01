import 'package:ataulfo/features/invitations/presentation/widgets/invitation_share_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({
    required String? token,
    required bool emailSent,
    String email = 'a@x.com',
  }) => MaterialApp(
    home: Scaffold(
      body: InvitationShareSheet(
        email: email,
        token: token,
        emailSent: emailSent,
      ),
    ),
  );

  testWidgets('con token muestra el código y los botones de copiar', (
    tester,
  ) async {
    await tester.pumpWidget(host(token: 'RAW-T', emailSent: true));

    expect(find.text('Invitación creada'), findsOneWidget);
    expect(find.byKey(const Key('invitation_share.code')), findsOneWidget);
    expect(find.text('RAW-T'), findsOneWidget);
    expect(find.byKey(const Key('invitation_share.copy_code')), findsOneWidget);
    expect(
      find.byKey(const Key('invitation_share.copy_message')),
      findsOneWidget,
    );
  });

  testWidgets('email_sent:false muestra el aviso de compartir el código', (
    tester,
  ) async {
    await tester.pumpWidget(host(token: 'RAW-T', emailSent: false));

    expect(find.textContaining('No pudimos enviar el correo'), findsOneWidget);
  });

  testWidgets('copiar código muestra el aviso de copiado', (tester) async {
    await tester.pumpWidget(host(token: 'RAW-T', emailSent: true));

    await tester.tap(find.byKey(const Key('invitation_share.copy_code')));
    await tester
        .pumpAndSettle(); // resuelve el copy async + muestra el SnackBar

    expect(find.text('Código copiado'), findsOneWidget);
  });

  testWidgets('sin token (backend previo) degrada: sólo aviso de correo', (
    tester,
  ) async {
    await tester.pumpWidget(host(token: null, emailSent: true));

    expect(find.byKey(const Key('invitation_share.code')), findsNothing);
    expect(find.byKey(const Key('invitation_share.copy_code')), findsNothing);
    expect(find.textContaining('Le enviamos un correo'), findsOneWidget);
    // Sin código en pantalla, el copy NO debe pedir compartir un código.
    expect(find.textContaining('código'), findsNothing);
  });
}
