import 'package:ataulfo/features/templates/data/dto/var_def_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> defJson({
    String id = 'v1',
    String name = 'nombre',
    String type = 'text',
    String def = '',
    String description = '',
  }) => <String, dynamic>{
    'id': id,
    'name': name,
    'type': type,
    'default': def,
    'description': description,
  };

  group('VarDefResp.fromJson', () {
    test('parsea todos los campos', () {
      final r = VarDefResp.fromJson(
        defJson(
          id: 'v1',
          name: 'nombre',
          type: 'text',
          def: 'cliente',
          description: 'Saludo personalizado',
        ),
      );

      expect(r.id, 'v1');
      expect(r.name, 'nombre');
      expect(r.type, 'text');
      expect(r.defaultValue, 'cliente');
      expect(r.description, 'Saludo personalizado');
    });

    test('clave obligatoria ausente → FormatException', () {
      expect(
        () => VarDefResp.fromJson(<String, dynamic>{'id': 'v1'}),
        throwsFormatException,
      );
    });

    test(
      'default/description faltantes son interpretados como string vacío',
      () {
        // El backend serializa con omitempty: defaults vacíos no aparecen
        // en el JSON. El cliente debe aceptarlo y normalizar a "".
        final r = VarDefResp.fromJson(<String, dynamic>{
          'id': 'v1',
          'name': 'nombre',
          'type': 'text',
        });

        expect(r.defaultValue, '');
        expect(r.description, '');
      },
    );
  });

  group('ListVarDefsResp.fromJson', () {
    test('parsea {version, defs[]}', () {
      final r = ListVarDefsResp.fromJson(<String, dynamic>{
        'version': 3,
        'defs': <dynamic>[
          defJson(name: 'nombre'),
          defJson(id: 'v2', name: 'edad'),
        ],
      });

      expect(r.version, 3);
      expect(r.defs, hasLength(2));
      expect(r.defs[0].name, 'nombre');
      expect(r.defs[1].name, 'edad');
    });

    test('defs ausente → FormatException', () {
      expect(
        () => ListVarDefsResp.fromJson(<String, dynamic>{'version': 1}),
        throwsFormatException,
      );
    });

    test('defs vacío es válido (plantilla sin variables)', () {
      final r = ListVarDefsResp.fromJson(<String, dynamic>{
        'version': 1,
        'defs': <dynamic>[],
      });

      expect(r.version, 1);
      expect(r.defs, isEmpty);
    });
  });
}
