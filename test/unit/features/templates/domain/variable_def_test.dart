import 'package:agentic/features/templates/domain/entities/variable_def.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VarType.fromWire', () {
    test('mapea el set v1 completo (text + label + 4 multimedia)', () {
      // Espejo del set del backend (variable_def.go).
      expect(VarType.fromWire('text'), VarType.text);
      expect(VarType.fromWire('label'), VarType.label);
      expect(VarType.fromWire('image'), VarType.image);
      expect(VarType.fromWire('video'), VarType.video);
      expect(VarType.fromWire('audio'), VarType.audio);
      expect(VarType.fromWire('document'), VarType.document);
    });

    test('tipo desconocido en el wire → ArgumentError (fail-loud)', () {
      // Cualquier extensión futura (number/date/etc.) tiene que aterrizar
      // primero como entrada explícita aquí. Degradar a un "unknown"
      // cosmético escondería drift de contrato.
      expect(() => VarType.fromWire('number'), throwsArgumentError);
      expect(() => VarType.fromWire(''), throwsArgumentError);
      // El cliente NO normaliza case (el backend sí). Wire canonical es
      // lower-case; cualquier otra forma viene mal del backend y rompe.
      expect(() => VarType.fromWire('TEXT'), throwsArgumentError);
      expect(() => VarType.fromWire('Image'), throwsArgumentError);
    });
  });

  group('VarType.toWire (roundtrip con fromWire)', () {
    test('cada VarType serializa al token canónico del wire', () {
      // Roundtrip exhaustivo: serializar y deserializar debe dar la misma
      // VarType. Anclar este test asegura que añadir un tipo en el enum
      // sin extender toWire/fromWire haga ruido en el switch exhaustivo.
      for (final t in VarType.values) {
        expect(
          VarType.fromWire(t.toWire()),
          t,
          reason: 'roundtrip fallido para $t (wire=${t.toWire()})',
        );
      }
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
