import 'package:ataulfo/features/product_catalog/domain/failures/composition_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RejectedFailure: igualdad por mensaje', () {
    expect(
      const CompositionRejectedFailure('x'),
      const CompositionRejectedFailure('x'),
    );
    expect(
      const CompositionRejectedFailure('x'),
      isNot(const CompositionRejectedFailure('y')),
    );
    expect(
      const CompositionRejectedFailure(),
      const CompositionRejectedFailure(),
    );
  });

  test('ConflictFailure: igualdad por mensaje', () {
    expect(
      const CompositionConflictFailure('x'),
      const CompositionConflictFailure('x'),
    );
    expect(
      const CompositionConflictFailure('x'),
      isNot(const CompositionConflictFailure('y')),
    );
    expect(
      const CompositionConflictFailure(),
      isNot(const CompositionRejectedFailure()),
    );
  });

  test('los failures son Exception atrapables', () {
    expect(const CompositionNetworkFailure(), isA<Exception>());
    expect(const CompositionTimeoutFailure(), isA<Exception>());
    expect(const CompositionNotFoundFailure(), isA<Exception>());
    expect(const CompositionServerFailure(), isA<Exception>());
    expect(const CompositionUnavailableFailure(), isA<Exception>());
    expect(const UnknownCompositionFailure(), isA<Exception>());
  });
}
