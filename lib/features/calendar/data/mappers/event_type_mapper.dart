import '../../domain/entities/event_type.dart';
import '../dto/event_type_dto.dart';

/// Convierte el DTO del wire a la entidad de dominio. Trivial (mismos campos):
/// existe para mantener el borde wire ⇄ dominio explícito y simétrico con el
/// resto de features.
class EventTypeMapper {
  const EventTypeMapper._();

  static EventType dtoToEntity(EventTypeDto dto) => EventType(
    id: dto.id,
    name: dto.name,
    description: dto.description,
    durationMin: dto.durationMin,
    active: dto.active,
  );
}
