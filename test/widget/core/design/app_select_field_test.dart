import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_select_field.dart';

void main() {
  const options = <AppSelectOption<String>>[
    AppSelectOption('a', 'Opción A'),
    AppSelectOption('b', 'Opción B'),
  ];

  Future<void> pumpField(
    WidgetTester tester, {
    String? value,
    ValueChanged<String?>? onChanged,
    bool enabled = true,
    String? helperText,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSelectField<String>(
            label: 'Modelo',
            helperText: helperText,
            value: value,
            options: options,
            onChanged: onChanged,
            enabled: enabled,
          ),
        ),
      ),
    );
  }

  DecoratedBox shellBox(WidgetTester tester) {
    return tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(AppSelectField<String>),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
  }

  testWidgets('pinta el label arriba y el shell con fill input + radio field', (
    tester,
  ) async {
    await pumpField(tester, value: 'a');
    expect(find.text('Modelo'), findsWidgets);
    final d = shellBox(tester).decoration as BoxDecoration;
    expect(d.color, AppTokens.input);
    expect(d.borderRadius, BorderRadius.circular(AppTokens.radiusField));
  });

  testWidgets('sin decoración Material: el underline del dropdown se apaga', (
    tester,
  ) async {
    await pumpField(tester, value: 'a');
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    // Un SizedBox.shrink() como underline elimina la línea de Material.
    expect(dropdown.underline, isA<SizedBox>());
  });

  testWidgets('elegir una opción dispara onChanged con el value', (
    tester,
  ) async {
    String? received = 'none';
    await pumpField(tester, value: null, onChanged: (v) => received = v);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opción B').last);
    await tester.pumpAndSettle();
    expect(received, 'b');
  });

  testWidgets('enabled=false deshabilita el dropdown (onChanged null)', (
    tester,
  ) async {
    await pumpField(tester, value: 'a', onChanged: (_) {}, enabled: false);
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(dropdown.onChanged, isNull);
  });

  testWidgets('helperText: se pinta bajo el field', (tester) async {
    await pumpField(tester, value: 'a', helperText: 'Ayuda del campo');
    expect(find.text('Ayuda del campo'), findsOneWidget);
  });
}
