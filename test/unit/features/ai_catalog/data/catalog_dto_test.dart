import 'package:ataulfo/features/ai_catalog/data/dto/catalog_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelDto.fromJson', () {
    test('parsea claves canónicas del wire', () {
      // Las claves del wire ya son camelCase: el adaptador Go encoda
      // `id`, `supportsTemperature`, `supportsThinking` directo.
      final dto = ModelDto.fromJson(<String, dynamic>{
        'id': 'gemini-3.1-pro-preview',
        'supportsTemperature': true,
        'supportsThinking': true,
      });

      expect(dto.id, 'gemini-3.1-pro-preview');
      expect(dto.supportsTemperature, isTrue);
      expect(dto.supportsThinking, isTrue);
    });

    test('FormatException si falta una clave obligatoria', () {
      // Fail-loud: el contrato del wire es estricto. Un wire sin
      // `supportsTemperature` (p.ej. backend pre-flag) es un bug, no un
      // default — la UI no debe asumir `false` silenciosamente.
      expect(
        () => ModelDto.fromJson(<String, dynamic>{
          'id': 'gemini-3.1-pro-preview',
          'supportsThinking': true,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('FormatException si el tipo no coincide', () {
      // Un flag que viaje como int (1/0) sería contrato roto. JSON los
      // expone como bool nativo; cualquier otro tipo es bug del wire.
      expect(
        () => ModelDto.fromJson(<String, dynamic>{
          'id': 'gemini-3.1-pro-preview',
          'supportsTemperature': 1,
          'supportsThinking': true,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('parsea hosts seleccionables (lista de strings)', () {
      final dto = ModelDto.fromJson(<String, dynamic>{
        'id': 'MiniMax-M3',
        'supportsTemperature': true,
        'supportsThinking': true,
        'hosts': <dynamic>['MINIMAX', 'FIREWORKS'],
      });
      expect(dto.hosts, <String>['MINIMAX', 'FIREWORKS']);
    });

    test('hosts ausente ⇒ lista vacía (wire viejo degrada sin crash)', () {
      // TOLERANTE como las modalidades: un backend que aún no expone hosts no
      // debe romper el catálogo. Vacío ⇒ el editor no ofrece selección de host.
      final dto = ModelDto.fromJson(<String, dynamic>{
        'id': 'gemini-3.1-pro-preview',
        'supportsTemperature': true,
        'supportsThinking': true,
      });
      expect(dto.hosts, isEmpty);
    });
  });

  group('ProviderEntryDto.fromJson', () {
    test('parsea provider + defaultModel + lista de models', () {
      final dto = ProviderEntryDto.fromJson(<String, dynamic>{
        'provider': 'GEMINI',
        'defaultModel': 'gemini-3.1-pro-preview',
        'models': <dynamic>[
          <String, dynamic>{
            'id': 'gemini-3.1-pro-preview',
            'supportsTemperature': true,
            'supportsThinking': true,
          },
        ],
      });

      expect(dto.provider, 'GEMINI');
      expect(dto.defaultModel, 'gemini-3.1-pro-preview');
      expect(dto.models.length, 1);
      expect(dto.models.first.id, 'gemini-3.1-pro-preview');
    });

    test('lista vacía de models es legítima (provider sin modelos hoy)', () {
      // Hipotético: backend en transición publica un provider antes de
      // poblar models. El cliente debe parsearlo sin romper — el editor
      // (TE3) decide si lo oculta o muestra inerte.
      final dto = ProviderEntryDto.fromJson(<String, dynamic>{
        'provider': 'GEMINI',
        'defaultModel': '',
        'models': <dynamic>[],
      });
      expect(dto.models, isEmpty);
    });

    test('FormatException si falta provider o defaultModel', () {
      expect(
        () => ProviderEntryDto.fromJson(<String, dynamic>{
          'defaultModel': 'gemini-3.1-pro-preview',
          'models': <dynamic>[],
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ProviderEntryDto.fromJson(<String, dynamic>{
          'provider': 'GEMINI',
          'models': <dynamic>[],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('FormatException si models no es lista', () {
      expect(
        () => ProviderEntryDto.fromJson(<String, dynamic>{
          'provider': 'GEMINI',
          'defaultModel': 'gemini-3.1-pro-preview',
          'models': 'not-a-list',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('CatalogResp.fromJson', () {
    test('parsea el wire canónico de GET /ai/catalog', () {
      final dto = CatalogResp.fromJson(<String, dynamic>{
        'providers': <dynamic>[
          <String, dynamic>{
            'provider': 'GEMINI',
            'defaultModel': 'gemini-3.1-pro-preview',
            'models': <dynamic>[
              <String, dynamic>{
                'id': 'gemini-3.1-pro-preview',
                'supportsTemperature': true,
                'supportsThinking': true,
              },
            ],
          },
          <String, dynamic>{
            'provider': 'OPENAI',
            'defaultModel': 'gpt-5.5',
            'models': <dynamic>[
              <String, dynamic>{
                'id': 'gpt-5.5',
                'supportsTemperature': false,
                'supportsThinking': true,
              },
            ],
          },
        ],
      });

      expect(dto.providers.length, 2);
      expect(dto.providers[0].provider, 'GEMINI');
      expect(dto.providers[1].provider, 'OPENAI');
      expect(dto.providers[1].models.first.supportsTemperature, isFalse);
    });

    test('FormatException si falta la clave providers', () {
      expect(
        () => CatalogResp.fromJson(<String, dynamic>{}),
        throwsA(isA<FormatException>()),
      );
    });

    test('providers: [] es respuesta legítima', () {
      // Hipotético defensivo: backend con tabla vacía. El cliente no debe
      // romper — el editor mostraría un estado terminal de "catálogo
      // vacío" (no esperado en producción, pero el contrato lo permite).
      final dto = CatalogResp.fromJson(<String, dynamic>{
        'providers': <dynamic>[],
      });
      expect(dto.providers, isEmpty);
    });
  });
}
