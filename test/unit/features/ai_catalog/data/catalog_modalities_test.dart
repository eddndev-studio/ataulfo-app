import 'package:ataulfo/features/ai_catalog/data/dto/catalog_dto.dart';
import 'package:ataulfo/features/ai_catalog/data/mappers/catalog_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('modalidades de entrada del catálogo', () {
    test('ModelDto parsea las flags de modalidad del wire', () {
      final dto = ModelDto.fromJson(<String, dynamic>{
        'id': 'gemini-3.1-pro-preview',
        'supportsTemperature': true,
        'supportsThinking': true,
        'supportsImageInput': true,
        'supportsAudioInput': true,
        'supportsDocumentInput': true,
      });
      expect(dto.supportsImageInput, isTrue);
      expect(dto.supportsAudioInput, isTrue);
      expect(dto.supportsDocumentInput, isTrue);
    });

    test('flags ausentes degradan a false (wire viejo, sin crash)', () {
      final dto = ModelDto.fromJson(<String, dynamic>{
        'id': 'MiniMax-M2.7',
        'supportsTemperature': true,
        'supportsThinking': false,
      });
      expect(dto.supportsImageInput, isFalse);
      expect(dto.supportsAudioInput, isFalse);
      expect(dto.supportsDocumentInput, isFalse);
    });

    test('el mapper proyecta las modalidades a la entidad', () {
      final resp = CatalogResp.fromJson(<String, dynamic>{
        'providers': <Map<String, dynamic>>[
          <String, dynamic>{
            'provider': 'GEMINI',
            'defaultModel': 'gemini-3.1-pro-preview',
            'models': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'gemini-3.1-pro-preview',
                'supportsTemperature': true,
                'supportsThinking': true,
                'supportsImageInput': true,
                'supportsAudioInput': true,
                'supportsDocumentInput': true,
              },
            ],
          },
        ],
      });
      final cat = CatalogMapper.respToEntity(resp);
      final m = cat.providers.single.models.single;
      expect(m.supportsImageInput, isTrue);
      expect(m.supportsAudioInput, isTrue);
      expect(m.supportsDocumentInput, isTrue);
    });
  });
}
