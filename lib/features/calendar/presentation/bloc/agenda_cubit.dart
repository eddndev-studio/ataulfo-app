import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/appointment.dart';
import '../../domain/failures/calendar_failure.dart';
import '../../domain/repositories/calendar_repository.dart';

/// Vista de UN día de la agenda. Mantiene el día seleccionado (fecha local, sin
/// hora) a través de todas las transiciones para que las flechas de
/// navegación y el encabezado siempre lo tengan, y carga las citas cuyo inicio
/// cae en `[día, día+1)` local.
///
/// Un cambio de estado de cita (cancelar/completar/no-show) recarga la lista
/// EN SILENCIO (sin volver a un spinner de pantalla completa): la fila
/// simplemente se actualiza. La navegación entre días sí muestra la carga.
enum AgendaStatus { loading, loaded, error }

class AgendaState {
  const AgendaState({
    required this.day,
    required this.status,
    required this.appointments,
    required this.failure,
    required this.mutating,
  });

  AgendaState.initial(this.day)
    : status = AgendaStatus.loading,
      appointments = const <Appointment>[],
      failure = null,
      mutating = false;

  /// Día en foco: fecha local a medianoche (la hora es 00:00 local).
  final DateTime day;
  final AgendaStatus status;

  /// Citas del día, ordenadas por inicio ascendente.
  final List<Appointment> appointments;

  /// Falla de la última carga (solo relevante con [status] == error).
  final CalendarFailure? failure;

  /// Hay una transición de estado en vuelo: las acciones del detalle se
  /// deshabilitan mientras dura.
  final bool mutating;

  AgendaState copyWith({
    DateTime? day,
    AgendaStatus? status,
    List<Appointment>? appointments,
    CalendarFailure? failure,
    bool clearFailure = false,
    bool? mutating,
  }) => AgendaState(
    day: day ?? this.day,
    status: status ?? this.status,
    appointments: appointments ?? this.appointments,
    failure: clearFailure ? null : (failure ?? this.failure),
    mutating: mutating ?? this.mutating,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AgendaState &&
        other.day == day &&
        other.status == status &&
        other.failure == failure &&
        other.mutating == mutating &&
        _listEquals(other.appointments, appointments);
  }

  @override
  int get hashCode =>
      Object.hash(day, status, failure, mutating, Object.hashAll(appointments));
}

class AgendaCubit extends Cubit<AgendaState> {
  AgendaCubit(this._repo, {DateTime? today})
    : super(AgendaState.initial(_dateOnly(today ?? DateTime.now())));

  final CalendarRepository _repo;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _next(DateTime day) =>
      DateTime(day.year, day.month, day.day + 1);

  /// Carga (o recarga) el día actual mostrando el spinner.
  Future<void> load() async {
    emit(state.copyWith(status: AgendaStatus.loading, clearFailure: true));
    await _fetchInto(state.day);
  }

  Future<void> goToDay(DateTime d) async {
    final day = _dateOnly(d);
    emit(
      state.copyWith(
        day: day,
        status: AgendaStatus.loading,
        appointments: const <Appointment>[],
        clearFailure: true,
      ),
    );
    await _fetchInto(day);
  }

  Future<void> nextDay() => goToDay(_next(state.day));
  Future<void> prevDay() =>
      goToDay(DateTime(state.day.year, state.day.month, state.day.day - 1));
  Future<void> goToToday() => goToDay(DateTime.now());

  /// Aplica una transición de estado a una cita y recarga el día en silencio.
  /// Devuelve la falla si la mutación se rechazó (para que el detalle la
  /// anuncie), o null en éxito.
  Future<CalendarFailure?> setStatus(
    String id,
    AppointmentStatus status,
  ) async {
    emit(state.copyWith(mutating: true));
    try {
      await _repo.setAppointmentStatus(id: id, status: status);
    } on CalendarFailure catch (f) {
      emit(state.copyWith(mutating: false));
      return f;
    }
    await _refetchSilent();
    return null;
  }

  Future<void> _fetchInto(DateTime day) async {
    try {
      final appts = await _repo.appointments(from: day, to: _next(day));
      emit(
        state.copyWith(
          status: AgendaStatus.loaded,
          appointments: _sorted(appts),
          clearFailure: true,
          mutating: false,
        ),
      );
    } on CalendarFailure catch (f) {
      emit(
        state.copyWith(status: AgendaStatus.error, failure: f, mutating: false),
      );
    }
  }

  /// Recarga sin tocar el status (no vuelve a "loading"): la lista se refresca
  /// bajo el detalle sin parpadeo. Si el refetch falla, conserva la lista
  /// previa y solo baja [mutating].
  Future<void> _refetchSilent() async {
    try {
      final appts = await _repo.appointments(
        from: state.day,
        to: _next(state.day),
      );
      emit(
        state.copyWith(
          status: AgendaStatus.loaded,
          appointments: _sorted(appts),
          clearFailure: true,
          mutating: false,
        ),
      );
    } on CalendarFailure {
      emit(state.copyWith(mutating: false));
    }
  }

  static List<Appointment> _sorted(List<Appointment> appts) =>
      <Appointment>[...appts]..sort((a, b) => a.startAt.compareTo(b.startAt));
}

bool _listEquals(List<Appointment> a, List<Appointment> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
