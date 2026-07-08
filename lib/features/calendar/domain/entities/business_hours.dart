/// Un tramo de atención dentro de un día de la semana: `[openMin, closeMin)`
/// en minutos desde la medianoche LOCAL. Varios tramos por día modelan pausas
/// (p. ej. 09:00–14:00 y 16:00–19:00 son dos tramos del mismo `weekday`).
///
/// `weekday` sigue la convención del wire: 0 = domingo … 6 = sábado. Un
/// horario que cruza la medianoche no existe: se parte en dos tramos, uno por
/// día (el contrato de las ventanas del backend es intra-día).
class BusinessHoursSlot {
  const BusinessHoursSlot({
    required this.weekday,
    required this.openMin,
    required this.closeMin,
  });

  /// 0 = domingo, 1 = lunes … 6 = sábado.
  final int weekday;

  /// Apertura en minutos desde 00:00 local (p. ej. 540 = 09:00).
  final int openMin;

  /// Cierre en minutos desde 00:00 local, exclusivo. Estrictamente mayor que
  /// [openMin] en un tramo válido.
  final int closeMin;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BusinessHoursSlot &&
        other.weekday == weekday &&
        other.openMin == openMin &&
        other.closeMin == closeMin;
  }

  @override
  int get hashCode => Object.hash(weekday, openMin, closeMin);
}
