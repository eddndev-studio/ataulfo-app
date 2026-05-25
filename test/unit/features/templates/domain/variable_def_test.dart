import 'package:agentic/features/templates/domain/entities/variable_def.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VarType.fromWire', () {
    test('mapea "text" → VarType.text', () {
      expect(VarType.fromWire('text'), VarType.text);
    });

    test('tipo desconocido en el wire → ArgumentError (fail-loud)', () {
      // El backend v1 sólo conoce "text"; cualquier extensión futura
      // (number/date/etc.) tiene que aterrizar primero como entrada
      // explícita aquí. Degradar a un "unknown" cosmético escondería
      // drift de contrato.
      expect(() => VarType.fromWire('number'), throwsArgumentError);
      expect(() => VarType.fromWire(''), throwsArgumentError);
      expect(() => VarType.fromWire('TEXT'), throwsArgumentError);
    });
  });

  group('VariableDef value-equality', () {
    test('dos instancias con misma data son iguales', () {
      const a = VariableDef(
        id: 'v1',
        name: 'nombre',
        type: VarType.text,
        defaultValue: 'cliente',
        description: 'Saludo personalizado',
      );
      const b = VariableDef(
        id: 'v1',
        name: 'nombre',
        type: VarType.text,
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
        type: VarType.text,
        defaultValue: '',
        description: '',
      );
      const b = VariableDef(
        id: 'v1',
        name: 'otro',
        type: VarType.text,
        defaultValue: '',
        description: '',
      );

      expect(a, isNot(equals(b)));
    });
  });
}
