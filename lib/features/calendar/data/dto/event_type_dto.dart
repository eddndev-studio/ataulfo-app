/// DTO del wire de un tipo de evento (`GET /workspace/calendar/event-types`).
///
/// Las claves viajan en camelCase (consistente con el adaptador Go del
/// calendario). Todos los campos son obligatorios: un faltante o un tipo
/// inválido es un wire roto, no un caso a tolerar. El mapper convierte a la
/// entidad de dominio.
class EventTypeDto {
  const EventTypeDto({
    required this.id,
    required this.name,
    required this.description,
    required this.durationMin,
    required this.active,
  });

  factory EventTypeDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final description = json['description'];
    final durationMin = json['durationMin'];
    final active = json['active'];
    if (id is! String ||
        name is! String ||
        description is! String ||
        durationMin is! int ||
        active is! bool) {
      throw const FormatException(
        'event-type: clave obligatoria ausente o tipo inválido',
      );
    }
    return EventTypeDto(
      id: id,
      name: name,
      description: description,
      durationMin: durationMin,
      active: active,
    );
  }

  final String id;
  final String name;
  final String description;
  final int durationMin;
  final bool active;
}
