import 'package:ataulfo/features/calendar/domain/failures/calendar_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('las variantes son subtipos sellados de CalendarFailure', () {
    const failures = <CalendarFailure>[
      CalendarNetworkFailure(),
      CalendarTimeoutFailure(),
      CalendarForbiddenFailure(),
      CalendarPlanRequiredFailure(),
      CalendarNotFoundFailure(),
      CalendarConflictFailure(),
      CalendarValidationFailure('x'),
      CalendarServerFailure(),
      UnknownCalendarFailure(),
    ];
    for (final f in failures) {
      expect(f, isA<CalendarFailure>());
      expect(f, isA<Exception>());
    }
  });

  group('CalendarValidationFailure', () {
    test('iguales por mensaje', () {
      expect(
        const CalendarValidationFailure('no'),
        const CalendarValidationFailure('no'),
      );
      expect(
        const CalendarValidationFailure('a') ==
            const CalendarValidationFailure('b'),
        isFalse,
      );
    });

    test('mensaje opcional degrada a null', () {
      expect(const CalendarValidationFailure().message, isNull);
    });
  });
}
