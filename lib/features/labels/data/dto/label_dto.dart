/// DTO de `GET /labels` (ver `labelResp` en
/// `ataulfo-go/internal/adapters/httplabel/dto.go`). `color` es un string hex
/// `#RRGGBB`. `createdAt`/`updatedAt` viajan en el wire pero no se modelan: el
/// selector del mapeo solo necesita id/name/color/description.
class LabelResp {
  const LabelResp({
    required this.id,
    required this.name,
    required this.color,
    required this.description,
  });

  factory LabelResp.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final color = json['color'];
    final rawDescription = json['description'];
    if (id is! String || name is! String || color is! String) {
      throw const FormatException(
        'labelResp con campos requeridos faltantes o de tipo incorrecto',
      );
    }
    return LabelResp(
      id: id,
      name: name,
      color: color,
      description: rawDescription is String ? rawDescription : '',
    );
  }

  final String id;
  final String name;
  final String color;
  final String description;
}

class LabelListResp {
  const LabelListResp({required this.items});

  factory LabelListResp.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) {
      throw const FormatException('labelListResp sin items array');
    }
    return LabelListResp(
      items: items
          .cast<Map<String, dynamic>>()
          .map(LabelResp.fromJson)
          .toList(growable: false),
    );
  }

  final List<LabelResp> items;
}

/// Body de `POST /labels` y `PUT /labels/{id}` (mismo shape: el catálogo es
/// plano, PUT reemplaza el documento). `color` es hex `#RRGGBB`. La validación
/// fina (longitudes, formato del color) la hace el backend; aquí solo se
/// serializa lo que el operador introdujo.
class LabelUpsertReq {
  const LabelUpsertReq({
    required this.name,
    required this.color,
    required this.description,
  });

  final String name;
  final String color;
  final String description;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'color': color,
    'description': description,
  };
}
