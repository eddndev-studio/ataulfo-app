import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/format_duration.dart';

void main() {
  group('formatAppDuration — lectura humana', () {
    test('90 s se lee "1 min 30 s"', () {
      expect(formatAppDuration(const Duration(seconds: 90)), '1 min 30 s');
    });

    test('componentes en cero se omiten: "45 s", "5 min", "1 h"', () {
      expect(formatAppDuration(const Duration(seconds: 45)), '45 s');
      expect(formatAppDuration(const Duration(minutes: 5)), '5 min');
      expect(formatAppDuration(const Duration(hours: 1)), '1 h');
    });

    test('las tres magnitudes componen: "1 h 2 min 3 s"', () {
      expect(
        formatAppDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1 h 2 min 3 s',
      );
    });

    test('duración cero se lee "0 s"', () {
      expect(formatAppDuration(Duration.zero), '0 s');
    });
  });
}
