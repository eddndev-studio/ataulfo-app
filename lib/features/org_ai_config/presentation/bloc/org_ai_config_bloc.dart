import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../templates/domain/entities/template.dart';
import '../../domain/entities/org_ai_config.dart';
import '../../domain/failures/org_ai_config_failure.dart';
import '../../domain/repositories/org_ai_config_repository.dart';

/// Bloc de la config de IA de la org (ADMIN/OWNER). Page-scoped: dispara
/// `LoadRequested` al abrir. Mantiene un par baseline/working: las ediciones
/// (host por modelo, defaults) mutan `working`; `dirty` compara contra `saved`
/// para habilitar Guardar. Save hace PUT y re-asienta el baseline con lo que el
/// backend devuelve.
class OrgAiConfigBloc extends Bloc<OrgAiConfigEvent, OrgAiConfigState> {
  OrgAiConfigBloc(this._repo) : super(const OrgAiConfigInitial()) {
    on<OrgAiConfigLoadRequested>(_onLoad);
    on<OrgAiConfigHostChanged>(_onHostChanged);
    on<OrgAiConfigDefaultsChanged>(_onDefaultsChanged);
    on<OrgAiConfigSaveRequested>(_onSave);
  }

  final OrgAiConfigRepository _repo;

  Future<void> _onLoad(
    OrgAiConfigLoadRequested event,
    Emitter<OrgAiConfigState> emit,
  ) async {
    emit(const OrgAiConfigLoading());
    try {
      final cfg = await _repo.get();
      emit(OrgAiConfigLoaded(saved: cfg, working: cfg));
    } on OrgAiConfigFailure catch (f) {
      emit(OrgAiConfigLoadFailed(f));
    }
  }

  void _onHostChanged(
    OrgAiConfigHostChanged event,
    Emitter<OrgAiConfigState> emit,
  ) {
    final s = state;
    if (s is! OrgAiConfigLoaded) return;
    final next = event.host == null
        ? s.working.clearHost(event.model)
        : s.working.withHost(event.model, event.host!);
    emit(s.copyWith(working: next, clearSaveError: true));
  }

  void _onDefaultsChanged(
    OrgAiConfigDefaultsChanged event,
    Emitter<OrgAiConfigState> emit,
  ) {
    final s = state;
    if (s is! OrgAiConfigLoaded) return;
    emit(
      s.copyWith(
        working: s.working.withDefaults(event.defaults),
        clearSaveError: true,
      ),
    );
  }

  Future<void> _onSave(
    OrgAiConfigSaveRequested event,
    Emitter<OrgAiConfigState> emit,
  ) async {
    final s = state;
    if (s is! OrgAiConfigLoaded || s.saving) return;
    emit(s.copyWith(saving: true, clearSaveError: true));
    try {
      final saved = await _repo.update(s.working);
      emit(OrgAiConfigLoaded(saved: saved, working: saved));
    } on OrgAiConfigFailure catch (f) {
      emit(s.copyWith(saving: false, saveError: f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class OrgAiConfigEvent {
  const OrgAiConfigEvent();
}

class OrgAiConfigLoadRequested extends OrgAiConfigEvent {
  const OrgAiConfigLoadRequested();
  @override
  bool operator ==(Object other) => other is OrgAiConfigLoadRequested;
  @override
  int get hashCode => (OrgAiConfigLoadRequested).hashCode;
}

/// Fija (`host` no-null) o quita (`host` null ⇒ vuelve al default) el host de
/// un modelo.
class OrgAiConfigHostChanged extends OrgAiConfigEvent {
  const OrgAiConfigHostChanged({required this.model, required this.host});

  final String model;
  final String? host;

  @override
  bool operator ==(Object other) =>
      other is OrgAiConfigHostChanged &&
      other.model == model &&
      other.host == host;
  @override
  int get hashCode => Object.hash(model, host);
}

class OrgAiConfigDefaultsChanged extends OrgAiConfigEvent {
  const OrgAiConfigDefaultsChanged(this.defaults);

  final AIConfig defaults;

  @override
  bool operator ==(Object other) =>
      other is OrgAiConfigDefaultsChanged && other.defaults == defaults;
  @override
  int get hashCode => defaults.hashCode;
}

class OrgAiConfigSaveRequested extends OrgAiConfigEvent {
  const OrgAiConfigSaveRequested();
  @override
  bool operator ==(Object other) => other is OrgAiConfigSaveRequested;
  @override
  int get hashCode => (OrgAiConfigSaveRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class OrgAiConfigState {
  const OrgAiConfigState();
}

class OrgAiConfigInitial extends OrgAiConfigState {
  const OrgAiConfigInitial();
  @override
  bool operator ==(Object other) => other is OrgAiConfigInitial;
  @override
  int get hashCode => (OrgAiConfigInitial).hashCode;
}

class OrgAiConfigLoading extends OrgAiConfigState {
  const OrgAiConfigLoading();
  @override
  bool operator ==(Object other) => other is OrgAiConfigLoading;
  @override
  int get hashCode => (OrgAiConfigLoading).hashCode;
}

class OrgAiConfigLoaded extends OrgAiConfigState {
  const OrgAiConfigLoaded({
    required this.saved,
    required this.working,
    this.saving = false,
    this.saveError,
  });

  /// Último estado confirmado por el backend (baseline del dirty).
  final OrgAiConfig saved;

  /// Edición en curso (lo que se enviará al guardar).
  final OrgAiConfig working;

  final bool saving;
  final OrgAiConfigFailure? saveError;

  /// Hay cambios sin guardar.
  bool get dirty => working != saved;

  OrgAiConfigLoaded copyWith({
    OrgAiConfig? saved,
    OrgAiConfig? working,
    bool? saving,
    OrgAiConfigFailure? saveError,
    bool clearSaveError = false,
  }) => OrgAiConfigLoaded(
    saved: saved ?? this.saved,
    working: working ?? this.working,
    saving: saving ?? this.saving,
    saveError: clearSaveError ? null : (saveError ?? this.saveError),
  );

  @override
  bool operator ==(Object other) =>
      other is OrgAiConfigLoaded &&
      other.saved == saved &&
      other.working == working &&
      other.saving == saving &&
      other.saveError == saveError;

  @override
  int get hashCode => Object.hash(saved, working, saving, saveError);
}

class OrgAiConfigLoadFailed extends OrgAiConfigState {
  const OrgAiConfigLoadFailed(this.failure);

  final OrgAiConfigFailure failure;

  @override
  bool operator ==(Object other) =>
      other is OrgAiConfigLoadFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
