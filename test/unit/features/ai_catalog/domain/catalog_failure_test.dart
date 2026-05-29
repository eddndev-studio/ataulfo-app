import 'package:ataulfo/features/ai_catalog/domain/failures/catalog_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogFailure (sealed)', () {
    test('todas las variantes son subtipos de CatalogFailure y Exception', () {
      // Sellar la jerarquía obliga al switch del bloc a cubrir todos los
      // casos: un failure nuevo rompe el build, no se cuela silencioso.
      // El endpoint /ai/catalog no emite 404 (la tabla siempre existe)
      // ni 422 (read-only, no acepta body). Solo cinco casos terminales
      // — los mismos que memberships, mismo perfil de read-only auth+RBAC.
      const failures = <CatalogFailure>[
        CatalogNetworkFailure(),
        CatalogTimeoutFailure(),
        CatalogForbiddenFailure(),
        CatalogServerFailure(),
        UnknownCatalogFailure(),
      ];

      for (final f in failures) {
        expect(f, isA<CatalogFailure>());
        expect(f, isA<Exception>());
      }
    });

    test('cada variante es su propio tipo (no se cruzan en isA)', () {
      // Endurece la separación de cubos: un bug que mapeara Timeout a
      // Network (o viceversa) pasaría tests laxos. La UI puede distinguir
      // copy "sin conexión" vs "demoró demasiado" — el contrato del bloc
      // depende de que los tipos no se confundan.
      const network = CatalogNetworkFailure();
      const timeout = CatalogTimeoutFailure();
      const forbidden = CatalogForbiddenFailure();
      const server = CatalogServerFailure();
      const unknown = UnknownCatalogFailure();

      expect(network, isNot(isA<CatalogTimeoutFailure>()));
      expect(timeout, isNot(isA<CatalogNetworkFailure>()));
      expect(forbidden, isNot(isA<CatalogServerFailure>()));
      expect(server, isNot(isA<CatalogForbiddenFailure>()));
      expect(unknown, isNot(isA<CatalogServerFailure>()));
    });
  });
}
