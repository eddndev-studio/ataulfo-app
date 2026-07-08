import 'package:ataulfo/features/billing/domain/failures/billing_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BillingFailure (sealed)', () {
    test('todas las variantes son subtipos de BillingFailure y Exception', () {
      // Sellar la jerarquía obliga al switch del bloc a cubrir todos los
      // casos: un failure nuevo rompe el build, no se cuela silencioso.
      // GET /workspace/billing emite 409 (sin org activa en las claims) y
      // 404 (org sin suscripción) además del perfil read-only estándar.
      const failures = <BillingFailure>[
        BillingNetworkFailure(),
        BillingTimeoutFailure(),
        BillingOrgUnresolvedFailure(),
        BillingNotFoundFailure(),
        BillingServerFailure(),
        UnknownBillingFailure(),
      ];

      for (final f in failures) {
        expect(f, isA<BillingFailure>());
        expect(f, isA<Exception>());
      }
    });

    test('cada variante es su propio tipo (no se cruzan en isA)', () {
      // La UI distingue copy por variante ("sin conexión" vs "demoró") y el
      // 409 tiene semántica propia (resolver org y reintentar): un mapeo
      // cruzado pasaría tests laxos y rompería ese contrato.
      const network = BillingNetworkFailure();
      const timeout = BillingTimeoutFailure();
      const unresolved = BillingOrgUnresolvedFailure();
      const notFound = BillingNotFoundFailure();
      const server = BillingServerFailure();
      const unknown = UnknownBillingFailure();

      expect(network, isNot(isA<BillingTimeoutFailure>()));
      expect(timeout, isNot(isA<BillingNetworkFailure>()));
      expect(unresolved, isNot(isA<BillingNotFoundFailure>()));
      expect(notFound, isNot(isA<BillingOrgUnresolvedFailure>()));
      expect(server, isNot(isA<UnknownBillingFailure>()));
      expect(unknown, isNot(isA<BillingServerFailure>()));
    });
  });
}
