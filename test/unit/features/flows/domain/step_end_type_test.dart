import 'package:ataulfo/features/flows/domain/entities/step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StepType END', () {
    test('fromWire reconoce END', () {
      expect(StepType.fromWire('END'), StepType.end);
    });

    test('toWire serializa END', () {
      expect(StepType.end.toWire(), 'END');
    });
  });
}
