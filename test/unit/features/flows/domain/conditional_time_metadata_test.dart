import 'dart:convert';

import 'package:agentic/features/flows/domain/entities/conditional_time_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConditionalTimeMetadata.fromJsonString', () {
    test('parsea wire snake_case válido con una ventana', () {
      const raw =
          '{"tz":"America/Mexico_City","windows":[{"days":[1,2,3,4,5],'
          '"from":"09:00","to":"18:00"}],"on_match_order":1,"on_else_order":2}';
      final md = ConditionalTimeMetadata.fromJsonString(raw);
      expect(md.tz, 'America/Mexico_City');
      expect(md.onMatchOrder, 1);
      expect(md.onElseOrder, 2);
      expect(md.windows, hasLength(1));
      expect(md.windows.first.days, <int>[1, 2, 3, 4, 5]);
      expect(md.windows.first.from, '09:00');
      expect(md.windows.first.to, '18:00');
    });

    test('múltiples ventanas se preservan en orden', () {
      const raw =
          '{"tz":"UTC","windows":['
          '{"days":[0,6],"from":"00:00","to":"23:59"},'
          '{"days":[1],"from":"09:00","to":"12:00"}'
          '],"on_match_order":0,"on_else_order":3}';
      final md = ConditionalTimeMetadata.fromJsonString(raw);
      expect(md.windows, hasLength(2));
      expect(md.windows[0].days, <int>[0, 6]);
      expect(md.windows[1].days, <int>[1]);
    });

    test('json malformado → FormatException', () {
      expect(
        () => ConditionalTimeMetadata.fromJsonString('not json'),
        throwsFormatException,
      );
    });

    test('tz vacía → FormatException', () {
      const raw =
          '{"tz":"","windows":[{"days":[1],"from":"09:00","to":"10:00"}],'
          '"on_match_order":0,"on_else_order":1}';
      expect(
        () => ConditionalTimeMetadata.fromJsonString(raw),
        throwsFormatException,
      );
    });

    test('sin windows (lista vacía) → FormatException', () {
      const raw =
          '{"tz":"UTC","windows":[],"on_match_order":0,"on_else_order":1}';
      expect(
        () => ConditionalTimeMetadata.fromJsonString(raw),
        throwsFormatException,
      );
    });

    test('on_match_order negativo → FormatException', () {
      const raw =
          '{"tz":"UTC","windows":[{"days":[1],"from":"09:00","to":"10:00"}],'
          '"on_match_order":-1,"on_else_order":0}';
      expect(
        () => ConditionalTimeMetadata.fromJsonString(raw),
        throwsFormatException,
      );
    });

    test('on_else_order negativo → FormatException', () {
      const raw =
          '{"tz":"UTC","windows":[{"days":[1],"from":"09:00","to":"10:00"}],'
          '"on_match_order":0,"on_else_order":-1}';
      expect(
        () => ConditionalTimeMetadata.fromJsonString(raw),
        throwsFormatException,
      );
    });

    test('window con days vacío → FormatException', () {
      const raw =
          '{"tz":"UTC","windows":[{"days":[],"from":"09:00","to":"10:00"}],'
          '"on_match_order":0,"on_else_order":1}';
      expect(
        () => ConditionalTimeMetadata.fromJsonString(raw),
        throwsFormatException,
      );
    });

    test('window con day fuera de rango (>6) → FormatException', () {
      const raw =
          '{"tz":"UTC","windows":[{"days":[7],"from":"09:00","to":"10:00"}],'
          '"on_match_order":0,"on_else_order":1}';
      expect(
        () => ConditionalTimeMetadata.fromJsonString(raw),
        throwsFormatException,
      );
    });

    test('window con day negativo → FormatException', () {
      const raw =
          '{"tz":"UTC","windows":[{"days":[-1],"from":"09:00","to":"10:00"}],'
          '"on_match_order":0,"on_else_order":1}';
      expect(
        () => ConditionalTimeMetadata.fromJsonString(raw),
        throwsFormatException,
      );
    });

    test('from >= to (no overnight v1) → FormatException', () {
      const raw =
          '{"tz":"UTC","windows":[{"days":[1],"from":"18:00","to":"09:00"}],'
          '"on_match_order":0,"on_else_order":1}';
      expect(
        () => ConditionalTimeMetadata.fromJsonString(raw),
        throwsFormatException,
      );
    });

    test('from == to (window vacía) → FormatException', () {
      const raw =
          '{"tz":"UTC","windows":[{"days":[1],"from":"09:00","to":"09:00"}],'
          '"on_match_order":0,"on_else_order":1}';
      expect(
        () => ConditionalTimeMetadata.fromJsonString(raw),
        throwsFormatException,
      );
    });

    test('HH:MM con formato inválido (no numérico) → FormatException', () {
      const raw =
          '{"tz":"UTC","windows":[{"days":[1],"from":"9am","to":"10:00"}],'
          '"on_match_order":0,"on_else_order":1}';
      expect(
        () => ConditionalTimeMetadata.fromJsonString(raw),
        throwsFormatException,
      );
    });

    test('HH:MM fuera de rango (HH=24) → FormatException', () {
      const raw =
          '{"tz":"UTC","windows":[{"days":[1],"from":"24:00","to":"25:00"}],'
          '"on_match_order":0,"on_else_order":1}';
      expect(
        () => ConditionalTimeMetadata.fromJsonString(raw),
        throwsFormatException,
      );
    });

    test('HH:MM fuera de rango (MM=60) → FormatException', () {
      const raw =
          '{"tz":"UTC","windows":[{"days":[1],"from":"09:60","to":"10:00"}],'
          '"on_match_order":0,"on_else_order":1}';
      expect(
        () => ConditionalTimeMetadata.fromJsonString(raw),
        throwsFormatException,
      );
    });
  });

  group('ConditionalTimeMetadata.toJsonString', () {
    test('serializa con keys snake_case del wire', () {
      const md = ConditionalTimeMetadata(
        tz: 'America/Mexico_City',
        windows: <TimeWindow>[
          TimeWindow(days: <int>[1, 2, 3], from: '09:00', to: '12:00'),
        ],
        onMatchOrder: 2,
        onElseOrder: 5,
      );
      final decoded = jsonDecode(md.toJsonString()) as Map<String, dynamic>;
      expect(decoded['tz'], 'America/Mexico_City');
      expect(decoded['on_match_order'], 2);
      expect(decoded['on_else_order'], 5);
      expect(decoded.containsKey('onMatchOrder'), isFalse);
      expect(decoded.containsKey('onElseOrder'), isFalse);
      final windows = decoded['windows'] as List<dynamic>;
      expect(windows, hasLength(1));
      final w0 = windows.first as Map<String, dynamic>;
      expect(w0['days'], <dynamic>[1, 2, 3]);
      expect(w0['from'], '09:00');
      expect(w0['to'], '12:00');
    });

    test('roundtrip fromJsonString(toJsonString(md)) preserva la data', () {
      const md = ConditionalTimeMetadata(
        tz: 'UTC',
        windows: <TimeWindow>[
          TimeWindow(days: <int>[0, 6], from: '00:00', to: '23:59'),
          TimeWindow(days: <int>[3], from: '14:30', to: '15:45'),
        ],
        onMatchOrder: 0,
        onElseOrder: 1,
      );
      final back = ConditionalTimeMetadata.fromJsonString(md.toJsonString());
      expect(back, equals(md));
    });
  });

  group('ConditionalTimeMetadata value-equality', () {
    test('dos instancias con la misma data son iguales', () {
      const a = ConditionalTimeMetadata(
        tz: 'UTC',
        windows: <TimeWindow>[
          TimeWindow(days: <int>[1], from: '09:00', to: '10:00'),
        ],
        onMatchOrder: 0,
        onElseOrder: 1,
      );
      const b = ConditionalTimeMetadata(
        tz: 'UTC',
        windows: <TimeWindow>[
          TimeWindow(days: <int>[1], from: '09:00', to: '10:00'),
        ],
        onMatchOrder: 0,
        onElseOrder: 1,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('diferencia en cualquier campo rompe equality', () {
      const base = ConditionalTimeMetadata(
        tz: 'UTC',
        windows: <TimeWindow>[
          TimeWindow(days: <int>[1], from: '09:00', to: '10:00'),
        ],
        onMatchOrder: 0,
        onElseOrder: 1,
      );
      expect(
        base,
        isNot(
          equals(
            const ConditionalTimeMetadata(
              tz: 'America/Mexico_City',
              windows: <TimeWindow>[
                TimeWindow(days: <int>[1], from: '09:00', to: '10:00'),
              ],
              onMatchOrder: 0,
              onElseOrder: 1,
            ),
          ),
        ),
        reason: 'tz',
      );
      expect(
        base,
        isNot(
          equals(
            const ConditionalTimeMetadata(
              tz: 'UTC',
              windows: <TimeWindow>[
                TimeWindow(days: <int>[2], from: '09:00', to: '10:00'),
              ],
              onMatchOrder: 0,
              onElseOrder: 1,
            ),
          ),
        ),
        reason: 'window.days',
      );
      expect(
        base,
        isNot(
          equals(
            const ConditionalTimeMetadata(
              tz: 'UTC',
              windows: <TimeWindow>[
                TimeWindow(days: <int>[1], from: '09:00', to: '10:00'),
              ],
              onMatchOrder: 1,
              onElseOrder: 1,
            ),
          ),
        ),
        reason: 'onMatchOrder',
      );
    });
  });
}
