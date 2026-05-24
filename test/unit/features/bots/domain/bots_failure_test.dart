import 'package:agentic/features/bots/domain/failures/bots_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BotsFailure (sealed)', () {
    test('todas las variantes son subtipos de BotsFailure y de Exception', () {
      // Sellar la jerarquía obliga a que un switch del bloc cubra todos los
      // casos; un nuevo failure rompe el build en lugar de colarse silencioso.
      const failures = <BotsFailure>[
        BotsNetworkFailure(),
        BotsTimeoutFailure(),
        BotsForbiddenFailure(),
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
