import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/invitations/presentation/widgets/invite_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<InviteSheetResult?> Function() pumpHost(WidgetTester tester) {
    InviteSheetResult? captured;
    var done = false;
    return () async {
      if (!done) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppDesignTheme.dark(),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      captured = await InviteSheet.open(ctx);
                      done = true;
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
      }
      return captured;
    };
  }

  testWidgets('muestra campo de correo y selector de rol', (tester) async {
    final read = pumpHost(tester);
    await read();

    expect(find.byKey(const Key('invite.email')), findsOneWidget);
    expect(find.byKey(const Key('invite.role')), findsOneWidget);
  });

  testWidgets('Enviar está deshabilitado con el correo vacío', (tester) async {
    final read = pumpHost(tester);
    await read();

    final submit = tester.widget<AppButton>(
      find.byKey(const Key('invite.submit')),
    );
    expect(submit.onPressed, isNull);
  });

  testWidgets('con correo, enviar devuelve InviteSheetResult(email, rol)', (
    tester,
  ) async {
    final read = pumpHost(tester);
    await read();

    await tester.enterText(find.byKey(const Key('invite.email')), 'a@x.com');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite.submit')));
    await tester.pumpAndSettle();

    final result = await read();
    expect(result, isNotNull);
    expect(result!.email, 'a@x.com');
    // Rol por defecto: WORKER (el invitado más común; se puede cambiar).
    expect(result.role, 'WORKER');
  });

  testWidgets('cambiar el rol se refleja en el resultado', (tester) async {
    final read = pumpHost(tester);
    await read();

    await tester.enterText(find.byKey(const Key('invite.email')), 'a@x.com');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite.role')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ADMIN').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite.submit')));
    await tester.pumpAndSettle();

    final result = await read();
    expect(result!.role, 'ADMIN');
  });

  testWidgets('recorta el correo (no envía espacios)', (tester) async {
    final read = pumpHost(tester);
    await read();

    await tester.enterText(
      find.byKey(const Key('invite.email')),
      '  a@x.com  ',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite.submit')));
    await tester.pumpAndSettle();

    final result = await read();
    expect(result!.email, 'a@x.com');
  });
}
