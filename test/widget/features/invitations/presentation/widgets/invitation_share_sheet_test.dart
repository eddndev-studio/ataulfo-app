import 'package:ataulfo/core/platform/share_service.dart';
import 'package:ataulfo/features/invitations/presentation/widgets/invitation_share_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registra el texto/asunto de la última llamada, sin tocar el SO.
class _FakeShareService implements ShareService {
  String? lastText;
  String? lastSubject;

  @override
  Future<void> shareText(String text, {String? subject}) async {
    lastText = text;
    lastSubject = subject;
  }
}

/// Simula una plataforma sin selector nativo disponible (p. ej. Linux sin
/// handler de `mailto:`), que es como falla `share_plus` ahí.
class _ThrowingShareService implements ShareService {
  @override
  Future<void> shareText(String text, {String? subject}) async {
    throw StateError('no share handler');
  }
}

void main() {
  Widget host({
    required String? token,
    required bool emailSent,
    String email = 'a@x.com',
    ShareService? shareService,
  }) => MaterialApp(
    home: Scaffold(
      body: InvitationShareSheet(
        email: email,
        token: token,
        emailSent: emailSent,
        shareService: shareService,
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
      find.byKey(const Key('invitation_share.share_message')),
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

  testWidgets(
    'compartir mensaje abre el selector del sistema con el mensaje completo',
    (tester) async {
      final share = _FakeShareService();
      await tester.pumpWidget(
        host(token: 'RAW-T', emailSent: true, shareService: share),
      );

      await tester.tap(find.byKey(const Key('invitation_share.share_message')));
      await tester.pumpAndSettle();

      expect(share.lastText, isNotNull);
      expect(share.lastText, contains('a@x.com'));
      expect(share.lastText, contains('RAW-T'));
      expect(share.lastText, contains('Para unirte'));
      // El SO ya da su propio feedback; no hay SnackBar propio en el
      // camino exitoso.
      expect(find.text('Invitación copiada'), findsNothing);
    },
  );

  testWidgets('compartir sin selector nativo (share falla) degrada a copiar el '
      'mensaje completo', (tester) async {
    await tester.pumpWidget(
      host(
        token: 'RAW-T',
        emailSent: true,
        shareService: _ThrowingShareService(),
      ),
    );

    await tester.tap(find.byKey(const Key('invitation_share.share_message')));
    await tester.pumpAndSettle();

    expect(find.text('Invitación copiada'), findsOneWidget);
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
