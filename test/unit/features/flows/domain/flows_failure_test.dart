import 'package:ataulfo/features/flows/domain/failures/flows_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlowsFailure', () {
    test('cada subtype es una FlowsFailure y un Exception', () {
      const List<FlowsFailure> all = <FlowsFailure>[
        FlowsNetworkFailure(),
        FlowsTimeoutFailure(),
        FlowsForbiddenFailure(),
        FlowsNotFoundFailure(),
        FlowsServerFailure(),
        UnknownFlowsFailure(),
        FlowsInvalidCreateFailure(),
        FlowsInvalidStepFailure(),
        FlowsStepNotFoundFailure(),
        FlowsInvalidSettingsFailure(),
        FlowsConflictFailure(),
        FlowsInvalidReorderFailure(),
        FlowsStepReferencedFailure(),
      ];
      for (final f in all) {
        expect(f, isA<FlowsFailure>());
        expect(f, isA<Exception>());
      }
    });

    test('switch exhaustivo sobre la jerarquía sellada compila', () {
      String label(FlowsFailure f) => switch (f) {
        FlowsNetworkFailure() => 'net',
        FlowsTimeoutFailure() => 'timeout',
        FlowsForbiddenFailure() => 'forbidden',
        FlowsNotFoundFailure() => 'notfound',
        FlowsServerFailure() => 'server',
        UnknownFlowsFailure() => 'unknown',
        FlowsInvalidCreateFailure() => 'invalid_create',
        FlowsInvalidStepFailure() => 'invalid_step',
        FlowsStepNotFoundFailure() => 'step_notfound',
        FlowsInvalidSettingsFailure() => 'invalid_settings',
        FlowsConflictFailure() => 'conflict',
        FlowsInvalidReorderFailure() => 'invalid_reorder',
        FlowsStepReferencedFailure() => 'step_referenced',
      };
      expect(label(const FlowsInvalidSettingsFailure()), 'invalid_settings');
      expect(label(const FlowsConflictFailure()), 'conflict');
      expect(label(const FlowsNetworkFailure()), 'net');
      expect(label(const FlowsNotFoundFailure()), 'notfound');
    });

    test('const-canonical: dos instancias del mismo subtype son idénticas', () {
      expect(
        identical(const FlowsConflictFailure(), const FlowsConflictFailure()),
        isTrue,
      );
      expect(
        identical(
          const FlowsInvalidSettingsFailure(),
          const FlowsInvalidSettingsFailure(),
        ),
        isTrue,
      );
    });
  });
}
