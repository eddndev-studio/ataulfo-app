import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/widgets/app_radio.dart';
import 'package:ataulfo/core/design/widgets/app_radio_row.dart';

void main() {
  testWidgets('AppRadioRow compone el radio y selecciona desde toda la fila', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppRadioRow<String>(
            value: 'all',
            groupValue: 'selected',
            title: 'Toda la Biblioteca',
            subtitle: 'Incluye los recursos activos.',
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.byType(AppRadio<String>), findsOneWidget);
    expect(find.text('Toda la Biblioteca'), findsOneWidget);
    expect(find.text('Incluye los recursos activos.'), findsOneWidget);

    await tester.tap(find.text('Toda la Biblioteca'));
    await tester.pump();
    expect(selected, 'all');
  });
}
