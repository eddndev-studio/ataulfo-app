/// Tipo de evento reservable de la org: el "qué" de una cita (una consulta,
/// una demostración, una llamada) con su duración fija. La duración es un
/// múltiplo de 15 minutos (invariante del dominio del backend); el cliente
/// ofrece los múltiplos válidos en el formulario pero no recalcula la regla.
///
/// `active` gobierna si el tipo se ofrece para reservar (el asistente y la
/// reserva manual solo listan activos); desactivar preserva las citas ya
/// creadas con ese tipo. El backend nunca borra tipos.
class EventType {
  const EventType({
    required this.id,
    required this.name,
    required this.description,
    required this.durationMin,
    required this.active,
  });

  final String id;
  final String name;
  final String description;

  /// Duración en minutos (múltiplo de 15, >= 15). Coincide con el hueco que
  /// ocupa una cita de este tipo en la agenda.
  final int durationMin;

  final bool active;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventType &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.durationMin == durationMin &&
        other.active == active;
  }

  @override
  int get hashCode => Object.hash(id, name, description, durationMin, active);
}
