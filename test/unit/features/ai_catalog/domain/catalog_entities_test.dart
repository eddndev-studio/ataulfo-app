import 'package:ataulfo/features/ai_catalog/domain/entities/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AIModel', () {
    test(
      'value equality compara id + supportsTemperature + supportsThinking',
      () {
        // Las flags `supportsTemperature` y `supportsThinking` cambian la UI
        // del editor de AIConfig (TE3): ocultar el slider de temperature en
        // GPT-5, ocultar el dropdown de thinking en MiniMax/DeepSeek. Un bug
        // que comparara solo `id` haría que dos catálogos con flags distintas
        // se vieran "iguales" y la UI no se rerenderizara.
        const a = AIModel(
          id: 'gemini-3.1-pro-preview',
          supportsTemperature: true,
          supportsThinking: true,
        );
        const b = AIModel(
          id: 'gemini-3.1-pro-preview',
          supportsTemperature: true,
          supportsThinking: true,
        );
        const c = AIModel(
          id: 'gemini-3.1-pro-preview',
          supportsTemperature: false,
          supportsThinking: true,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
        expect(a, isNot(equals(c)));
      },
    );
  });

  group('ProviderEntry', () {
    test(
      'value equality compara provider + defaultModel + lista de models',
      () {
        // Dos providers con misma identidad pero models distintos NO son
        // iguales — el catálogo cambia release a release y los listados
        // tienen que distinguirse para que el bloc emita un nuevo Loaded.
        const m1 = AIModel(
          id: 'gemini-3.1-pro-preview',
          supportsTemperature: true,
          supportsThinking: true,
        );
        const m2 = AIModel(
          id: 'gemini-3.5-flash',
          supportsTemperature: true,
          supportsThinking: true,
        );

        const a = ProviderEntry(
          provider: 'GEMINI',
          defaultModel: 'gemini-3.1-pro-preview',
          models: [m1, m2],
        );
        const b = ProviderEntry(
          provider: 'GEMINI',
          defaultModel: 'gemini-3.1-pro-preview',
          models: [m1, m2],
        );
        const c = ProviderEntry(
          provider: 'GEMINI',
          defaultModel: 'gemini-3.1-pro-preview',
          models: [m1],
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
        expect(a, isNot(equals(c)));
      },
    );

    test(
      'provider es String crudo (no enum) — el backend es la fuente canónica',
      () {
        // El catálogo del backend puede ganar un proveedor nuevo entre
        // releases del cliente. Si el dominio cerrara `provider` a un enum,
        // ese caso rompería el `fromJson` por una entrada perfectamente
        // legítima del backend. El editor de AIConfig (TE3) decide qué
        // hacer con un provider que no reconoce.
        const entry = ProviderEntry(
          provider: 'PROVIDER_FUTURO_QUE_NO_EXISTE_HOY',
          defaultModel: 'modelo-x',
          models: [],
        );
        expect(entry.provider, isA<String>());
      },
    );
  });

  group('Catalog', () {
    test('value equality compara la lista de providers', () {
      const gemini = ProviderEntry(
        provider: 'GEMINI',
        defaultModel: 'gemini-3.1-pro-preview',
        models: [
          AIModel(
            id: 'gemini-3.1-pro-preview',
            supportsTemperature: true,
            supportsThinking: true,
          ),
        ],
      );
      const openai = ProviderEntry(
        provider: 'OPENAI',
        defaultModel: 'gpt-5.5',
        models: [
          AIModel(
            id: 'gpt-5.5',
            supportsTemperature: false,
            supportsThinking: true,
          ),
        ],
      );

      const a = Catalog(providers: [gemini, openai]);
      const b = Catalog(providers: [gemini, openai]);
      const c = Catalog(providers: [gemini]);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('orden de providers importa para igualdad', () {
      // El orden del wire es significativo: el backend lo elige por
      // prioridad de release. El cliente no reordena, y dos listas con
      // los mismos elementos en distinto orden NO son iguales — un
      // re-orden cambia la UX (qué proveedor sale primero en el picker).
      const a = ProviderEntry(
        provider: 'GEMINI',
        defaultModel: 'gemini-3.1-pro-preview',
        models: [],
      );
      const b = ProviderEntry(
        provider: 'OPENAI',
        defaultModel: 'gpt-5.5',
        models: [],
      );

      const ab = Catalog(providers: [a, b]);
      const ba = Catalog(providers: [b, a]);

      expect(ab, isNot(equals(ba)));
    });
  });
}
