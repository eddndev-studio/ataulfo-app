import 'package:agentic/features/flows/presentation/widgets/conditional_time_day_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('uiDayToWire', () {
    test('mapea L-D (0..6 UI) a la convención time.Weekday (Dom=0..Sáb=6)', () {
      // UI: 0=Lun, 1=Mar, 2=Mié, 3=Jue, 4=Vie, 5=Sáb, 6=Dom (orden visual L→D)
      // Wire: 0=Dom, 1=Lun, 2=Mar, 3=Mié, 4=Jue, 5=Vie, 6=Sáb (time.Weekday Go)
      expect(uiDayToWire(0), 1, reason: 'Lun');
      expect(uiDayToWire(1), 2, reason: 'Mar');
      expect(uiDayToWire(2), 3, reason: 'Mié');
      expect(uiDayToWire(3), 4, reason: 'Jue');
      expect(uiDayToWire(4), 5, reason: 'Vie');
      expect(uiDayToWire(5), 6, reason: 'Sáb');
      expect(uiDayToWire(6), 0, reason: 'Dom');
    });
  });

  group('wireDayToUi', () {
    test('mapea Dom=0..Sáb=6 (wire) a 0..6 UI (L→D)', () {
      expect(wireDayToUi(0), 6, reason: 'Dom → último visual');
      expect(wireDayToUi(1), 0, reason: 'Lun → primero visual');
      expect(wireDayToUi(2), 1, reason: 'Mar');
      expect(wireDayToUi(3), 2, reason: 'Mié');
      expect(wireDayToUi(4), 3, reason: 'Jue');
      expect(wireDayToUi(5), 4, reason: 'Vie');
      expect(wireDayToUi(6), 5, reason: 'Sáb');
    });
  });

  group('roundtrip ui ⇄ wire', () {
    test('uiDayToWire(wireDayToUi(d)) == d para los 7 días wire', () {
      for (var w = 0; w <= 6; w++) {
        expect(uiDayToWire(wireDayToUi(w)), w, reason: 'wire=$w');
      }
    });

    test('wireDayToUi(uiDayToWire(d)) == d para los 7 índices UI', () {
      for (var u = 0; u <= 6; u++) {
        expect(wireDayToUi(uiDayToWire(u)), u, reason: 'ui=$u');
      }
    });
  });

  group('uiDayLabel', () {
    test('labels cortos L M X J V S D en orden UI', () {
      expect(uiDayLabel(0), 'L');
      expect(uiDayLabel(1), 'M');
      expect(uiDayLabel(2), 'X');
      expect(uiDayLabel(3), 'J');
      expect(uiDayLabel(4), 'V');
      expect(uiDayLabel(5), 'S');
      expect(uiDayLabel(6), 'D');
    });
  });
}
