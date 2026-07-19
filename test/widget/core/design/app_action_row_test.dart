import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_action_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppDesignTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('pinta la anatomía de una acción y dispara el tap', (
    tester,
  ) async {
    var taps = 0;
    await pump(
      tester,
      AppActionRow(
        icon: Icons.psychology_outlined,
        title: 'Ver razonamiento',
        subtitle: 'Abre la corrida de IA',
        trailing: const Icon(Icons.chevron_right),
        onTap: () => taps++,
      ),
    );

    expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
    expect(find.text('Ver razonamiento'), findsOneWidget);
    expect(find.text('Abre la corrida de IA'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('Ver razonamiento'));
    expect(taps, 1);
  });

  testWidgets('danger usa el color semántico para icono y título', (
    tester,
  ) async {
    await pump(
      tester,
      AppActionRow(
        icon: Icons.delete_outline,
        title: 'Eliminar',
        tone: AppActionRowTone.danger,
        onTap: () {},
      ),
    );

    expect(
      tester.widget<Icon>(find.byIcon(Icons.delete_outline)).color,
      AppTokens.danger,
    );
    expect(
      tester.widget<Text>(find.text('Eliminar')).style?.color,
      AppTokens.danger,
    );
  });

  testWidgets('reserva un blanco táctil mínimo de 48 y semántica de botón', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      AppActionRow(icon: Icons.play_arrow, title: 'Ejecutar', onTap: () {}),
    );

    expect(
      tester.getSize(find.byType(AppActionRow)).height,
      greaterThanOrEqualTo(48),
    );
    expect(find.bySemanticsLabel('Ejecutar'), findsOneWidget);
    semantics.dispose();
  });
}
