import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_checkbox.dart';
import 'package:ataulfo/core/design/widgets/app_checkbox_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppDesignTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('compone un AppCheckbox con título, apoyo y leading', (
    tester,
  ) async {
    await pump(
      tester,
      AppCheckboxRow(
        value: true,
        onChanged: (_) {},
        leading: const Icon(Icons.label_outline),
        title: 'Prospecto',
        subtitle: 'Activa el seguimiento automático',
      ),
    );

    expect(find.byType(AppCheckbox), findsOneWidget);
    expect(find.byIcon(Icons.label_outline), findsOneWidget);
    expect(find.text('Prospecto'), findsOneWidget);
    expect(find.text('Activa el seguimiento automático'), findsOneWidget);
  });

  testWidgets('tocar cualquier punto de la fila alterna el valor', (
    tester,
  ) async {
    bool? next;
    await pump(
      tester,
      AppCheckboxRow(
        value: false,
        onChanged: (value) => next = value,
        title: 'Recordatorios',
      ),
    );

    await tester.tap(find.text('Recordatorios'));
    expect(next, isTrue);
  });

  testWidgets('deshabilitada queda inerte y anuncia su estado', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      const AppCheckboxRow(
        value: true,
        onChanged: null,
        title: 'Herramientas bloqueadas',
      ),
    );

    await tester.tap(find.text('Herramientas bloqueadas'));
    expect(find.bySemanticsLabel('Herramientas bloqueadas'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Herramientas bloqueadas')),
      isSemantics(
        label: 'Herramientas bloqueadas',
        hasCheckedState: true,
        isChecked: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    semantics.dispose();
  });
}
