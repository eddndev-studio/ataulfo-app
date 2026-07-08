import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/calendar/presentation/widgets/month_calendar_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<DateTime?> openAndReturn(
    WidgetTester tester, {
    required DateTime initial,
  }) async {
    DateTime? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await MonthCalendarSheet.open(
                    context,
                    initialDate: initial,
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('muestra el mes es-MX del initialDate', (tester) async {
    await openAndReturn(tester, initial: DateTime(2026, 7, 15));
    expect(find.text('Julio 2026'), findsOneWidget);
  });

  testWidgets('el chevron avanza de mes', (tester) async {
    await openAndReturn(tester, initial: DateTime(2026, 7, 15));
    await tester.tap(find.byKey(const Key('calendar.month.next')));
    await tester.pumpAndSettle();
    expect(find.text('Agosto 2026'), findsOneWidget);
  });

  testWidgets('tocar un día devuelve esa fecha y cierra', (tester) async {
    late Future<DateTime?> future;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => future = MonthCalendarSheet.open(
                  context,
                  initialDate: DateTime(2026, 7, 15),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calendar.month.day.20')));
    await tester.pumpAndSettle();

    expect(await future, DateTime(2026, 7, 20));
  });
}
