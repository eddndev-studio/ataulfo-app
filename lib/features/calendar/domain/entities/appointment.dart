/// Estado de una cita en su ciclo de vida. Cerrado: un valor fuera de este
/// conjunto es un wire roto, no un caso a tolerar (el mapper lanza).
///
/// - [confirmed]: viva y reservando el hueco (bloquea doble-reserva).
/// - [cancelled]: anulada; libera el hueco.
/// - [completed]: se llevó a cabo.
/// - [noShow]: el cliente no se presentó.
enum AppointmentStatus { confirmed, cancelled, completed, noShow }

/// Quién creó la cita. [ai] = el asistente la reservó de forma autónoma en una
/// conversación; [operator] = un humano la creó a mano desde la agenda.
enum AppointmentCreatedBy { ai, operator }

/// Una cita reservada: el "cuándo" ([startAt]–[endAt], instantes UTC) de un
/// [eventTypeId] para un cliente. Puede estar ligada a un chat concreto
/// ([botId] + [chatLid], cuando la reservó el asistente en una conversación) o
/// no (reserva manual sin chat de origen).
///
/// Los instantes viajan y se guardan en UTC; la UI los pinta SIEMPRE en la
/// hora local del dispositivo. `eventTypeName` viaja denormalizado en el wire
/// para pintar la lista sin cruzar contra el catálogo de tipos.
class Appointment {
  const Appointment({
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

  final String id;
  final String eventTypeId;

  /// Nombre del tipo de evento, denormalizado por el backend para la lista.
  final String eventTypeName;

  /// Bot ligado a la cita, o null si la reserva no nació de un chat.
  final String? botId;

  /// Chat ligado a la cita (`chatLid`), o null. Junto con [botId] identifica la
  /// conversación de origen; ambos presentes o ambos ausentes.
  final String? chatLid;

  final String customerName;
  final String note;

  /// Inicio de la cita (UTC). Se pinta en hora local vía `toLocal()`.
  final DateTime startAt;

  /// Fin de la cita (UTC). `endAt - startAt` = duración del tipo de evento.
  final DateTime endAt;

  final AppointmentStatus status;
  final AppointmentCreatedBy createdBy;

  /// Ligada a una conversación concreta (ambos ids presentes).
  bool get hasChat => botId != null && chatLid != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Appointment &&
        other.id == id &&
        other.eventTypeId == eventTypeId &&
        other.eventTypeName == eventTypeName &&
        other.botId == botId &&
        other.chatLid == chatLid &&
        other.customerName == customerName &&
        other.note == note &&
        other.startAt == startAt &&
        other.endAt == endAt &&
        other.status == status &&
        other.createdBy == createdBy;
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventTypeId,
    eventTypeName,
    botId,
    chatLid,
    customerName,
    note,
    startAt,
    endAt,
    status,
    createdBy,
  );
}
