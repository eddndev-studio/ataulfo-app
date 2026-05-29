import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BotsFailure (sealed)', () {
    test('todas las variantes son subtipos de BotsFailure y de Exception', () {
      // Sellar la jerarquía obliga a que un switch del bloc cubra todos los
      // casos; un nuevo failure rompe el build en lugar de colarse silencioso.
      // InvalidCreate aterriza con POST /bots: el handler devuelve 422 cuando
      // el dominio rechaza la construcción del bot (name vacío, channel
      // desconocido, template_id ajeno/inexistente, variables fuera del set).
      // Un solo cubo bajo "Revisa los datos del bot" — el operador no puede
      // accionar distinto entre las variantes de 422 sin instrumentación del
      // backend.
      const failures = <BotsFailure>[
        BotsNetworkFailure(),
        BotsTimeoutFailure(),
        BotsForbiddenFailure(),
        BotsInvalidCreateFailure(),
        BotsServerFailure(),
        UnknownBotsFailure(),
      ];

      for (final f in failures) {
        expect(f, isA<BotsFailure>());
        expect(f, isA<Exception>());
      }
    });
  });
}
