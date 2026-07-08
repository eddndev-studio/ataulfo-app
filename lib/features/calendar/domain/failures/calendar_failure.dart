/// Failures expuestos por la capa de datos del calendario.
///
/// Son `Exception` (no `Error`): los blocs/cubits las atrapan y traducen a
/// estados de UI. La jerarquía es sellada para forzar a los switches a cubrir
/// todos los casos: un failure nuevo rompe el build, no se cuela silencioso.
///
/// 401 NO aparece aquí: lo absorbe el AuthInterceptor (refresh transparente o
/// purga + Unauthenticated).
sealed class CalendarFailure implements Exception {
  const CalendarFailure();
}

/// Sin conexión, DNS, TLS, connection error. Reintentable.
final class CalendarNetworkFailure extends CalendarFailure {
  const CalendarNetworkFailure();
}

/// Timeout específico (connect/send/receive). Distinto de red para permitir un
/// copy de reintento diferenciado.
final class CalendarTimeoutFailure extends CalendarFailure {
  const CalendarTimeoutFailure();
}

/// 403: el rol no alcanza para la operación (el CRUD de tipos de evento y de
/// horarios es ADMIN+). El gate de la UI es cosmético; la autoridad es este
/// 403 del servidor.
final class CalendarForbiddenFailure extends CalendarFailure {
  const CalendarForbiddenFailure();
}

/// 404: el recurso (tipo de evento, cita) no existe en la org del operador.
final class CalendarNotFoundFailure extends CalendarFailure {
  const CalendarNotFoundFailure();
}

/// 409: el hueco acaba de ocuparse entre que se listó la disponibilidad y se
/// intentó reservar. La UI recarga los slots y pide reintentar.
final class CalendarConflictFailure extends CalendarFailure {
  const CalendarConflictFailure();
}

/// 422: la operación es inválida según el dominio del backend (tramos de
/// horario que se cruzan, cita en el pasado, fuera de horario…). El backend
/// manda un código estable que el datasource traduce a copy es-MX en
/// [message]; null si el código no se conoce (la UI cae a su copy genérico).
final class CalendarValidationFailure extends CalendarFailure {
  const CalendarValidationFailure([this.message]);

  /// Mensaje del backend explicando por qué se rechazó, o null si no vino uno.
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is CalendarValidationFailure && other.message == message;

  @override
  int get hashCode => Object.hash(CalendarValidationFailure, message);
}

/// 5xx del backend. Distinto de red: el servidor respondió, pero rompió.
final class CalendarServerFailure extends CalendarFailure {
  const CalendarServerFailure();
}

/// Cualquier otro caso (status no contemplado, body malformado, type error al
/// castear). El cliente lo expone como error genérico sin filtrar el status.
final class UnknownCalendarFailure extends CalendarFailure {
  const UnknownCalendarFailure();
}
