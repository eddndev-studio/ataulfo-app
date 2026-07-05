import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/widgets/app_switch.dart';
import 'package:ataulfo/core/design/widgets/app_toggle_row.dart';

void main() {
  Future<void> pumpRow(WidgetTester tester, Widget row) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: row)));
  }

  testWidgets('pinta label + caption y el AppSwitch con su key', (
    tester,
  ) async {
    await pumpRow(
      tester,
      const AppToggleRow(
        switchKey: Key('row.switch'),
        label: 'IA habilitada',
        caption: 'Apagada, los bots no responden con IA.',
        value: true,
        onChanged: _noop,
      ),
    );
    expect(find.text('IA habilitada'), findsOneWidget);
    expect(find.text('Apagada, los bots no responden con IA.'), findsOneWidget);
    expect(find.byKey(const Key('row.switch')), findsOneWidget);
    final sw = tester.widget<AppSwitch>(find.byType(AppSwitch));
    expect(sw.value, isTrue);
  });

  testWidgets('tap en el switch dispara onChanged con el valor invertido', (
    tester,
  ) async {
    bool? received;
    await pumpRow(
      tester,
      AppToggleRow(
        switchKey: const Key('row.switch'),
        label: 'Pausado',
        caption: 'x',
        value: false,
        onChanged: (v) => received = v,
      ),
    );
    await tester.tap(find.byKey(const Key('row.switch')));
    await tester.pumpAndSettle();
    expect(received, isTrue);
  });

  testWidgets('onChanged nulo deshabilita el switch', (tester) async {
    await pumpRow(
      tester,
      const AppToggleRow(
        switchKey: Key('row.switch'),
        label: 'Inerte',
        caption: 'x',
        value: false,
        onChanged: null,
      ),
    );
    final sw = tester.widget<AppSwitch>(find.byType(AppSwitch));
    expect(sw.onChanged, isNull);
  });
}

void _noop(bool _) {}
