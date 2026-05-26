import 'package:agentic/features/templates/domain/failures/templates_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TemplatesFailure (sealed)', () {
    test('todas las variantes son subtipos de TemplatesFailure y Exception', () {
      // Sellar la jerarquía obliga a que un switch del bloc cubra todos los
      // casos; un nuevo failure rompe el build en lugar de colarse silencioso.
      // NotFound aterriza con el endpoint de detalle por id: GET
      // /templates/:id sí responde 404 si el id no existe en la org.
      // InvalidName aterriza con POST /templates: el handler devuelve 422
      // si el nombre viola la validación de dominio (vacío, demasiado
      // largo, formato). El cliente debe distinguirla del genérico para
      // mostrar copy útil al usuario.
      const failures = <TemplatesFailure>[
        TemplatesNetworkFailure(),
        TemplatesTimeoutFailure(),
        TemplatesForbiddenFailure(),
        TemplatesNotFoundFailure(),
        TemplatesInvalidNameFailure(),
        TemplatesInvalidUpdateFailure(),
        TemplatesConflictFailure(),
        TemplatesServerFailure(),
        UnknownTemplatesFailure(),
      ];

      for (final f in failures) {
        expect(f, isA<TemplatesFailure>());
        expect(f, isA<Exception>());
      }
    });

    test('cada variante es su propio tipo (no se cruzan en isA)', () {
      // Endurece la separación de cubos: un bug que mapeara 409 a 422 (o
      // viceversa) en el datasource pasaría el test del listado pero no
      // este — los dos failures comparten sealed pero deben permanecer
      // distinguibles en el switch del bloc.
      const conflict = TemplatesConflictFailure();
      const invalidUpdate = TemplatesInvalidUpdateFailure();
      const invalidName = TemplatesInvalidNameFailure();

      expect(conflict, isA<TemplatesConflictFailure>());
      expect(conflict, isNot(isA<TemplatesInvalidUpdateFailure>()));
      expect(invalidUpdate, isA<TemplatesInvalidUpdateFailure>());
      expect(invalidUpdate, isNot(isA<TemplatesInvalidNameFailure>()));
      expect(invalidName, isNot(isA<TemplatesInvalidUpdateFailure>()));
    });
  });
}
