import 'package:agentic/features/templates/data/dto/var_def_dto.dart';
import 'package:agentic/features/templates/data/mappers/var_defs_mapper.dart';
import 'package:agentic/features/templates/domain/entities/variable_def.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VarDefsMapper', () {
    test('varDefRespToEntity traduce todos los campos', () {
      const resp = VarDefResp(
        id: 'v1',
        name: 'nombre',
        type: 'text',
        defaultValue: 'cliente',
        description: 'Saludo personalizado',
      );

      final ent = VarDefsMapper.varDefRespToEntity(resp);

      expect(ent.id, 'v1');
      expect(ent.name, 'nombre');
      expect(ent.type, VarType.text);
      expect(ent.defaultValue, 'cliente');
      expect(ent.description, 'Saludo personalizado');
    });

    test('tipo desconocido en el wire → ArgumentError sin envolver', () {
      // El mapper propaga el ArgumentError del fromWire sin
      // convertirlo a otra cosa — el drift de contrato no se degrada
      // a un failure reintentable.
      const resp = VarDefResp(
        id: 'v1',
        name: 'nombre',
        type: 'number',
        defaultValue: '',
        description: '',
      );

      expect(() => VarDefsMapper.varDefRespToEntity(resp), throwsArgumentError);
    });

    test('listToLoaded expone version + defs en el orden del wire', () {
      const resp = ListVarDefsResp(
        version: 2,
        defs: <VarDefResp>[
          VarDefResp(
            id: 'v1',
            name: 'nombre',
            type: 'text',
            defaultValue: '',
            description: '',
          ),
          VarDefResp(
            id: 'v2',
            name: 'edad',
            type: 'text',
            defaultValue: '0',
            description: 'Años cumplidos',
          ),
        ],
      );

      final res = VarDefsMapper.listToLoaded(resp);

      expect(res.version, 2);
      expect(res.defs, hasLength(2));
      expect(res.defs[0].name, 'nombre');
      expect(res.defs[1].name, 'edad');
      expect(res.defs[1].defaultValue, '0');
    });
  });
}
