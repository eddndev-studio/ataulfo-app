import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_choice_chip.dart';
import 'package:ataulfo/features/members/domain/entities/member.dart';
import 'package:ataulfo/features/members/presentation/widgets/member_edit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _worker = Member(
  id: 'm2',
  userId: 'u2',
  email: 'worker@x.com',
  emailVerified: true,
  role: 'WORKER',
);
const _admin = Member(
  id: 'm3',
  userId: 'u3',
  email: 'admin@x.com',
  emailVerified: true,
  role: 'ADMIN',
);

void main() {
  // Abre la hoja desde una página real (showModalBottomSheet vive en otro
  // subárbol del Navigator) y captura el resultado del pop.
  Future<MemberSheetResult?> Function() pumpHost(
    WidgetTester tester,
    Member member, {
    required bool isSelf,
    bool callerIsOwner = false,
  }) {
    MemberSheetResult? captured;
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
                      captured = await MemberEditSheet.open(
                        ctx,
                        member: member,
                        isSelf: isSelf,
                        callerIsOwner: callerIsOwner,
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

  testWidgets('muestra el correo y el rol actual del miembro', (tester) async {
    final read = pumpHost(tester, _worker, isSelf: false);
    await read();

    expect(find.text('worker@x.com'), findsOneWidget);
    expect(find.byKey(const Key('member_edit.role')), findsOneWidget);
  });

  testWidgets('el picker ofrece los cuatro roles como chips a la vista', (
    tester,
  ) async {
    final read = pumpHost(tester, _worker, isSelf: false);
    await read();

    // Los cuatro roles como AppChoiceChip, sin abrir nada; el rol actual
    // (WORKER) llega preseleccionado.
    expect(find.byType(AppChoiceChip), findsNWidgets(4));
    for (final role in const <String>[
      'Propietario',
      'Administrador',
      'Supervisor',
      'Agente',
    ]) {
      expect(find.widgetWithText(AppChoiceChip, role), findsOneWidget);
    }
    final worker = tester.widget<AppChoiceChip>(
      find.widgetWithText(AppChoiceChip, 'Agente'),
    );
    expect(worker.selected, isTrue);
  });

  testWidgets('Guardar está deshabilitado si el rol no cambió (no-op)', (
    tester,
  ) async {
    final read = pumpHost(tester, _worker, isSelf: false);
    await read();

    final save = tester.widget<AppButton>(
      find.byKey(const Key('member_edit.save')),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('cambiar el rol habilita Guardar y devuelve RoleChange(rol)', (
    tester,
  ) async {
    final read = pumpHost(tester, _worker, isSelf: false);
    await read();

    await tester.tap(find.text('Administrador'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('member_edit.save')));
    await tester.pumpAndSettle();

    final result = await read();
    expect(result, isA<MemberSheetRoleChange>());
    expect((result! as MemberSheetRoleChange).role, 'ADMIN');
  });

  testWidgets('con isSelf NO se muestra el botón de quitar', (tester) async {
    final read = pumpHost(tester, _worker, isSelf: true);
    await read();

    expect(find.byKey(const Key('member_edit.remove')), findsNothing);
  });

  testWidgets('quitar pide confirmación y, confirmada, devuelve Remove', (
    tester,
  ) async {
    final read = pumpHost(tester, _worker, isSelf: false);
    await read();

    await tester.tap(find.byKey(const Key('member_edit.remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('member_edit.remove_confirm')));
    await tester.pumpAndSettle();

    final result = await read();
    expect(result, isA<MemberSheetRemove>());
  });

  testWidgets('cancelar la confirmación NO devuelve resultado de quitar', (
    tester,
  ) async {
    final read = pumpHost(tester, _worker, isSelf: false);
    await read();

    await tester.tap(find.byKey(const Key('member_edit.remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // La hoja sigue abierta; aún no hay resultado.
    expect(find.byKey(const Key('member_edit.remove')), findsOneWidget);
  });

  // --- Asignar bots (sólo WORKER) ---------------------------------------------

  testWidgets('un WORKER ofrece "Asignar bots" y devuelve AssignBots', (
    tester,
  ) async {
    final read = pumpHost(tester, _worker, isSelf: false);
    await read();

    expect(find.byKey(const Key('member_edit.assign_bots')), findsOneWidget);

    await tester.tap(find.byKey(const Key('member_edit.assign_bots')));
    await tester.pumpAndSettle();

    final result = await read();
    expect(result, isA<MemberSheetAssignBots>());
  });

  testWidgets('un no-WORKER (ADMIN) NO ofrece "Asignar bots"', (tester) async {
    final read = pumpHost(tester, _admin, isSelf: false);
    await read();

    expect(find.byKey(const Key('member_edit.assign_bots')), findsNothing);
  });

  // --- Transferir propiedad (sólo OWNER real, target no-self) ------------------

  testWidgets(
    'caller OWNER sobre otro miembro ofrece "Transferir propiedad" y, '
    'confirmado, devuelve Transfer',
    (tester) async {
      final read = pumpHost(tester, _admin, isSelf: false, callerIsOwner: true);
      await read();

      expect(find.byKey(const Key('member_edit.transfer')), findsOneWidget);

      await tester.tap(find.byKey(const Key('member_edit.transfer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('member_edit.transfer_confirm')));
      await tester.pumpAndSettle();

      final result = await read();
      expect(result, isA<MemberSheetTransfer>());
    },
  );

  testWidgets('caller NO OWNER no ofrece "Transferir propiedad"', (
    tester,
  ) async {
    final read = pumpHost(tester, _admin, isSelf: false);
    await read();

    expect(find.byKey(const Key('member_edit.transfer')), findsNothing);
  });

  testWidgets('en la propia fila no se ofrece "Transferir propiedad"', (
    tester,
  ) async {
    final read = pumpHost(tester, _admin, isSelf: true, callerIsOwner: true);
    await read();

    expect(find.byKey(const Key('member_edit.transfer')), findsNothing);
  });
}
