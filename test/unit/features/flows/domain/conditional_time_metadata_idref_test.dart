import 'package:ataulfo/features/flows/domain/entities/conditional_time_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

const _win = '"windows":[{"days":[1,2],"from":"09:00","to":"18:00"}]';

void main() {
  group('ConditionalTimeMetadata id-form', () {
    test('parsea el shape canónico por id (con orders sintetizados)', () {
      final md = ConditionalTimeMetadata.fromJsonString(
        '{"tz":"UTC",$_win,'
        '"on_match_step_id":"s-b","on_else_step_id":"s-c",'
        '"on_match_order":1,"on_else_order":2}',
      );
      expect(md.hasStepIdRefs, isTrue);
      expect(md.onMatchStepId, 's-b');
      expect(md.onElseStepId, 's-c');
      // Los orders sintetizados por el backend se conservan para display.
      expect(md.onMatchOrder, 1);
      expect(md.onElseOrder, 2);
    });

    test('parsea id-form sin claves posicionales', () {
      final md = ConditionalTimeMetadata.fromJsonString(
        '{"tz":"UTC",$_win,'
        '"on_match_step_id":"s-b","on_else_step_id":"s-c"}',
      );
      expect(md.hasStepIdRefs, isTrue);
      expect(md.onMatchOrder, isNull);
      expect(md.onElseOrder, isNull);
    });

    test('un solo id presente es shape a medias: FormatException', () {
      expect(
        () => ConditionalTimeMetadata.fromJsonString(
          '{"tz":"UTC",$_win,"on_match_step_id":"s-b"}',
        ),
        throwsFormatException,
      );
    });

    test('shape legacy posicional sigue parseando (filas no migradas)', () {
      final md = ConditionalTimeMetadata.fromJsonString(
        '{"tz":"UTC",$_win,"on_match_order":3,"on_else_order":5}',
      );
      expect(md.hasStepIdRefs, isFalse);
      expect(md.onMatchOrder, 3);
      expect(md.onElseOrder, 5);
    });

    test('sin ids ni orders completos: FormatException', () {
      expect(
        () => ConditionalTimeMetadata.fromJsonString(
          '{"tz":"UTC",$_win,"on_match_order":3}',
        ),
        throwsFormatException,
      );
    });

    test('toJsonString con ids emite id-form puro (sin orders)', () {
      const md = ConditionalTimeMetadata(
        tz: 'UTC',
        windows: <TimeWindow>[
          TimeWindow(days: <int>[1], from: '09:00', to: '18:00'),
        ],
        onMatchStepId: 's-b',
        onElseStepId: 's-c',
        onMatchOrder: 1,
        onElseOrder: 2,
      );
      final encoded = md.toJsonString();
      expect(encoded, contains('"on_match_step_id":"s-b"'));
      expect(encoded, contains('"on_else_step_id":"s-c"'));
      // Los orders son carga muerta para el backend nuevo: no viajan.
      expect(encoded, isNot(contains('on_match_order')));
      expect(encoded, isNot(contains('on_else_order')));
    });

    test('toJsonString legacy (sin ids) conserva el shape posicional', () {
      const md = ConditionalTimeMetadata(
        tz: 'UTC',
        windows: <TimeWindow>[
          TimeWindow(days: <int>[1], from: '09:00', to: '18:00'),
        ],
        onMatchOrder: 3,
        onElseOrder: 5,
      );
      final encoded = md.toJsonString();
      expect(encoded, contains('"on_match_order":3'));
      expect(encoded, isNot(contains('on_match_step_id')));
    });
  });
}
