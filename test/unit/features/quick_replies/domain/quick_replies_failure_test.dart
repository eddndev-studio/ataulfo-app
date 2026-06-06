import 'package:ataulfo/features/quick_replies/domain/failures/quick_replies_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('las failures son Exception (no Error) y de la jerarquía sellada', () {
    const failures = <QuickRepliesFailure>[
      QuickRepliesNetworkFailure(),
      QuickRepliesTimeoutFailure(),
      QuickRepliesForbiddenFailure(),
      QuickRepliesNotFoundFailure(),
      QuickRepliesServerFailure(),
      QuickRepliesUnknownFailure(),
    ];
    for (final f in failures) {
      expect(f, isA<Exception>());
      expect(f, isA<QuickRepliesFailure>());
    }
  });
}
