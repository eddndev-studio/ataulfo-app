import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/memberships/presentation/widgets/rename_org_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<String?> Function() pumpHost(
    WidgetTester tester, {
    required String currentName,
  }) {
    String? captured;
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
                      captured = await RenameOrgSheet.open(
                        ctx,
                        currentName: currentName,
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

  testWidgets('precarga el nombre actual', (tester) async {
    final read = pumpHost(tester, currentName: 'Acme');
    await read();

    expect(find.widgetWithText(TextField, 'Acme'), findsOneWidget);
  });

  testWidgets('Guardar está deshabilitado si el nombre no cambió', (
    tester,
  ) async {
    final read = pumpHost(tester, currentName: 'Acme');
    await read();

    final save = tester.widget<AppButton>(
      find.byKey(const Key('rename_org.submit')),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('cambiar el nombre y Guardar devuelve el nombre recortado', (
    tester,
  ) async {
    final read = pumpHost(tester, currentName: 'Acme');
    await read();

    await tester.enterText(
      find.byKey(const Key('rename_org.name')),
      '  Acme Inc.  ',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rename_org.submit')));
    await tester.pumpAndSettle();

    final result = await read();
    expect(result, 'Acme Inc.');
  });

  testWidgets('vaciar el nombre deshabilita Guardar', (tester) async {
    final read = pumpHost(tester, currentName: 'Acme');
    await read();

    await tester.enterText(find.byKey(const Key('rename_org.name')), '   ');
    await tester.pumpAndSettle();

    final save = tester.widget<AppButton>(
      find.byKey(const Key('rename_org.submit')),
    );
    expect(save.onPressed, isNull);
  });
}
