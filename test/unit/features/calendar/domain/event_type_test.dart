import 'package:ataulfo/features/calendar/domain/entities/event_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = EventType(
    id: 'et1',
    name: 'Consulta',
    description: 'Primera visita',
    durationMin: 30,
    active: true,
  );

  group('EventType igualdad por valor', () {
    test('mismos campos ⇒ iguales y mismo hashCode', () {
      const other = EventType(
        id: 'et1',
        name: 'Consulta',
        description: 'Primera visita',
        durationMin: 30,
        active: true,
      );
      expect(base, other);
      expect(base.hashCode, other.hashCode);
    });

    test('cualquier campo distinto ⇒ desiguales', () {
      expect(base == base.copyName('X'), isFalse);
      expect(
        base ==
            const EventType(
              id: 'et1',
              name: 'Consulta',
              description: 'Primera visita',
              durationMin: 45,
              active: true,
            ),
        isFalse,
      );
      expect(
        base ==
            const EventType(
              id: 'et1',
              name: 'Consulta',
              description: 'Primera visita',
              durationMin: 30,
              active: false,
            ),
        isFalse,
      );
    });
  });
}

extension on EventType {
  EventType copyName(String name) => EventType(
    id: id,
    name: name,
    description: description,
    durationMin: durationMin,
    active: active,
  );
}
