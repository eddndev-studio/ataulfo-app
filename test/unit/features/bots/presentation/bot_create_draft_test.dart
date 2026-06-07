import 'package:ataulfo/features/bots/presentation/bot_create_draft.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:flutter_test/flutter_test.dart';

const _ai = AIConfig(
  enabled: false,
  provider: AIProvider.gemini,
  model: 'gemini-3.1-pro-preview',
  temperature: 0.7,
  thinkingLevel: ThinkingLevel.low,
  systemPrompt: '',
  contextMessages: 20,
);

const _t1 = Template(
  id: 't1',
  orgId: 'o1',
  name: 'Soporte',
  version: 1,
  ai: _ai,
);

void main() {
  group('BotCreateDraft', () {
    test('isEmpty cuando no hay plantilla ni texto', () {
      const draft = BotCreateDraft();
      expect(draft.isEmpty, isTrue);
    });

    test('no isEmpty si hay plantilla seleccionada', () {
      const draft = BotCreateDraft(template: _t1);
      expect(draft.isEmpty, isFalse);
    });

    test('no isEmpty si hay nombre o identificador', () {
      expect(const BotCreateDraft(name: 'x').isEmpty, isFalse);
      expect(const BotCreateDraft(identifier: '55').isEmpty, isFalse);
    });

    test('igualdad por valor (template + name + identifier)', () {
      expect(
        const BotCreateDraft(template: _t1, name: 'Bot', identifier: '55'),
        const BotCreateDraft(template: _t1, name: 'Bot', identifier: '55'),
      );
      expect(
        const BotCreateDraft(template: _t1, name: 'Bot'),
        isNot(const BotCreateDraft(template: _t1, name: 'Otro')),
      );
    });
  });

  group('BotCreateDraftStore', () {
    test('arranca vacío', () {
      expect(BotCreateDraftStore().current, isNull);
    });

    test('save persiste el borrador y current lo devuelve', () {
      final store = BotCreateDraftStore();
      const draft = BotCreateDraft(template: _t1, name: 'Bot', identifier: '5');
      store.save(draft);
      expect(store.current, draft);
    });

    test('save con borrador vacío equivale a limpiar (no guarda basura)', () {
      final store = BotCreateDraftStore()
        ..save(const BotCreateDraft(template: _t1, name: 'Bot'));
      store.save(const BotCreateDraft());
      expect(store.current, isNull);
    });

    test('clear borra el borrador guardado', () {
      final store = BotCreateDraftStore()
        ..save(const BotCreateDraft(template: _t1, name: 'Bot'));
      store.clear();
      expect(store.current, isNull);
    });
  });
}
