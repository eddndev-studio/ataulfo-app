import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/auth/presentation/widgets/resend_code_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({
    required bool Function() onResend,
    bool enabled = true,
    int cooldownSeconds = 60,
  }) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(
      body: ResendCodeButton(
        onResend: onResend,
        enabled: enabled,
        cooldownSeconds: cooldownSeconds,
      ),
    ),
  );

  testWidgets('en reposo muestra "Reenviar código" y es tappable', (
    tester,
  ) async {
    var count = 0;
    await tester.pumpWidget(
      host(
        onResend: () {
          count++;
          return true;
        },
      ),
    );

    expect(find.text('Reenviar código'), findsOneWidget);

    await tester.tap(find.byType(AppButton));
    await tester.pump();

    expect(count, 1);
  });

  testWidgets('tras un envío iniciado arranca la cuenta y bloquea re-taps', (
    tester,
  ) async {
    var count = 0;
    await tester.pumpWidget(
      host(
        onResend: () {
          count++;
          return true;
        },
        cooldownSeconds: 60,
      ),
    );

    await tester.tap(find.byType(AppButton));
    await tester.pump();

    expect(find.text('Reenviar código (60s)'), findsOneWidget);

    await tester.tap(find.byType(AppButton));
    await tester.pump();
    expect(count, 1, reason: 'durante la cuenta regresiva no reenvía');
  });

  testWidgets('si el envío NO se inició (onResend=false) no arranca la cuenta', (
    tester,
  ) async {
    var count = 0;
    await tester.pumpWidget(
      host(
        onResend: () {
          count++;
          return false;
        },
      ),
    );

    await tester.tap(find.byType(AppButton));
    await tester.pump();

    // Sigue disponible ("Reenviar código", sin segundos) y se puede reintentar.
    expect(find.text('Reenviar código'), findsOneWidget);
    await tester.tap(find.byType(AppButton));
    await tester.pump();
    expect(count, 2);
  });

  testWidgets('la cuenta regresiva avanza segundo a segundo', (tester) async {
    await tester.pumpWidget(host(onResend: () => true, cooldownSeconds: 60));

    await tester.tap(find.byType(AppButton));
    await tester.pump();
    expect(find.text('Reenviar código (60s)'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Reenviar código (59s)'), findsOneWidget);
  });

  testWidgets('al agotarse la cuenta vuelve a habilitarse', (tester) async {
    var count = 0;
    await tester.pumpWidget(
      host(
        onResend: () {
          count++;
          return true;
        },
        cooldownSeconds: 3,
      ),
    );

    await tester.tap(find.byType(AppButton));
    await tester.pump();
    expect(count, 1);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Reenviar código'), findsOneWidget);

    await tester.tap(find.byType(AppButton));
    await tester.pump();
    expect(count, 2);
  });

  testWidgets('enabled=false lo deja inerte', (tester) async {
    var count = 0;
    await tester.pumpWidget(
      host(
        onResend: () {
          count++;
          return true;
        },
        enabled: false,
      ),
    );

    await tester.tap(find.byType(AppButton));
    await tester.pump();

    expect(count, 0);
  });
}
