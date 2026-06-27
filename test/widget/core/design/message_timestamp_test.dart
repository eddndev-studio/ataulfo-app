import 'package:ataulfo/core/design/widgets/message_timestamp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('hoy ⇒ solo HH:mm', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MessageTimestamp(
          at: DateTime(2026, 6, 20, 14, 30),
          now: DateTime(2026, 6, 20, 18, 0),
        ),
      ),
    );
    expect(find.text('14:30'), findsOneWidget);
  });

  testWidgets('día anterior ⇒ "Ayer HH:mm"', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MessageTimestamp(
          at: DateTime(2026, 6, 19, 9, 5),
          now: DateTime(2026, 6, 20, 10, 0),
        ),
      ),
    );
    expect(find.text('Ayer 09:05'), findsOneWidget);
  });
}
