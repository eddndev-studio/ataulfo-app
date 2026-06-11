import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AIProvider.fromWire', () {
    test('"OPENAI" → openai', () {
      expect(AIProvider.fromWire('OPENAI'), AIProvider.openai);
    });

    test('"GEMINI" → gemini', () {
      expect(AIProvider.fromWire('GEMINI'), AIProvider.gemini);
    });

    test('"MINIMAX" → minimax', () {
      expect(AIProvider.fromWire('MINIMAX'), AIProvider.minimax);
    });

    test('"DEEPSEEK" → deepseek', () {
      expect(AIProvider.fromWire('DEEPSEEK'), AIProvider.deepseek);
    });

    test('valor desconocido lanza ArgumentError (fail-loud)', () {
      // Política espejo de BotChannel: si el backend agrega un proveedor
      // (p. ej. "ANTHROPIC") el cliente debe enterarse en boot y romper, no
      // degradar a un "unknown" cosmético que ocultaría drift de contrato.
      expect(() => AIProvider.fromWire('ANTHROPIC'), throwsArgumentError);
      expect(() => AIProvider.fromWire(''), throwsArgumentError);
    });
  });

  group('ThinkingLevel.fromWire', () {
    test('"LOW" → low', () {
      expect(ThinkingLevel.fromWire('LOW'), ThinkingLevel.low);
    });

    test('"MEDIUM" → medium', () {
      expect(ThinkingLevel.fromWire('MEDIUM'), ThinkingLevel.medium);
    });

    test('"HIGH" → high', () {
      expect(ThinkingLevel.fromWire('HIGH'), ThinkingLevel.high);
    });

    test('valor desconocido lanza ArgumentError (fail-loud)', () {
      expect(() => ThinkingLevel.fromWire('NONE'), throwsArgumentError);
      expect(() => ThinkingLevel.fromWire(''), throwsArgumentError);
    });
  });

  group('AIConfig', () {
    AIConfig make({
      bool enabled = false,
      AIProvider provider = AIProvider.gemini,
      String model = 'gemini-3.1-pro-preview',
      double temperature = 0.7,
      ThinkingLevel thinkingLevel = ThinkingLevel.low,
      String systemPrompt = '',
      int contextMessages = 20,
    }) => AIConfig(
      enabled: enabled,
      provider: provider,
      model: model,
      temperature: temperature,
      thinkingLevel: thinkingLevel,
      systemPrompt: systemPrompt,
      contextMessages: contextMessages,
    );

    test('expone los 7 campos del wire S03/S12', () {
      final c = make();
      expect(c.enabled, isFalse);
      expect(c.provider, AIProvider.gemini);
      expect(c.model, 'gemini-3.1-pro-preview');
      expect(c.temperature, 0.7);
      expect(c.thinkingLevel, ThinkingLevel.low);
      expect(c.systemPrompt, '');
      expect(c.contextMessages, 20);
    });

    test('dos AIConfig con misma data son iguales (value-type)', () {
      expect(make(), make());
      expect(make().hashCode, make().hashCode);
    });

    test('difieren si cambia cualquiera de los 7 campos', () {
      final base = make();
      expect(base, isNot(make(enabled: true)));
      expect(base, isNot(make(provider: AIProvider.openai)));
      expect(base, isNot(make(model: 'gpt-5')));
      expect(base, isNot(make(temperature: 1.0)));
      expect(base, isNot(make(thinkingLevel: ThinkingLevel.high)));
      expect(base, isNot(make(systemPrompt: 'eres un agente')));
      expect(base, isNot(make(contextMessages: 10)));
    });
  });

  group('Template', () {
    Template make({
      String id = 't1',
      String orgId = 'o1',
      String name = 'Soporte',
      int version = 1,
      AIConfig? ai,
    }) => Template(
      id: id,
      orgId: orgId,
      name: name,
      version: version,
      ai:
          ai ??
          const AIConfig(
            enabled: false,
            provider: AIProvider.gemini,
            model: 'gemini-3.1-pro-preview',
            temperature: 0.7,
            thinkingLevel: ThinkingLevel.low,
            systemPrompt: '',
            contextMessages: 20,
          ),
    );

    test('expone los campos del wire S03', () {
      final t = make();
      expect(t.id, 't1');
      expect(t.orgId, 'o1');
      expect(t.name, 'Soporte');
      expect(t.version, 1);
      expect(t.ai.provider, AIProvider.gemini);
    });

    test('dos Template con misma data son iguales (value-type)', () {
      expect(make(), make());
      expect(make().hashCode, make().hashCode);
    });

    test('difieren si cambia cualquiera de los 5 campos', () {
      final base = make();
      expect(base, isNot(make(id: 't2')));
      expect(base, isNot(make(orgId: 'o2')));
      expect(base, isNot(make(name: 'Ventas')));
      expect(base, isNot(make(version: 2)));
      expect(
        base,
        isNot(
          make(
            ai: const AIConfig(
              enabled: true,
              provider: AIProvider.openai,
              model: 'gpt-5',
              temperature: 1.0,
              thinkingLevel: ThinkingLevel.high,
              systemPrompt: 'x',
              contextMessages: 10,
            ),
          ),
        ),
      );
    });
  });

  group('AIConfig.copyWith', () {
    const base = AIConfig(
      enabled: true,
      provider: AIProvider.gemini,
      model: 'gemini-3.1-pro-preview',
      temperature: 0.7,
      thinkingLevel: ThinkingLevel.medium,
      systemPrompt: 'hola',
      contextMessages: 20,
    );

    test('sin args devuelve un value-equal', () {
      expect(base.copyWith(), base);
    });

    test('reemplaza solo el campo pedido y conserva el resto', () {
      final out = base.copyWith(temperature: 1.2);
      expect(out.temperature, 1.2);
      expect(out.model, base.model);
      expect(out.systemPrompt, base.systemPrompt);
      expect(out.enabled, base.enabled);

      final off = base.copyWith(enabled: false);
      expect(off.enabled, isFalse);
      expect(off.temperature, base.temperature);
    });
  });
}
