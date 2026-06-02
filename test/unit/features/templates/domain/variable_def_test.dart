import 'package:ataulfo/features/templates/domain/entities/variable_def.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VariableDef value-equality', () {
    test('dos instancias con misma data son iguales', () {
      const a = VariableDef(
        id: 'v1',
        name: 'nombre',
        defaultValue: 'cliente',
        description: 'Saludo personalizado',
      );
      const b = VariableDef(
        id: 'v1',
        name: 'nombre',
        defaultValue: 'cliente',
        description: 'Saludo personalizado',
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('cambia el name → desigual', () {
      const a = VariableDef(
        id: 'v1',
        name: 'nombre',
        defaultValue: '',
        description: '',
      );
      const b = VariableDef(
        id: 'v1',
        name: 'otro',
        defaultValue: '',
        description: '',
      );

      expect(a, isNot(equals(b)));
    });
  });
}
