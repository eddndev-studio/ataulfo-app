import 'package:agentic/features/triggers/domain/failures/triggers_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TriggersFailure', () {
    test('cada subtype es una TriggersFailure y un Exception', () {
      const List<TriggersFailure> all = <TriggersFailure>[
        TriggersNetworkFailure(),
        TriggersTimeoutFailure(),
        TriggersForbiddenFailure(),
        TriggersNotFoundFailure(),
        TriggersServerFailure(),
        UnknownTriggersFailure(),
        TriggersInvalidFailure(),
      ];
      for (final f in all) {
        expect(f, isA<TriggersFailure>());
        expect(f, isA<Exception>());
      }
    });

    test('switch exhaustivo sobre la jerarquía sellada compila', () {
      String label(TriggersFailure f) => switch (f) {
        TriggersNetworkFailure() => 'net',
        TriggersTimeoutFailure() => 'timeout',
        TriggersForbiddenFailure() => 'forbidden',
        TriggersNotFoundFailure() => 'notfound',
        TriggersServerFailure() => 'server',
        UnknownTriggersFailure() => 'unknown',
        TriggersInvalidFailure() => 'invalid',
      };
      expect(label(const TriggersInvalidFailure()), 'invalid');
      expect(label(const TriggersNetworkFailure()), 'net');
      expect(label(const TriggersNotFoundFailure()), 'notfound');
      expect(label(const UnknownTriggersFailure()), 'unknown');
    });

    test('const-canonical: dos instancias del mismo subtype son idénticas', () {
      expect(
        identical(
          const TriggersNetworkFailure(),
          const TriggersNetworkFailure(),
        ),
        isTrue,
      );
    });
  });
}
