import 'package:ataulfo/features/wa_labels/domain/failures/wa_labels_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WaLabelsFailure', () {
    test('todas son WaLabelsFailure y Exception', () {
      const fs = <WaLabelsFailure>[
        WaLabelsNetworkFailure(),
        WaLabelsTimeoutFailure(),
        WaLabelsForbiddenFailure(),
        WaLabelsNotFoundFailure(),
        WaLabelsServerFailure(),
        WaLabelsUnknownFailure(),
        WaLabelsInvalidFailure(),
        WaLabelsNotConnectedFailure(),
        WaLabelsUpstreamFailure(),
      ];
      for (final f in fs) {
        expect(f, isA<Exception>());
      }
    });

    test('los tipos son distinguibles por el switch sellado', () {
      String label(WaLabelsFailure f) => switch (f) {
        WaLabelsNetworkFailure() => 'network',
        WaLabelsTimeoutFailure() => 'timeout',
        WaLabelsForbiddenFailure() => 'forbidden',
        WaLabelsNotFoundFailure() => 'notFound',
        WaLabelsServerFailure() => 'server',
        WaLabelsUnknownFailure() => 'unknown',
        WaLabelsInvalidFailure() => 'invalid',
        WaLabelsNotConnectedFailure() => 'notConnected',
        WaLabelsUpstreamFailure() => 'upstream',
      };
      expect(label(const WaLabelsNotConnectedFailure()), 'notConnected');
      expect(label(const WaLabelsUpstreamFailure()), 'upstream');
      expect(label(const WaLabelsInvalidFailure()), 'invalid');
    });
  });
}
