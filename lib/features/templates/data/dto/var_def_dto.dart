/// DTO de una variable-definition del listado
/// `GET /templates/{id}/variable-definitions` (ver `varDefResp` en
/// `ataulfo-go/internal/adapters/httptemplates/dto.go`). Nombres
/// `snake_case` del wire viven aquí; el mapper traduce a la entidad.
class VarDefResp {
  const VarDefResp({
    required this.id,
    required this.name,
    required this.type,
    required this.defaultValue,
    required this.description,
  });

  factory VarDefResp.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final type = json['type'];
    if (id is! String || name is! String || type is! String) {
      throw const FormatException('varDefResp: clave obligatoria ausente');
    }
    final rawDefault = json['default'];
    final rawDesc = json['description'];
    // `default` y `description` llevan omitempty en el backend: ausentes
    // significan vacíos. Cualquier otro tipo (no-string presente) es
    // contrato roto.
    if (rawDefault != null && rawDefault is! String) {
      throw const FormatException('varDefResp.default no es string');
    }
    if (rawDesc != null && rawDesc is! String) {
      throw const FormatException('varDefResp.description no es string');
    }
    return VarDefResp(
      id: id,
      name: name,
      type: type,
      defaultValue: (rawDefault as String?) ?? '',
      description: (rawDesc as String?) ?? '',
    );
  }

  final String id;
  final String name;
  final String type;
  final String defaultValue;
  final String description;
}

class ListVarDefsResp {
  const ListVarDefsResp({required this.version, required this.defs});

  factory ListVarDefsResp.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final defs = json['defs'];
    if (version is! int || defs is! List<dynamic>) {
      throw const FormatException('listVarDefsResp: clave obligatoria ausente');
    }
    return ListVarDefsResp(
      version: version,
      defs: defs
          .cast<Map<String, dynamic>>()
          .map(VarDefResp.fromJson)
          .toList(growable: false),
    );
  }

  final int version;
  final List<VarDefResp> defs;
}
