import 'package:ataulfo/features/invitations/domain/failures/invitations_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InvitationsFailure', () {
    test('todas las variantes derivan de InvitationsFailure (sellada)', () {
      const failures = <InvitationsFailure>[
        InvitationsNetworkFailure(),
        InvitationsTimeoutFailure(),
        InvitationsForbiddenFailure(),
        InvitationsDuplicateFailure(),
        InvitationsValidationFailure(),
        InvitationsNotFoundFailure(),
        InvitationsGoneFailure(),
        InvitationsServerFailure(),
        UnknownInvitationsFailure(),
      ];

      for (final f in failures) {
        expect(f, isA<InvitationsFailure>());
        expect(f, isA<Exception>());
      }
    });

    test('cada variante es de su propio tipo (no se cruzan)', () {
      expect(
        const InvitationsDuplicateFailure(),
        isNot(isA<InvitationsValidationFailure>()),
      );
      expect(
        const InvitationsGoneFailure(),
        isNot(isA<InvitationsNotFoundFailure>()),
      );
    });
  });
}
