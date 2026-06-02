import 'package:ataulfo/features/templates/data/dto/var_def_dto.dart';
import 'package:ataulfo/features/templates/data/mappers/var_defs_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VarDefsMapper', () {
    test('varDefRespToEntity traduce todos los campos', () {
      const resp = VarDefResp(
        id: 'v1',
        name: 'nombre',
        defaultValue: 'cliente',
        description: 'Saludo personalizado',
      );

      final ent = VarDefsMapper.varDefRespToEntity(resp);

      expect(ent.id, 'v1');
      expect(ent.name, 'nombre');
      expect(ent.defaultValue, 'cliente');
      expect(ent.description, 'Saludo personalizado');
    });

    test('listToLoaded expone version + defs en el orden del wire', () {
      const resp = ListVarDefsResp(
        version: 2,
        defs: <VarDefResp>[
          VarDefResp(
            id: 'v1',
            name: 'nombre',
            defaultValue: '',
            description: '',
          ),
          VarDefResp(
            id: 'v2',
            name: 'edad',
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
