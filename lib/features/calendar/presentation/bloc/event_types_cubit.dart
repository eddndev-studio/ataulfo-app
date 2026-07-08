import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/event_type.dart';
import '../../domain/failures/calendar_failure.dart';
import '../../domain/repositories/calendar_repository.dart';

/// Listado y edición de tipos de evento (Ajustes → Agenda). Las mutaciones
/// (crear/editar/activar) recargan la lista fresca del backend: la vista nunca
/// adivina el resultado de un POST/PUT. Devuelven la falla al llamador para
/// que el formulario decida (cerrarse o mostrar el error) sin acoplar el
/// cubit a la UI.
enum EventTypesStatus { loading, loaded, error }

class EventTypesState {
  const EventTypesState({
    required this.status,
    required this.items,
    required this.failure,
    required this.mutating,
  });

  const EventTypesState.loading()
    : status = EventTypesStatus.loading,
      items = const <EventType>[],
      failure = null,
      mutating = false;

  final EventTypesStatus status;
  final List<EventType> items;
  final CalendarFailure? failure;
  final bool mutating;

  EventTypesState copyWith({
    EventTypesStatus? status,
    List<EventType>? items,
    CalendarFailure? failure,
    bool clearFailure = false,
    bool? mutating,
  }) => EventTypesState(
    status: status ?? this.status,
    items: items ?? this.items,
    failure: clearFailure ? null : (failure ?? this.failure),
    mutating: mutating ?? this.mutating,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventTypesState &&
        other.status == status &&
        other.failure == failure &&
        other.mutating == mutating &&
        _listEquals(other.items, items);
  }

  @override
  int get hashCode =>
      Object.hash(status, failure, mutating, Object.hashAll(items));
}

class EventTypesCubit extends Cubit<EventTypesState> {
  EventTypesCubit(this._repo) : super(const EventTypesState.loading());

  final CalendarRepository _repo;

  Future<void> load() async {
    emit(state.copyWith(status: EventTypesStatus.loading, clearFailure: true));
    try {
      final items = await _repo.listEventTypes();
      emit(state.copyWith(status: EventTypesStatus.loaded, items: items));
    } on CalendarFailure catch (f) {
      emit(state.copyWith(status: EventTypesStatus.error, failure: f));
    }
  }

  Future<CalendarFailure?> create({
    required String name,
    required String description,
    required int durationMin,
  }) => _mutate(
    () => _repo.createEventType(
      name: name,
      description: description,
      durationMin: durationMin,
    ),
  );

  Future<CalendarFailure?> update({
    required String id,
    required String name,
    required String description,
    required int durationMin,
    required bool active,
  }) => _mutate(
    () => _repo.updateEventType(
      id: id,
      name: name,
      description: description,
      durationMin: durationMin,
      active: active,
    ),
  );

  /// Conveniencia: alterna `active` conservando el resto del tipo.
  Future<CalendarFailure?> setActive(EventType et, bool active) => update(
    id: et.id,
    name: et.name,
    description: et.description,
    durationMin: et.durationMin,
    active: active,
  );

  Future<CalendarFailure?> _mutate(Future<void> Function() op) async {
    if (state.mutating) return null;
    emit(state.copyWith(mutating: true));
    try {
      await op();
    } on CalendarFailure catch (f) {
      emit(state.copyWith(mutating: false));
      return f;
    }
    try {
      final items = await _repo.listEventTypes();
      emit(
        state.copyWith(
          status: EventTypesStatus.loaded,
          items: items,
          mutating: false,
          clearFailure: true,
        ),
      );
    } on CalendarFailure {
      emit(state.copyWith(mutating: false));
    }
    return null;
  }
}

bool _listEquals(List<EventType> a, List<EventType> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
