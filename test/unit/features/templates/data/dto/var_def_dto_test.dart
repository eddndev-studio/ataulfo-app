import 'package:ataulfo/features/templates/data/dto/var_def_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> defJson({
    String id = 'v1',
    String name = 'nombre',
    String def = '',
    String description = '',
  }) => <String, dynamic>{
    'id': id,
    'name': name,
    'default': def,
    'description': description,
  };

  group('VarDefResp.fromJson', () {
    test('parsea todos los campos', () {
      final r = VarDefResp.fromJson(
        defJson(
          id: 'v1',
          name: 'nombre',
          def: 'cliente',
          description: 'Saludo personalizado',
        ),
      );

      expect(r.id, 'v1');
      expect(r.name, 'nombre');
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
      'respuesta CON la clave legacy `type` decodifica bien (se ignora)',
      () {
        // El backend sigue emitiendo `type: "text"` por compat de wire; el
        // cliente lo tolera sin leerlo — las variables son solo-texto.
        final r = VarDefResp.fromJson(<String, dynamic>{
          'id': 'v1',
          'name': 'nombre',
          'type': 'text',
          'default': 'cliente',
          'description': '',
        });

        expect(r.id, 'v1');
        expect(r.name, 'nombre');
        expect(r.defaultValue, 'cliente');
      },
    );

    test('respuesta SIN la clave `type` decodifica igual de bien', () {
      // Cuando el backend deje de emitir `type`, la respuesta sigue
      // siendo válida — la clave nunca fue obligatoria para el cliente.
      final r = VarDefResp.fromJson(<String, dynamic>{
        'id': 'v1',
        'name': 'nombre',
        'default': 'cliente',
        'description': '',
      });

      expect(r.id, 'v1');
      expect(r.name, 'nombre');
      expect(r.defaultValue, 'cliente');
    });

    test(
      'default/description faltantes son interpretados como string vacío',
      () {
        // El backend serializa con omitempty: defaults vacíos no aparecen
        // en el JSON. El cliente debe aceptarlo y normalizar a "".
        final r = VarDefResp.fromJson(<String, dynamic>{
          'id': 'v1',
          'name': 'nombre',
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
