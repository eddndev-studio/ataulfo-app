import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/app_confirm_dialog.dart';
import 'package:ataulfo/core/design/tokens.dart';

void main() {
  late bool? result;

  Future<void> openDialog(
    WidgetTester tester, {
    bool destructive = true,
    Key? confirmKey,
    Key? cancelKey,
  }) async {
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showAppConfirmDialog(
                  context,
                  title: 'Título',
                  message: 'Mensaje',
                  confirmLabel: 'Eliminar',
                  destructive: destructive,
                  confirmKey: confirmKey,
                  cancelKey: cancelKey,
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('pinta título y mensaje', (tester) async {
    await openDialog(tester);
    expect(find.text('Título'), findsOneWidget);
    expect(find.text('Mensaje'), findsOneWidget);
  });

  testWidgets('confirmar devuelve true', (tester) async {
    await openDialog(tester);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('cancelar devuelve false', (tester) async {
    await openDialog(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('descartar tocando fuera devuelve false', (tester) async {
    await openDialog(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('destructive true: el confirmar es rojo (danger)', (
    tester,
  ) async {
    await openDialog(tester);
    final style = tester.widget<Text>(find.text('Eliminar')).style;
    expect(style?.color, AppTokens.danger);
  });

  testWidgets('destructive false: el confirmar es filled (onPrimary)', (
    tester,
  ) async {
    await openDialog(tester, destructive: false);
    final style = tester.widget<Text>(find.text('Eliminar')).style;
    expect(style?.color, AppTokens.onPrimary);
  });

  testWidgets('confirmKey se aplica al botón de confirmar', (tester) async {
    await openDialog(tester, confirmKey: const Key('my.confirm'));
    expect(find.byKey(const Key('my.confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('my.confirm')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('cancelKey se aplica al botón de cancelar', (tester) async {
    await openDialog(tester, cancelKey: const Key('my.cancel'));
    expect(find.byKey(const Key('my.cancel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('my.cancel')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
