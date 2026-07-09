import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/business_hours.dart';
import '../../domain/failures/calendar_failure.dart';
import '../../domain/repositories/calendar_repository.dart';

/// Editor del horario semanal de atención (Ajustes → Agenda). Mantiene un
/// conjunto de trabajo editable (`working`) frente a la última foto guardada
/// (`baseline`): de ahí sale `dirty` (hay cambios sin guardar). Guardar hace un
/// `PUT` de REEMPLAZO TOTAL del horario.
///
/// La validación de cruces la manda el backend (422), pero el editor también
/// la comprueba localmente (`isValid`) para deshabilitar «Guardar» y avisar en
/// el acto sin ida y vuelta.
enum BusinessHoursStatus { loading, loaded, error }

/// Tramo por defecto al agregar: 09:00–17:00 (minutos desde medianoche).
const int _defaultOpen = 540;
const int _defaultClose = 1020;

class BusinessHoursState {
  const BusinessHoursState({
    required this.status,
    required this.working,
    required this.baseline,
    required this.saving,
    required this.failure,
  });

  const BusinessHoursState.loading()
    : status = BusinessHoursStatus.loading,
      working = const <BusinessHoursSlot>[],
      baseline = const <BusinessHoursSlot>[],
      saving = false,
      failure = null;

  final BusinessHoursStatus status;
  final List<BusinessHoursSlot> working;
  final List<BusinessHoursSlot> baseline;
  final bool saving;
  final CalendarFailure? failure;

  /// Tramos del día [weekday] en orden de inserción.
  List<BusinessHoursSlot> slotsFor(int weekday) =>
      working.where((s) => s.weekday == weekday).toList(growable: false);

  /// Hay cambios sin guardar respecto de la última foto del backend.
  bool get dirty => !_listEquals(working, baseline);

  /// Todos los tramos son coherentes (apertura < cierre) y ningún par del
  /// mismo día se cruza.
  bool get isValid {
    for (final s in working) {
      if (s.openMin >= s.closeMin) return false;
    }
    for (var day = 0; day <= 6; day++) {
      final daySlots = slotsFor(day);
      for (var i = 0; i < daySlots.length; i++) {
        for (var j = i + 1; j < daySlots.length; j++) {
          if (_overlaps(daySlots[i], daySlots[j])) return false;
        }
      }
    }
    return true;
  }

  bool get canSave => dirty && isValid && !saving;

  static bool _overlaps(BusinessHoursSlot a, BusinessHoursSlot b) =>
      a.openMin < b.closeMin && b.openMin < a.closeMin;

  BusinessHoursState copyWith({
    BusinessHoursStatus? status,
    List<BusinessHoursSlot>? working,
    List<BusinessHoursSlot>? baseline,
    bool? saving,
    CalendarFailure? failure,
    bool clearFailure = false,
  }) => BusinessHoursState(
    status: status ?? this.status,
    working: working ?? this.working,
    baseline: baseline ?? this.baseline,
    saving: saving ?? this.saving,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BusinessHoursState &&
        other.status == status &&
        other.saving == saving &&
        other.failure == failure &&
        _listEquals(other.working, working) &&
        _listEquals(other.baseline, baseline);
  }

  @override
  int get hashCode => Object.hash(
    status,
    saving,
    failure,
    Object.hashAll(working),
    Object.hashAll(baseline),
  );
}

class BusinessHoursCubit extends Cubit<BusinessHoursState> {
  BusinessHoursCubit(this._repo) : super(const BusinessHoursState.loading());

  final CalendarRepository _repo;

  Future<void> load() async {
    emit(
      state.copyWith(status: BusinessHoursStatus.loading, clearFailure: true),
    );
    try {
      final hours = await _repo.getHours();
      emit(
        state.copyWith(
          status: BusinessHoursStatus.loaded,
          working: hours,
          baseline: hours,
        ),
      );
    } on CalendarFailure catch (f) {
      emit(state.copyWith(status: BusinessHoursStatus.error, failure: f));
    }
  }

  /// Agrega un tramo por defecto (09:00–17:00) al día [weekday].
  void addSlot(int weekday) => _setWorking(<BusinessHoursSlot>[
    ...state.working,
    BusinessHoursSlot(
      weekday: weekday,
      openMin: _defaultOpen,
      closeMin: _defaultClose,
    ),
  ]);

  /// Cierra el día [weekday]: quita todos sus tramos de una sola vez.
  void clearDay(int weekday) =>
      _setWorking(state.working.where((s) => s.weekday != weekday).toList());

  void removeSlotAt(int weekday, int indexInDay) {
    final next = <BusinessHoursSlot>[];
    var seen = 0;
    for (final s in state.working) {
      if (s.weekday == weekday) {
        if (seen == indexInDay) {
          seen++;
          continue; // se salta el tramo objetivo
        }
        seen++;
      }
      next.add(s);
    }
    _setWorking(next);
  }

  void updateSlotAt(
    int weekday,
    int indexInDay, {
    int? openMin,
    int? closeMin,
  }) {
    final next = <BusinessHoursSlot>[];
    var seen = 0;
    for (final s in state.working) {
      if (s.weekday == weekday && seen++ == indexInDay) {
        next.add(
          BusinessHoursSlot(
            weekday: weekday,
            openMin: openMin ?? s.openMin,
            closeMin: closeMin ?? s.closeMin,
          ),
        );
      } else {
        next.add(s);
      }
    }
    _setWorking(next);
  }

  /// Copia los tramos del día [from] a cada día de [to] (reemplazando los
  /// suyos). Copiar un día sobre sí mismo es un no-op (se excluye de [to]).
  void copyDay(int from, Set<int> to) {
    final targets = to.where((d) => d != from).toSet();
    if (targets.isEmpty) return;
    final source = state.slotsFor(from);
    final next = state.working
        .where((s) => !targets.contains(s.weekday))
        .toList();
    for (final target in targets) {
      for (final s in source) {
        next.add(s.forDay(target));
      }
    }
    _setWorking(next);
  }

  Future<CalendarFailure?> save() async {
    if (!state.canSave) return null;
    emit(state.copyWith(saving: true));
    try {
      await _repo.putHours(state.working);
    } on CalendarFailure catch (f) {
      emit(state.copyWith(saving: false));
      return f;
    }
    // Éxito: la foto guardada pasa a ser la nueva baseline (dirty ⇒ false).
    emit(state.copyWith(saving: false, baseline: state.working));
    return null;
  }

  void _setWorking(List<BusinessHoursSlot> next) =>
      emit(state.copyWith(working: next));
}

extension on BusinessHoursSlot {
  /// Copia el tramo cambiando solo el día.
  BusinessHoursSlot forDay(int weekday) =>
      BusinessHoursSlot(weekday: weekday, openMin: openMin, closeMin: closeMin);
}

bool _listEquals(List<BusinessHoursSlot> a, List<BusinessHoursSlot> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
