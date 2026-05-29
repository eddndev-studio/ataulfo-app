import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/features/flows/domain/conditional_time_reorder.dart';
import 'package:ataulfo/features/flows/domain/entities/conditional_time_metadata.dart';
import 'package:ataulfo/features/flows/domain/entities/step.dart';

/// Metadata CONDITIONAL_TIME canónica con destinos parametrizables. Las
/// ventanas son irrelevantes para el remap — solo importan los `order`
/// destino — pero deben ser válidas para que `fromJsonString` no rompa.
String _ctJson({required int onMatch, required int onElse}) =>
    ConditionalTimeMetadata(
      tz: 'America/Mexico_City',
      windows: const <TimeWindow>[
        TimeWindow(days: <int>[1, 2, 3, 4, 5], from: '09:00', to: '18:00'),
      ],
      onMatchOrder: onMatch,
      onElseOrder: onElse,
    ).toJsonString();

Step _text(String id, int order) => Step(
  id: id,
  flowId: 'f1',
  type: StepType.text,
  order: order,
  content: id.toUpperCase(),
  mediaRef: '',
  metadataJson: '{}',
  delayMs: 0,
  jitterPct: 0,
  aiOnly: false,
);

Step _ct(
  String id,
  int order, {
  required int onMatch,
  required int onElse,
  String? rawMetadata,
}) => Step(
  id: id,
  flowId: 'f1',
  type: StepType.conditionalTime,
  order: order,
  content: '',
  mediaRef: '',
  metadataJson: rawMetadata ?? _ctJson(onMatch: onMatch, onElse: onElse),
  delayMs: 0,
  jitterPct: 0,
  aiOnly: false,
);

void main() {
  group('remapConditionalTargetsOnReorder', () {
    test('sigue al paso lógico (por id) cuando los destinos cambian de '
        'posición', () {
      // a(0) ct(1) c(2). El CT bifurca a c (onMatch=2) y a a (onElse=0).
      // Reorder [c, a, ct] ⇒ c→0, a→1, ct→2.
      final snapshot = <Step>[
        _text('a', 0),
        _ct('b', 1, onMatch: 2, onElse: 0),
        _text('c', 2),
      ];

      final result = remapConditionalTargetsOnReorder(snapshot, <String>[
        'c',
        'a',
        'b',
      ]);

      expect(result.keys, <String>['b']);
      final md = ConditionalTimeMetadata.fromJsonString(result['b']!);
      expect(md.onMatchOrder, 0); // c (era order 2) ahora en índice 0
      expect(md.onElseOrder, 1); // a (era order 0) ahora en índice 1
    });

    test('indexa por valor de `order`, no por índice de lista '
        '(orders con hueco)', () {
      // c tiene order=3 (hueco: no existe un paso con order 2). El destino
      // onMatch=3 debe resolverse a c por su campo `order`, no por la
      // posición 3 de la lista (que no existe). Si se indexara por índice,
      // onMatch=3 quedaría colgante y NO se remaparía → este test fallaría.
      final snapshot = <Step>[
        _text('a', 0),
        _ct('b', 1, onMatch: 3, onElse: 0),
        _text('c', 3),
      ];

      final result = remapConditionalTargetsOnReorder(snapshot, <String>[
        'c',
        'a',
        'b',
      ]);

      final md = ConditionalTimeMetadata.fromJsonString(result['b']!);
      expect(md.onMatchOrder, 0); // c → índice 0
      expect(md.onElseOrder, 1); // a → índice 1
    });

    test('la auto-referencia sigue al propio CT', () {
      // El CT bifurca a sí mismo (onMatch=1 = su propio order). Tras moverlo
      // a índice 0, la auto-referencia debe apuntar a 0.
      final snapshot = <Step>[
        _text('a', 0),
        _ct('b', 1, onMatch: 1, onElse: 0),
      ];

      final result = remapConditionalTargetsOnReorder(snapshot, <String>[
        'b',
        'a',
      ]);

      final md = ConditionalTimeMetadata.fromJsonString(result['b']!);
      expect(md.onMatchOrder, 0); // b ahora en índice 0
      expect(md.onElseOrder, 1); // a → índice 1
    });

    test(
      'un destino colgante (fuera de rango) se preserva; el otro remapea',
      () {
        // onMatch=9 no corresponde a ningún paso ⇒ se deja intacto. onElse=0
        // (a) sí remapea. El CT igual aparece porque onElse cambió.
        final snapshot = <Step>[
          _text('a', 0),
          _ct('b', 1, onMatch: 9, onElse: 0),
        ];

        final result = remapConditionalTargetsOnReorder(snapshot, <String>[
          'b',
          'a',
        ]);

        final md = ConditionalTimeMetadata.fromJsonString(result['b']!);
        expect(md.onMatchOrder, 9); // colgante: intacto
        expect(md.onElseOrder, 1); // a → índice 1
      },
    );

    test('metadata ilegible se omite (no remap, sin crash)', () {
      final snapshot = <Step>[
        _text('a', 0),
        _ct('b', 1, onMatch: 0, onElse: 0, rawMetadata: '{ no es json'),
      ];

      final result = remapConditionalTargetsOnReorder(snapshot, <String>[
        'b',
        'a',
      ]);

      expect(result.containsKey('b'), isFalse);
    });

    test('reorder que no toca los destinos del CT → sin entrada', () {
      // Mueve d y e (no son destinos del CT). El CT apunta a a/b, que
      // conservan su posición ⇒ no necesita PATCH de metadata.
      final snapshot = <Step>[
        _text('a', 0),
        _text('b', 1),
        _ct('c', 2, onMatch: 0, onElse: 1),
        _text('d', 3),
        _text('e', 4),
      ];

      final result = remapConditionalTargetsOnReorder(snapshot, <String>[
        'a',
        'b',
        'c',
        'e',
        'd',
      ]);

      expect(result.containsKey('c'), isFalse);
    });

    test('reorder identidad → mapa vacío', () {
      final snapshot = <Step>[
        _text('a', 0),
        _ct('b', 1, onMatch: 0, onElse: 2),
        _text('c', 2),
      ];

      final result = remapConditionalTargetsOnReorder(snapshot, <String>[
        'a',
        'b',
        'c',
      ]);

      expect(result, isEmpty);
    });
  });
}
