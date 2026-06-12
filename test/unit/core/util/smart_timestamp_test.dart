import 'package:ataulfo/core/util/smart_timestamp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Reloj inyectado: las reglas son por día calendario LOCAL, así que los
  // casos se construyen con DateTime local (no UTC) para ser deterministas
  // en cualquier zona horaria del runner.
  final now = DateTime(2026, 6, 9, 15, 30);

  int ms(DateTime dt) => dt.millisecondsSinceEpoch;

  test('hoy: solo HH:mm', () {
    expect(smartTimestamp(ms(DateTime(2026, 6, 9, 14, 5)), now: now), '14:05');
  });

  test('ayer: prefijo Ayer', () {
    expect(
      smartTimestamp(ms(DateTime(2026, 6, 8, 23, 59)), now: now),
      'Ayer 23:59',
    );
  });

  test('mismo año, anterior a ayer: DD/MM HH:mm', () {
    expect(
      smartTimestamp(ms(DateTime(2026, 1, 2, 8, 0)), now: now),
      '02/01 08:00',
    );
  });

  test('año distinto: DD/MM/YY HH:mm', () {
    expect(
      smartTimestamp(ms(DateTime(2023, 11, 14, 16, 13)), now: now),
      '14/11/23 16:13',
    );
  });

  test('cruce de medianoche: 00:01 de hoy sigue siendo hoy', () {
    expect(smartTimestamp(ms(DateTime(2026, 6, 9, 0, 1)), now: now), '00:01');
  });

  test('ayer cruzando mes (1º del mes a las 00:30)', () {
    final firstOfMonth = DateTime(2026, 6, 1, 0, 30);
    expect(
      smartTimestamp(ms(DateTime(2026, 5, 31, 22, 0)), now: firstOfMonth),
      'Ayer 22:00',
    );
  });

  group('dayLabel (separadores de día del hilo)', () {
    test('hoy → "Hoy"', () {
      expect(dayLabel(ms(DateTime(2026, 6, 9, 0, 5)), now: now), 'Hoy');
    });

    test('ayer → "Ayer"', () {
      expect(dayLabel(ms(DateTime(2026, 6, 8, 23, 59)), now: now), 'Ayer');
    });

    test('mismo año → DD/MM', () {
      expect(dayLabel(ms(DateTime(2026, 3, 2, 10, 0)), now: now), '02/03');
    });

    test('año distinto → DD/MM/YY', () {
      expect(dayLabel(ms(DateTime(2025, 12, 31, 10, 0)), now: now), '31/12/25');
    });
  });
}
