import 'package:ataulfo/features/ai_catalog/domain/catalog_drift.dart';
import 'package:ataulfo/features/ai_catalog/domain/entities/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = Catalog(
  providers: [
    ProviderEntry(
      provider: 'GEMINI',
      defaultModel: 'gemini-3.1-pro-preview',
      models: [
        AIModel(
          id: 'gemini-3.1-pro-preview',
          supportsTemperature: true,
          supportsThinking: true,
        ),
        AIModel(
          id: 'gemini-3.5-flash',
          supportsTemperature: true,
          supportsThinking: true,
        ),
      ],
    ),
    ProviderEntry(
      provider: 'OPENAI',
      defaultModel: 'gpt-5.5',
      models: [
        AIModel(
          id: 'gpt-5.5',
          supportsTemperature: false,
          supportsThinking: true,
        ),
      ],
    ),
  ],
);

void main() {
  group('catalogProvider(catalog, providerWire)', () {
    test('devuelve el ProviderEntry si el wire matchea uno del catálogo', () {
      final entry = catalogProvider(_catalog, 'GEMINI');
      expect(entry, isNotNull);
      expect(entry!.provider, 'GEMINI');
      expect(entry.defaultModel, 'gemini-3.1-pro-preview');
    });

    test(
      'devuelve null si el provider del template no está en el catálogo',
      () {
        // Caso real de drift: el cliente todavía conoce MINIMAX en el enum
        // AIProvider, pero el backend retiró MINIMAX del catálogo (la enum
        // del wire es fail-loud para nuevas altas; las bajas del catálogo
        // sí pueden divergir hasta que el cliente se actualice).
        expect(catalogProvider(_catalog, 'MINIMAX'), isNull);
      },
    );
  });

  group('catalogModel(catalog, providerWire, modelId)', () {
    test('devuelve el AIModel si provider+model existen en el catálogo', () {
      final model = catalogModel(_catalog, 'GEMINI', 'gemini-3.5-flash');
      expect(model, isNotNull);
      expect(model!.id, 'gemini-3.5-flash');
      expect(model.supportsTemperature, isTrue);
    });

    test('devuelve null si el provider no está', () {
      expect(catalogModel(_catalog, 'MINIMAX', 'cualquiera'), isNull);
    });

    test('devuelve null si el provider está pero el modelo no', () {
      // Drift puro: el provider existe pero el modelo fue retirado entre
      // releases. El form debe marcar el modelo como 'Retirado' y forzar
      // re-elección antes de permitir submit.
      expect(
        catalogModel(_catalog, 'GEMINI', 'gemini-2.0-pro-retirado'),
        isNull,
      );
    });
  });
}
