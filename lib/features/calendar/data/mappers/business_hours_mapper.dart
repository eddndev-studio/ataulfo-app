import '../../domain/entities/business_hours.dart';
import '../dto/business_hours_dto.dart';

/// Convierte tramos de horario wire ⇄ dominio. La dirección entidad→DTO sirve
/// al `PUT` de reemplazo total (el editor manda la semana completa).
class BusinessHoursMapper {
  const BusinessHoursMapper._();

  static BusinessHoursSlot dtoToEntity(BusinessHoursSlotDto dto) =>
      BusinessHoursSlot(
        weekday: dto.weekday,
        openMin: dto.openMin,
        closeMin: dto.closeMin,
      );

  static BusinessHoursSlotDto entityToDto(BusinessHoursSlot slot) =>
      BusinessHoursSlotDto(
        weekday: slot.weekday,
        openMin: slot.openMin,
        closeMin: slot.closeMin,
      );
}
