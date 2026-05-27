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
      );
      const b = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'Bienvenida',
        isActive: true,
        version: 2,
      );

      expect(a, isNot(equals(b)));
    });
  });
}
