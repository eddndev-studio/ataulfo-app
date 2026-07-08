/// DTO del wire de un tramo de atención (`GET /workspace/calendar/hours`).
///
/// `weekday` 0=domingo..6=sábado; `openMin`/`closeMin` en minutos desde la
/// medianoche local. Campos obligatorios y enteros: un wire con otro tipo está
/// roto.
class BusinessHoursSlotDto {
  const BusinessHoursSlotDto({
    required this.weekday,
    required this.openMin,
    required this.closeMin,
  });

  factory BusinessHoursSlotDto.fromJson(Map<String, dynamic> json) {
    final weekday = json['weekday'];
    final openMin = json['openMin'];
    final closeMin = json['closeMin'];
    if (weekday is! int || openMin is! int || closeMin is! int) {
      throw const FormatException(
        'hours: clave obligatoria ausente o tipo inválido',
      );
    }
    return BusinessHoursSlotDto(
      weekday: weekday,
      openMin: openMin,
      closeMin: closeMin,
    );
  }

  final int weekday;
  final int openMin;
  final int closeMin;

  /// Serializa el tramo para el `PUT /workspace/calendar/hours` (reemplazo
  /// total). Espeja las mismas claves camelCase del wire de lectura.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'weekday': weekday,
    'openMin': openMin,
    'closeMin': closeMin,
  };
}
