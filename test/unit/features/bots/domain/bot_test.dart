import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BotChannel.fromWire', () {
    test('"WA_UNOFFICIAL" → waUnofficial', () {
      expect(BotChannel.fromWire('WA_UNOFFICIAL'), BotChannel.waUnofficial);
    });

    test('"WABA" → waba', () {
      expect(BotChannel.fromWire('WABA'), BotChannel.waba);
    });

    test('valor desconocido lanza ArgumentError (fail-loud)', () {
      // Política: si el backend agrega un canal nuevo (ej. "WABA_CLOUD") el
      // cliente debe enterarse en boot, no degradar silenciosamente con un
      // "unknown" cosmético. La detección temprana baja a ergonomía dejar
      // que el mapper rompa.
      expect(() => BotChannel.fromWire('WABA_CLOUD'), throwsArgumentError);
      expect(() => BotChannel.fromWire(''), throwsArgumentError);
    });
  });

  group('BotChannel.toWire', () {
    // Inversa de fromWire: el cliente envía el canal al backend como string
    // exacto del contrato. Sin esta función la UI tendría que conocer los
    // literales del wire al construir el body del POST, acoplando la
    // presentación al protocolo.
    test('waUnofficial → "WA_UNOFFICIAL"', () {
      expect(BotChannel.waUnofficial.toWire(), 'WA_UNOFFICIAL');
    });

    test('waba → "WABA"', () {
      expect(BotChannel.waba.toWire(), 'WABA');
    });

    test('roundtrip fromWire ∘ toWire es identidad para todo el enum', () {
      // Garantía estructural: nunca podrá haber un valor del enum que
      // toWire serialice a algo que fromWire no acepte de vuelta.
      for (final c in BotChannel.values) {
        expect(BotChannel.fromWire(c.toWire()), c);
      }
    });
  });

  group('Bot', () {
    Bot make({
      String id = 'b1',
      String orgID = 'o1',
      String templateID = 't1',
      String name = 'Soporte',
      BotChannel channel = BotChannel.waUnofficial,
      String? identifier = '52155...',
      int version = 1,
      bool paused = false,
      bool aiDisabled = false,
    }) => Bot(
      id: id,
      orgId: orgID,
      templateId: templateID,
      name: name,
      channel: channel,
      identifier: identifier,
      version: version,
      paused: paused,
      aiDisabled: aiDisabled,
    );

    test('expone los campos del wire S04', () {
      final b = make();
      expect(b.id, 'b1');
      expect(b.orgId, 'o1');
      expect(b.templateId, 't1');
      expect(b.name, 'Soporte');
      expect(b.channel, BotChannel.waUnofficial);
      expect(b.identifier, '52155...');
      expect(b.version, 1);
      expect(b.paused, isFalse);
      expect(b.aiDisabled, isFalse);
    });

    test(
      'identifier es opcional (puede ser null cuando el backend lo omite)',
      () {
        final b = make(identifier: null);
        expect(b.identifier, isNull);
      },
    );

    test('dos Bot con misma data son iguales (value-type)', () {
      final a = make();
      final b = make();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('difieren si cambia cualquiera de los 9 campos', () {
      final base = make();
      expect(base, isNot(make(id: 'b2')));
      expect(base, isNot(make(orgID: 'o2')));
      expect(base, isNot(make(templateID: 't2')));
      expect(base, isNot(make(name: 'Otro')));
      expect(base, isNot(make(channel: BotChannel.waba)));
      expect(base, isNot(make(identifier: 'otro')));
      expect(base, isNot(make(version: 2)));
      expect(base, isNot(make(paused: true)));
      expect(base, isNot(make(aiDisabled: true)));
    });
  });
}
