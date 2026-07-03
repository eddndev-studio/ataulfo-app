import 'package:ataulfo/features/templates/data/dto/template_dto.dart';
import 'package:ataulfo/features/templates/data/mappers/templates_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> baseAi() => <String, dynamic>{
    'enabled': true,
    'provider': 'GEMINI',
    'model': 'gemini-3.1-pro-preview',
    'temperature': 0.7,
    'thinking_level': 'LOW',
    'system_prompt': '',
    'context_messages': 20,
  };

  test('claves de seguimiento presentes se parsean y viajan al wire', () {
    final j = baseAi()
      ..['follow_up_enabled'] = true
      ..['follow_up_delay_minutes'] = 1440
      ..['follow_up_max_attempts'] = 2;
    final dto = AiConfigDto.fromJson(j);
    expect(dto.followUpEnabled, isTrue);
    expect(dto.followUpDelayMinutes, 1440);
    expect(dto.followUpMaxAttempts, 2);

    final entity = TemplatesMapper.aiConfigDtoToEntity(dto);
    final wire = TemplatesMapper.aiConfigToWire(entity);
    expect(wire['follow_up_enabled'], isTrue);
    expect(wire['follow_up_delay_minutes'], 1440);
    expect(wire['follow_up_max_attempts'], 2);
  });

  test('ausentes (backend previo) degradan a apagado con ceros', () {
    final dto = AiConfigDto.fromJson(baseAi());
    expect(dto.followUpEnabled, isFalse);
    expect(dto.followUpDelayMinutes, 0);
    expect(dto.followUpMaxAttempts, 0);
  });
}
