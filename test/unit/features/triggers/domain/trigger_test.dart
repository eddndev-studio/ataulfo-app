import 'package:agentic/features/triggers/domain/entities/trigger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TriggerType.fromWire', () {
    test('mapea TEXT y LABEL', () {
      expect(TriggerType.fromWire('TEXT'), TriggerType.text);
      expect(TriggerType.fromWire('LABEL'), TriggerType.label);
    });
    test('valor desconocido o casing distinto → ArgumentError', () {
      expect(() => TriggerType.fromWire('text'), throwsArgumentError);
      expect(() => TriggerType.fromWire('WEBHOOK'), throwsArgumentError);
      expect(() => TriggerType.fromWire(''), throwsArgumentError);
    });
  });

  group('TriggerType.toWire (roundtrip)', () {
    test('cada valor serializa al token canónico UPPERCASE', () {
      for (final v in TriggerType.values) {
        expect(TriggerType.fromWire(v.toWire()), v);
      }
    });
  });

  group('MatchType.fromWire', () {
    test('mapea EXACT/CONTAINS/REGEX', () {
      expect(MatchType.fromWire('EXACT'), MatchType.exact);
      expect(MatchType.fromWire('CONTAINS'), MatchType.contains);
      expect(MatchType.fromWire('REGEX'), MatchType.regex);
    });
    test('valor desconocido → ArgumentError', () {
      expect(() => MatchType.fromWire('exact'), throwsArgumentError);
      expect(() => MatchType.fromWire('PREFIX'), throwsArgumentError);
    });
  });

  group('MatchType.toWire (roundtrip)', () {
    test('cada valor serializa al token canónico UPPERCASE', () {
      for (final v in MatchType.values) {
        expect(MatchType.fromWire(v.toWire()), v);
      }
    });
  });

  group('LabelAction.fromWire', () {
    test('mapea ADD/REMOVE', () {
      expect(LabelAction.fromWire('ADD'), LabelAction.add);
      expect(LabelAction.fromWire('REMOVE'), LabelAction.remove);
    });
    test('valor desconocido → ArgumentError', () {
      expect(() => LabelAction.fromWire('add'), throwsArgumentError);
      expect(() => LabelAction.fromWire('TOGGLE'), throwsArgumentError);
    });
  });

  group('LabelAction.toWire (roundtrip)', () {
    test('cada valor serializa al token canónico UPPERCASE', () {
      for (final v in LabelAction.values) {
        expect(LabelAction.fromWire(v.toWire()), v);
      }
    });
  });

  group('TriggerScope.fromWire', () {
    test('mapea INCOMING/OUTGOING/BOTH', () {
      expect(TriggerScope.fromWire('INCOMING'), TriggerScope.incoming);
      expect(TriggerScope.fromWire('OUTGOING'), TriggerScope.outgoing);
      expect(TriggerScope.fromWire('BOTH'), TriggerScope.both);
    });
    test('valor desconocido → ArgumentError', () {
      expect(() => TriggerScope.fromWire('both'), throwsArgumentError);
      expect(() => TriggerScope.fromWire('INTERNAL'), throwsArgumentError);
    });
  });

  group('TriggerScope.toWire (roundtrip)', () {
    test('cada valor serializa al token canónico UPPERCASE', () {
      for (final v in TriggerScope.values) {
        expect(TriggerScope.fromWire(v.toWire()), v);
      }
    });
  });

  group('Trigger value-equality', () {
    final base = Trigger(
      id: 't1',
      templateId: 'tpl1',
      flowId: 'f1',
      triggerType: TriggerType.text,
      matchType: MatchType.contains,
      keyword: 'hola',
      labelId: '',
      labelAction: null,
      scope: TriggerScope.both,
      isActive: true,
      createdAt: DateTime.utc(2026, 5, 1, 12),
      updatedAt: DateTime.utc(2026, 5, 1, 12),
    );

    test('dos instancias con misma data son iguales', () {
      final a = Trigger(
        id: 't1',
        templateId: 'tpl1',
        flowId: 'f1',
        triggerType: TriggerType.text,
        matchType: MatchType.contains,
        keyword: 'hola',
        labelId: '',
        labelAction: null,
        scope: TriggerScope.both,
        isActive: true,
        createdAt: DateTime.utc(2026, 5, 1, 12),
        updatedAt: DateTime.utc(2026, 5, 1, 12),
      );
      expect(a, equals(base));
      expect(a.hashCode, equals(base.hashCode));
    });

    test('id distinto rompe igualdad', () {
      final b = base.copyWith(id: 't2');
      expect(b, isNot(equals(base)));
    });

    test('labelAction null vs ADD rompe igualdad', () {
      final b = base.copyWith(labelAction: LabelAction.add);
      expect(b, isNot(equals(base)));
    });

    test('copyWith preserva campos no sobreescritos', () {
      final c = base.copyWith(isActive: false);
      expect(c.isActive, isFalse);
      expect(c.id, base.id);
      expect(c.keyword, base.keyword);
      expect(c.scope, base.scope);
    });
  });

  group('Trigger shape por TriggerType', () {
    test(
      'TEXT lleva matchType + keyword; labelId/labelAction quedan vacíos',
      () {
        final t = Trigger(
          id: 't1',
          templateId: 'tpl1',
          flowId: 'f1',
          triggerType: TriggerType.text,
          matchType: MatchType.exact,
          keyword: 'comprar',
          labelId: '',
          labelAction: null,
          scope: TriggerScope.incoming,
          isActive: true,
          createdAt: DateTime.utc(2026, 5, 1),
          updatedAt: DateTime.utc(2026, 5, 1),
        );
        expect(t.triggerType, TriggerType.text);
        expect(t.keyword, 'comprar');
        expect(t.labelId, '');
        expect(t.labelAction, isNull);
      },
    );

    test(
      'LABEL lleva labelId + labelAction; matchType/keyword quedan vacíos',
      () {
        final t = Trigger(
          id: 't2',
          templateId: 'tpl1',
          flowId: 'f1',
          triggerType: TriggerType.label,
          matchType: null,
          keyword: '',
          labelId: 'lbl_vip',
          labelAction: LabelAction.add,
          scope: TriggerScope.both,
          isActive: true,
          createdAt: DateTime.utc(2026, 5, 1),
          updatedAt: DateTime.utc(2026, 5, 1),
        );
        expect(t.triggerType, TriggerType.label);
        expect(t.matchType, isNull);
        expect(t.keyword, '');
        expect(t.labelId, 'lbl_vip');
        expect(t.labelAction, LabelAction.add);
      },
    );
  });
}
