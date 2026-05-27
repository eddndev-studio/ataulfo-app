import 'package:agentic/features/flows/domain/entities/flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Flow value-equality', () {
    test('dos instancias con misma data son iguales', () {
      const a = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'Bienvenida',
        isActive: true,
        version: 3,
      );
      const b = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'Bienvenida',
        isActive: true,
        version: 3,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('cambia el name → desigual', () {
      const a = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'Bienvenida',
        isActive: true,
        version: 1,
      );
      const b = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'Despedida',
        isActive: true,
        version: 1,
      );

      expect(a, isNot(equals(b)));
    });

    test('cambia isActive → desigual', () {
      const a = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'Bienvenida',
        isActive: true,
        version: 1,
      );
      const b = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'Bienvenida',
        isActive: false,
        version: 1,
      );

      expect(a, isNot(equals(b)));
    });

    test('cambia version → desigual', () {
      const a = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'Bienvenida',
        isActive: true,
        version: 1,
        cooldownMs: 0,
        usageLimit: 0,
        excludesFlows: <String>[],
      );
      const b = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'Bienvenida',
        isActive: true,
        version: 2,
        cooldownMs: 0,
        usageLimit: 0,
        excludesFlows: <String>[],
      );

      expect(a, isNot(equals(b)));
    });

    test('expone cooldownMs / usageLimit / excludesFlows', () {
      const f = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'Bienvenida',
        isActive: true,
        version: 1,
        cooldownMs: 5000,
        usageLimit: 3,
        excludesFlows: <String>['f2', 'f3'],
      );

      expect(f.cooldownMs, 5000);
      expect(f.usageLimit, 3);
      expect(f.excludesFlows, <String>['f2', 'f3']);
    });

    test('cambia cooldownMs → desigual', () {
      const a = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'Bienvenida',
        isActive: true,
        version: 1,
        cooldownMs: 0,
        usageLimit: 0,
        excludesFlows: <String>[],
      );
      const b = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'Bienvenida',
        isActive: true,
        version: 1,
        cooldownMs: 1000,
        usageLimit: 0,
        excludesFlows: <String>[],
      );

      expect(a, isNot(equals(b)));
    });

    test('cambia usageLimit → desigual', () {
      const a = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'Bienvenida',
        isActive: true,
        version: 1,
        cooldownMs: 0,
        usageLimit: 0,
        excludesFlows: <String>[],
      );
      const b = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'Bienvenida',
        isActive: true,
        version: 1,
        cooldownMs: 0,
        usageLimit: 5,
        excludesFlows: <String>[],
      );

      expect(a, isNot(equals(b)));
    });

    test('cambia excludesFlows → desigual', () {
      const a = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'Bienvenida',
        isActive: true,
        version: 1,
        cooldownMs: 0,
        usageLimit: 0,
        excludesFlows: <String>[],
      );
      const b = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'Bienvenida',
        isActive: true,
        version: 1,
        cooldownMs: 0,
        usageLimit: 0,
        excludesFlows: <String>['f2'],
      );

      expect(a, isNot(equals(b)));
    });

    test('orden distinto en excludesFlows → desigual', () {
      const a = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'Bienvenida',
        isActive: true,
        version: 1,
        cooldownMs: 0,
        usageLimit: 0,
        excludesFlows: <String>['f2', 'f3'],
      );
      const b = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'Bienvenida',
        isActive: true,
        version: 1,
        cooldownMs: 0,
        usageLimit: 0,
        excludesFlows: <String>['f3', 'f2'],
      );

      expect(a, isNot(equals(b)));
    });
  });
}
