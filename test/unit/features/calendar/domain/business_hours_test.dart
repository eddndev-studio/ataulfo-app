import 'package:ataulfo/features/calendar/domain/entities/business_hours.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BusinessHoursSlot igualdad por valor', () {
    test('mismos campos ⇒ iguales y mismo hashCode', () {
      const a = BusinessHoursSlot(weekday: 1, openMin: 540, closeMin: 1080);
      const b = BusinessHoursSlot(weekday: 1, openMin: 540, closeMin: 1080);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('weekday/open/close distintos ⇒ desiguales', () {
      const a = BusinessHoursSlot(weekday: 1, openMin: 540, closeMin: 1080);
      expect(
        a == const BusinessHoursSlot(weekday: 2, openMin: 540, closeMin: 1080),
        isFalse,
      );
      expect(
        a == const BusinessHoursSlot(weekday: 1, openMin: 600, closeMin: 1080),
        isFalse,
      );
      expect(
        a == const BusinessHoursSlot(weekday: 1, openMin: 540, closeMin: 1020),
        isFalse,
      );
    });
  });
}
