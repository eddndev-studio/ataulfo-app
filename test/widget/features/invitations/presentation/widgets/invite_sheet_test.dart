import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_choice_chip.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/invitations/presentation/widgets/invite_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bots = <Bot>[
    Bot(
      id: 'b1',
      orgId: 'o1',
      templateId: 't1',
      name: 'Ventas',
      channel: BotChannel.waUnofficial,
      identifier: '50211111111',
      version: 1,
      paused: false,
      aiDisabled: false,
    ),
    Bot(
      id: 'b2',
      orgId: 'o1',
      templateId: 't1',
      name: 'Soporte',
      channel: BotChannel.waba,
      identifier: null,
      version: 1,
      paused: false,
      aiDisabled: false,
    ),
  ];

  Future<InviteSheetResult?> Function() pumpHost(
    WidgetTester tester, {
    List<Bot> availableBots = bots,
  }) {
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
                      captured = await InviteSheet.open(
                        ctx,
                        bots: availableBots,
                      );
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

  testWidgets('WORKER muestra los Canales disponibles y aviso con cero', (
    tester,
  ) async {
    final read = pumpHost(tester);
    await read();

    expect(find.byKey(const Key('invite.channels')), findsOneWidget);
    expect(find.text('Ventas'), findsOneWidget);
    expect(find.text('Soporte'), findsOneWidget);
    expect(find.byKey(const Key('invite.channels.warning')), findsOneWidget);
  });

  testWidgets('un WORKER devuelve sólo los canales seleccionados', (
    tester,
  ) async {
    final read = pumpHost(tester);
    await read();

    await tester.enterText(find.byKey(const Key('invite.email')), 'a@x.com');
    await tester.tap(find.text('Soporte'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('invite.submit')));
    await tester.pumpAndSettle();

    final result = await read();
    expect(result!.role, 'WORKER');
    expect(result.botIds, const <String>['b2']);
  });

  testWidgets('cambiar a un rol elevado oculta y limpia los canales', (
    tester,
  ) async {
    final read = pumpHost(tester);
    await read();

    await tester.enterText(find.byKey(const Key('invite.email')), 'a@x.com');
    await tester.tap(find.text('Ventas'));
    await tester.tap(find.text('Supervisor'));
    await tester.pump();

    expect(find.byKey(const Key('invite.channels')), findsNothing);
    await tester.tap(find.byKey(const Key('invite.submit')));
    await tester.pumpAndSettle();

    final result = await read();
    expect(result!.role, 'SUPERVISOR');
    expect(result.botIds, isEmpty);
  });

  testWidgets('sin Canales permite invitar un Agente con acceso cero', (
    tester,
  ) async {
    final read = pumpHost(tester, availableBots: const <Bot>[]);
    await read();

    await tester.enterText(find.byKey(const Key('invite.email')), 'a@x.com');
    await tester.pump();

    expect(find.textContaining('No hay Canales disponibles'), findsOneWidget);
    final submit = tester.widget<AppButton>(
      find.byKey(const Key('invite.submit')),
    );
    expect(submit.onPressed, isNotNull);
  });

  testWidgets('el rol se elige con chips del kit (todos a la vista)', (
    tester,
  ) async {
    final read = pumpHost(tester);
    await read();

    // Tres opciones (sin OWNER) como AppChoiceChip, con WORKER preseleccionado.
    expect(
      find.descendant(
        of: find.byKey(const Key('invite.role')),
        matching: find.byType(AppChoiceChip),
      ),
      findsNWidgets(3),
    );
    final worker = tester.widget<AppChoiceChip>(
      find.widgetWithText(AppChoiceChip, 'Agente'),
    );
    expect(worker.selected, isTrue);
  });

  testWidgets('Enviar está deshabilitado con el correo vacío', (tester) async {
    final read = pumpHost(tester);
    await read();

    final submit = tester.widget<AppButton>(
      find.byKey(const Key('invite.submit')),
    );
    expect(submit.onPressed, isNull);
  });

  testWidgets('correo sin forma de email deja Enviar deshabilitado', (
    tester,
  ) async {
    final read = pumpHost(tester);
    await read();

    await tester.enterText(find.byKey(const Key('invite.email')), 'x');
    await tester.pumpAndSettle();

    final submit = tester.widget<AppButton>(
      find.byKey(const Key('invite.submit')),
    );
    expect(
      submit.onPressed,
      isNull,
      reason:
          'sin @ con texto a ambos lados y punto en el dominio, '
          'el backend lo rechazaría: mejor gatear local',
    );
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
    expect(result.botIds, isEmpty);
  });

  testWidgets('cambiar el rol se refleja en el resultado', (tester) async {
    final read = pumpHost(tester);
    await read();

    await tester.enterText(find.byKey(const Key('invite.email')), 'a@x.com');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Administrador'));
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
