import 'package:ataulfo/features/media/domain/failures/media_failure.dart';
import 'package:flutter_test/flutter_test.dart';

// Función que el compilador obliga a ser exhaustiva sobre el sealed. Si se
// agrega una subclase nueva sin un brazo aquí, este archivo NO compila — es la
// garantía estructural que el bloc (#6) hereda.
String describe(MediaFailure f) => switch (f) {
  MediaNetworkFailure() => 'network',
  MediaTimeoutFailure() => 'timeout',
  MediaForbiddenFailure() => 'forbidden',
  MediaNotFoundFailure() => 'notFound',
  MediaTooLargeFailure() => 'tooLarge',
  MediaUnsupportedTypeFailure() => 'unsupportedType',
  MediaServerFailure() => 'server',
  UnknownMediaFailure() => 'unknown',
};

void main() {
  group('MediaFailure (sealed)', () {
    test('cada subclase es un Exception', () {
      expect(const MediaNetworkFailure(), isA<Exception>());
      expect(const MediaTooLargeFailure(), isA<MediaFailure>());
    });

    test('switch exhaustivo cubre todas las subclases', () {
      expect(describe(const MediaNetworkFailure()), 'network');
      expect(describe(const MediaTimeoutFailure()), 'timeout');
      expect(describe(const MediaForbiddenFailure()), 'forbidden');
      expect(describe(const MediaNotFoundFailure()), 'notFound');
      expect(describe(const MediaTooLargeFailure()), 'tooLarge');
      expect(describe(const MediaUnsupportedTypeFailure()), 'unsupportedType');
      expect(describe(const MediaServerFailure()), 'server');
      expect(describe(const UnknownMediaFailure()), 'unknown');
    });

    test(
      'const sin campos: dos instancias son idénticas (igualdad de estado)',
      () {
        expect(const MediaTooLargeFailure(), const MediaTooLargeFailure());
      },
    );
  });
}
