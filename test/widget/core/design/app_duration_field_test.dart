import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/widgets/app_choice_chip.dart';
import 'package:ataulfo/core/design/widgets/app_duration_field.dart';

void main() {
  Future<void> pumpField(WidgetTester tester, Widget field) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: field)));
  }

  Finder decrement() => find.byKey(const Key('app_duration_field.decrement'));
  Finder increment() => find.byKey(const Key('app_duration_field.increment'));

  group('AppDurationField — lectura', () {
    testWidgets('90 s se lee "1 min 30 s"', (tester) async {
      await pumpField(
        tester,
        AppDurationField(value: const Duration(seconds: 90), onChanged: (_) {}),
      );
      expect(find.text('1 min 30 s'), findsOneWidget);
    });

    testWidgets('componentes en cero se omiten: "45 s", "5 min", "1 h"', (
      tester,
    ) async {
      await pumpField(
        tester,
        AppDurationField(value: const Duration(seconds: 45), onChanged: (_) {}),
      );
      expect(find.text('45 s'), findsOneWidget);

      await pumpField(
        tester,
        AppDurationField(value: const Duration(minutes: 5), onChanged: (_) {}),
      );
      expect(find.text('5 min'), findsOneWidget);

      await pumpField(
        tester,
        AppDurationField(value: const Duration(hours: 1), onChanged: (_) {}),
      );
      expect(find.text('1 h'), findsOneWidget);
    });

    testWidgets('duración cero se lee "0 s"', (tester) async {
      await pumpField(
        tester,
        AppDurationField(value: Duration.zero, onChanged: (_) {}),
      );
      expect(find.text('0 s'), findsOneWidget);
    });
  });

  group('AppDurationField — stepper adaptativo', () {
    Future<Duration?> stepFrom(
      WidgetTester tester,
      Duration value, {
      required bool up,
    }) async {
      Duration? received;
      await pumpField(
        tester,
        AppDurationField(
          value: value,
          max: const Duration(hours: 2),
          onChanged: (d) => received = d,
        ),
      );
      await tester.tap(up ? increment() : decrement());
      return received;
    }

    testWidgets('bajo 10 s el paso es fino: 9 s + → 10 s; 10 s − → 9 s', (
      tester,
    ) async {
      expect(
        await stepFrom(tester, const Duration(seconds: 9), up: true),
        const Duration(seconds: 10),
      );
      expect(
        await stepFrom(tester, const Duration(seconds: 10), up: false),
        const Duration(seconds: 9),
      );
    });

    testWidgets(
      'entre 10 s y 1 min pasos de 5 s: 10 s + → 15 s; 60 s − → 55 s',
      (tester) async {
        expect(
          await stepFrom(tester, const Duration(seconds: 10), up: true),
          const Duration(seconds: 15),
        );
        expect(
          await stepFrom(tester, const Duration(seconds: 60), up: false),
          const Duration(seconds: 55),
        );
      },
    );

    testWidgets(
      'entre 1 y 10 min pasos de 30 s: 60 s + → 90 s; 90 s − → 60 s',
      (tester) async {
        expect(
          await stepFrom(tester, const Duration(seconds: 60), up: true),
          const Duration(seconds: 90),
        );
        expect(
          await stepFrom(tester, const Duration(seconds: 90), up: false),
          const Duration(seconds: 60),
        );
      },
    );

    testWidgets('desde 10 min los pasos son de 5 min', (tester) async {
      expect(
        await stepFrom(tester, const Duration(minutes: 10), up: true),
        const Duration(minutes: 15),
      );
    });

    testWidgets(
      'un valor fuera de la rejilla se asienta en ella: 62 s + → 90 s '
      'y 62 s − → 60 s',
      (tester) async {
        expect(
          await stepFrom(tester, const Duration(seconds: 62), up: true),
          const Duration(seconds: 90),
        );
        expect(
          await stepFrom(tester, const Duration(seconds: 62), up: false),
          const Duration(seconds: 60),
        );
      },
    );
  });

  group('AppDurationField — límites', () {
    testWidgets('en el máximo el botón + queda inerte', (tester) async {
      Duration? received;
      await pumpField(
        tester,
        AppDurationField(
          value: const Duration(minutes: 5),
          max: const Duration(minutes: 5),
          onChanged: (d) => received = d,
        ),
      );
      await tester.tap(increment(), warnIfMissed: false);
      expect(received, isNull);
    });

    testWidgets('en el mínimo el botón − queda inerte', (tester) async {
      Duration? received;
      await pumpField(
        tester,
        AppDurationField(
          value: const Duration(seconds: 1),
          min: const Duration(seconds: 1),
          onChanged: (d) => received = d,
        ),
      );
      await tester.tap(decrement(), warnIfMissed: false);
      expect(received, isNull);
    });

    testWidgets('el paso nunca rebasa los límites: se recorta al máximo', (
      tester,
    ) async {
      Duration? received;
      await pumpField(
        tester,
        AppDurationField(
          value: const Duration(seconds: 55),
          max: const Duration(seconds: 58),
          onChanged: (d) => received = d,
        ),
      );
      await tester.tap(increment());
      expect(received, const Duration(seconds: 58));
    });

    testWidgets('el paso nunca rebasa los límites: se recorta al mínimo', (
      tester,
    ) async {
      Duration? received;
      await pumpField(
        tester,
        AppDurationField(
          value: const Duration(seconds: 12),
          min: const Duration(seconds: 11),
          onChanged: (d) => received = d,
        ),
      );
      await tester.tap(decrement());
      expect(received, const Duration(seconds: 11));
    });
  });

  group('AppDurationField — presets', () {
    const presets = <Duration>[
      Duration(seconds: 1),
      Duration(seconds: 30),
      Duration(minutes: 5),
    ];

    testWidgets('pinta un chip del kit por preset con su lectura', (
      tester,
    ) async {
      await pumpField(
        tester,
        AppDurationField(
          value: const Duration(seconds: 90),
          presets: presets,
          onChanged: (_) {},
        ),
      );
      expect(find.byType(AppChoiceChip), findsNWidgets(3));
      expect(find.text('1 s'), findsOneWidget);
      expect(find.text('30 s'), findsOneWidget);
      expect(find.text('5 min'), findsOneWidget);
    });

    testWidgets('el chip del preset igual al valor aparece seleccionado', (
      tester,
    ) async {
      await pumpField(
        tester,
        AppDurationField(
          value: const Duration(seconds: 30),
          presets: presets,
          onChanged: (_) {},
        ),
      );
      final chips = tester.widgetList<AppChoiceChip>(
        find.byType(AppChoiceChip),
      );
      expect(chips.map((c) => c.selected), <bool>[false, true, false]);
    });

    testWidgets('tap en un preset emite exactamente esa duración', (
      tester,
    ) async {
      Duration? received;
      await pumpField(
        tester,
        AppDurationField(
          value: const Duration(seconds: 90),
          presets: presets,
          onChanged: (d) => received = d,
        ),
      );
      await tester.tap(find.byKey(const Key('app_duration_field.preset.300')));
      expect(received, const Duration(minutes: 5));
    });

    testWidgets('sin presets no se pintan chips', (tester) async {
      await pumpField(
        tester,
        AppDurationField(value: const Duration(seconds: 90), onChanged: (_) {}),
      );
      expect(find.byType(AppChoiceChip), findsNothing);
    });
  });

  group('AppDurationField — accesibilidad y estados', () {
    testWidgets('los botones +/− ofrecen blancos táctiles de al menos 44px', (
      tester,
    ) async {
      await pumpField(
        tester,
        AppDurationField(value: const Duration(seconds: 90), onChanged: (_) {}),
      );
      for (final f in <Finder>[decrement(), increment()]) {
        final size = tester.getSize(f);
        expect(size.width, greaterThanOrEqualTo(44.0));
        expect(size.height, greaterThanOrEqualTo(44.0));
      }
    });

    testWidgets('los botones exponen rol y etiqueta accesibles', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpField(
        tester,
        AppDurationField(value: const Duration(seconds: 90), onChanged: (_) {}),
      );
      expect(
        tester.getSemantics(decrement()),
        isSemantics(isButton: true, label: 'Reducir duración'),
      );
      expect(
        tester.getSemantics(increment()),
        isSemantics(isButton: true, label: 'Aumentar duración'),
      );
      handle.dispose();
    });

    testWidgets('deshabilitado (onChanged null): sin emisión y chips inertes', (
      tester,
    ) async {
      await pumpField(
        tester,
        const AppDurationField(
          value: Duration(seconds: 30),
          presets: <Duration>[Duration(seconds: 1)],
          onChanged: null,
        ),
      );
      await tester.tap(increment(), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final chip = tester.widget<AppChoiceChip>(find.byType(AppChoiceChip));
      expect(chip.onSelected, isNull);
    });
  });
}
