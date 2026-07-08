/// DTO del wire de una cita (`GET /workspace/calendar/appointments`).
///
/// Claves camelCase. `botId`/`chatLid` son nullable (una reserva manual no
/// nace de un chat). `startAt`/`endAt` viajan como RFC3339 UTC y aquí quedan
/// crudos: el mapper los parsea a `DateTime`. `status`/`createdBy` quedan como
/// strings del wire; el mapper los interpreta al enum (y lanza si son
/// desconocidos). `note` ausente/null degrada a cadena vacía (es opcional).
class AppointmentDto {
  const AppointmentDto({
    required this.id,
    required this.eventTypeId,
    required this.eventTypeName,
    required this.botId,
    required this.chatLid,
    required this.customerName,
    required this.note,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.createdBy,
  });

  factory AppointmentDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final eventTypeId = json['eventTypeId'];
    final eventTypeName = json['eventTypeName'];
    final botId = json['botId'];
    final chatLid = json['chatLid'];
    final customerName = json['customerName'];
    final note = json['note'] ?? '';
    final startAt = json['startAt'];
    final endAt = json['endAt'];
    final status = json['status'];
    final createdBy = json['createdBy'];
    if (id is! String ||
        eventTypeId is! String ||
        eventTypeName is! String ||
        (botId != null && botId is! String) ||
        (chatLid != null && chatLid is! String) ||
        customerName is! String ||
        note is! String ||
        startAt is! String ||
        endAt is! String ||
        status is! String ||
        createdBy is! String) {
      throw const FormatException(
        'appointment: clave obligatoria ausente o tipo inválido',
      );
    }
    return AppointmentDto(
      id: id,
      eventTypeId: eventTypeId,
      eventTypeName: eventTypeName,
      botId: botId as String?,
      chatLid: chatLid as String?,
      customerName: customerName,
      note: note,
      startAt: startAt,
      endAt: endAt,
      status: status,
      createdBy: createdBy,
    );
  }

  final String id;
  final String eventTypeId;
  final String eventTypeName;
  final String? botId;
  final String? chatLid;
  final String customerName;
  final String note;
  final String startAt;
  final String endAt;
  final String status;
  final String createdBy;
}
