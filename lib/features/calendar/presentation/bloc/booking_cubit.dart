import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/event_type.dart';
import '../../domain/failures/calendar_failure.dart';
import '../../domain/repositories/calendar_repository.dart';

/// Flujo de reserva manual: elegir tipo de evento (solo activos) → fecha →
/// slot de disponibilidad → nombre + nota → crear. El cubit orquesta las
/// cargas dependientes (al elegir tipo+fecha pide disponibilidad) y expone el
/// estado que la página compone en pasos.
///
/// [book] devuelve la falla o null (éxito): un 409 significa que el hueco se
/// ocupó entre listar y reservar, y la página recarga los slots y avisa.
enum BookingTypesStatus { loading, loaded, error }

enum SlotsStatus { idle, loading, loaded, error }

class BookingState {
  const BookingState({
    required this.typesStatus,
    required this.eventTypes,
    required this.selectedEventType,
    required this.date,
    required this.slotsStatus,
    required this.slots,
    required this.selectedSlot,
    required this.submitting,
  });

  const BookingState.loading()
    : typesStatus = BookingTypesStatus.loading,
      eventTypes = const <EventType>[],
      selectedEventType = null,
      date = null,
      slotsStatus = SlotsStatus.idle,
      slots = const <DateTime>[],
      selectedSlot = null,
      submitting = false;

  final BookingTypesStatus typesStatus;

  /// Solo tipos ACTIVOS (los únicos reservables).
  final List<EventType> eventTypes;
  final EventType? selectedEventType;

  /// Día local elegido (sin hora).
  final DateTime? date;
  final SlotsStatus slotsStatus;

  /// Instantes de inicio libres (UTC) para el tipo+día elegidos.
  final List<DateTime> slots;
  final DateTime? selectedSlot;
  final bool submitting;

  bool get canPickDate => selectedEventType != null;
  bool get canPickSlot => selectedSlot != null;

  BookingState copyWith({
    BookingTypesStatus? typesStatus,
    List<EventType>? eventTypes,
    EventType? selectedEventType,
    DateTime? date,
    SlotsStatus? slotsStatus,
    List<DateTime>? slots,
    DateTime? selectedSlot,
    bool? submitting,
    bool clearSelectedSlot = false,
    bool clearDate = false,
  }) => BookingState(
    typesStatus: typesStatus ?? this.typesStatus,
    eventTypes: eventTypes ?? this.eventTypes,
    selectedEventType: selectedEventType ?? this.selectedEventType,
    date: clearDate ? null : (date ?? this.date),
    slotsStatus: slotsStatus ?? this.slotsStatus,
    slots: slots ?? this.slots,
    selectedSlot: clearSelectedSlot
        ? null
        : (selectedSlot ?? this.selectedSlot),
    submitting: submitting ?? this.submitting,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookingState &&
        other.typesStatus == typesStatus &&
        other.selectedEventType == selectedEventType &&
        other.date == date &&
        other.slotsStatus == slotsStatus &&
        other.selectedSlot == selectedSlot &&
        other.submitting == submitting &&
        _listEquals<EventType>(other.eventTypes, eventTypes) &&
        _listEquals<DateTime>(other.slots, slots);
  }

  @override
  int get hashCode => Object.hash(
    typesStatus,
    selectedEventType,
    date,
    slotsStatus,
    selectedSlot,
    submitting,
    Object.hashAll(eventTypes),
    Object.hashAll(slots),
  );
}

class BookingCubit extends Cubit<BookingState> {
  BookingCubit(this._repo) : super(const BookingState.loading());

  final CalendarRepository _repo;

  Future<void> loadEventTypes() async {
    emit(state.copyWith(typesStatus: BookingTypesStatus.loading));
    try {
      final all = await _repo.listEventTypes();
      emit(
        state.copyWith(
          typesStatus: BookingTypesStatus.loaded,
          eventTypes: all.where((e) => e.active).toList(growable: false),
        ),
      );
    } on CalendarFailure {
      emit(state.copyWith(typesStatus: BookingTypesStatus.error));
    }
  }

  /// Elige el tipo. Cambia la selección ⇒ olvida fecha, slots y slot elegido
  /// (la disponibilidad depende del tipo).
  void selectEventType(EventType et) {
    emit(
      state.copyWith(
        selectedEventType: et,
        clearDate: true,
        slots: const <DateTime>[],
        slotsStatus: SlotsStatus.idle,
        clearSelectedSlot: true,
      ),
    );
  }

  /// Elige la fecha y carga la disponibilidad de ese día para el tipo elegido.
  Future<void> selectDate(DateTime date) async {
    final et = state.selectedEventType;
    if (et == null) return;
    final day = DateTime(date.year, date.month, date.day);
    emit(
      state.copyWith(
        date: day,
        slotsStatus: SlotsStatus.loading,
        slots: const <DateTime>[],
        clearSelectedSlot: true,
      ),
    );
    await _loadAvailability(et.id, day);
  }

  /// Recarga la disponibilidad del tipo+día actuales (p. ej. tras un 409).
  Future<void> reloadAvailability() async {
    final et = state.selectedEventType;
    final day = state.date;
    if (et == null || day == null) return;
    emit(
      state.copyWith(slotsStatus: SlotsStatus.loading, clearSelectedSlot: true),
    );
    await _loadAvailability(et.id, day);
  }

  void selectSlot(DateTime slot) => emit(state.copyWith(selectedSlot: slot));

  /// Crea la cita con el tipo/slot/nombre/nota. Devuelve la falla o null.
  Future<CalendarFailure?> book({
    required String customerName,
    required String note,
  }) async {
    final et = state.selectedEventType;
    final slot = state.selectedSlot;
    if (et == null || slot == null) return null;
    emit(state.copyWith(submitting: true));
    try {
      await _repo.createAppointment(
        eventTypeId: et.id,
        start: slot,
        customerName: customerName,
        note: note,
      );
      emit(state.copyWith(submitting: false));
      return null;
    } on CalendarFailure catch (f) {
      emit(state.copyWith(submitting: false));
      return f;
    }
  }

  Future<void> _loadAvailability(String eventTypeId, DateTime day) async {
    try {
      final slots = await _repo.availability(
        eventTypeId: eventTypeId,
        date: day,
      );
      emit(state.copyWith(slotsStatus: SlotsStatus.loaded, slots: slots));
    } on CalendarFailure {
      emit(state.copyWith(slotsStatus: SlotsStatus.error));
    }
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
