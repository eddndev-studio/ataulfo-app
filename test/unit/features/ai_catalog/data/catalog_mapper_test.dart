import 'package:agentic/features/ai_catalog/data/dto/catalog_dto.dart';
import 'package:agentic/features/ai_catalog/data/mappers/catalog_mapper.dart';
import 'package:agentic/features/ai_catalog/domain/entities/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogMapper.respToEntity', () {
    test('CatalogResp anidado → Catalog preservando estructura completa', () {
      // El mapper desciende por tres niveles (Catalog → ProviderEntry →
      // AIModel). Tests por capa: el datasource ya cubre la integración,
      // pero un test directo aísla regresiones del mapeo si en el futuro
      // el wire del backend gana campos (p.ej. costo por token, fecha de
      // retiro) y el mapper se actualiza.
      const resp = CatalogResp(
        providers: [
          ProviderEntryDto(
            provider: 'GEMINI',
            defaultModel: 'gemini-3.1-pro-preview',
            models: [
              ModelDto(
                id: 'gemini-3.1-pro-preview',
                supportsTemperature: true,
                supportsThinking: true,
              ),
              ModelDto(
                id: 'gemini-3.5-flash',
                supportsTemperature: true,
                supportsThinking: true,
              ),
            ],
          ),
          ProviderEntryDto(
            provider: 'OPENAI',
            defaultModel: 'gpt-5.5',
            models: [
              ModelDto(
                id: 'gpt-5.5',
                supportsTemperature: false,
                supportsThinking: true,
              ),
            ],
          ),
        ],
      );

      final got = CatalogMapper.respToEntity(resp);

      expect(
        got,
        const Catalog(
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
        ),
      );
    });

    test('Catalog con providers vacíos se mapea sin romper', () {
      const resp = CatalogResp(providers: []);
      final got = CatalogMapper.respToEntity(resp);
      expect(got, const Catalog(providers: []));
    });

    test('ProviderEntry con models vacíos se mapea sin romper', () {
      const resp = CatalogResp(
        providers: [
          ProviderEntryDto(provider: 'OPENAI', defaultModel: '', models: []),
        ],
      );
      final got = CatalogMapper.respToEntity(resp);
      expect(
        got,
        const Catalog(
          providers: [
            ProviderEntry(provider: 'OPENAI', defaultModel: '', models: []),
          ],
        ),
      );
    });
  });
}
