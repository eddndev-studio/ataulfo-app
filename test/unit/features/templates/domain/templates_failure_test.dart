import 'package:agentic/features/templates/domain/failures/templates_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TemplatesFailure (sealed)', () {
    test('todas las variantes son subtipos de TemplatesFailure y Exception', () {
      // Sellar la jerarquía obliga a que un switch del bloc cubra todos los
      // casos; un nuevo failure rompe el build en lugar de colarse silencioso.
      // El slice 1 no incluye NotFound porque `GET /templates` no devuelve
      // 404 (lista vacía es 200 con []); aterrizará con el detalle por id.
      const failures = <TemplatesFailure>[
        TemplatesNetworkFailure(),
        TemplatesTimeoutFailure(),
        TemplatesForbiddenFailure(),
        TemplatesServerFailure(),
        UnknownTemplatesFailure(),
      ];

      for (final f in failures) {
        expect(f, isA<TemplatesFailure>());
        expect(f, isA<Exception>());
      }
    });
  });
}
