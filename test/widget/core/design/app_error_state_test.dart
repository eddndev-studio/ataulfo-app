import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/core/design/widgets/app_error_state.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('pinta mensaje y descripción en una card', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AppErrorState(
          message: 'No se pudieron cargar los bots',
          description: 'Revisa tu conexión.',
        ),
      ),
    );
    expect(find.byType(AppCard), findsOneWidget);
    expect(find.text('No se pudieron cargar los bots'), findsOneWidget);
    expect(find.text('Revisa tu conexión.'), findsOneWidget);
  });

  testWidgets('sin onRetry: no monta botón', (tester) async {
    await tester.pumpWidget(_wrap(const AppErrorState(message: 'Error')));
    expect(find.byType(AppButton), findsNothing);
  });

  testWidgets('con onRetry: monta botón con el label y el tap lo dispara', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        AppErrorState(
          message: 'Error',
          retryLabel: 'Reintentar',
          onRetry: () => taps++,
        ),
      ),
    );
    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
