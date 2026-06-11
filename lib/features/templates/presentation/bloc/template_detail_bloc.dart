import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/template.dart';
import '../../domain/failures/templates_failure.dart';
import '../../domain/repositories/templates_repository.dart';

/// Bloc del detalle de una Template (S03). Vida del bloc atada a la ruta
/// `/templates/:id`: se construye con el ID y arranca en `Loading` para que
/// la página tenga spinner desde el primer frame (sin flash de Initial).
///
/// Hoy NO consume seed desde el `TemplatesBloc` del listado — siempre golpea
/// `repo.byId`. Cuando aterrice la cache (RFC-0001), el repositorio
/// devolverá la template local instantánea y orquestará el refetch contra
/// el backend; ese cambio queda confinado a la capa data.
class TemplateDetailBloc
    extends Bloc<TemplateDetailEvent, TemplateDetailState> {
  TemplateDetailBloc({required TemplatesRepository repo, required String id})
    : _repo = repo,
      _id = id,
      super(const TemplateDetailLoading()) {
    on<TemplateDetailLoadRequested>(_onLoad);
    on<TemplateDetailRenameRequested>(_onRename);
    on<TemplateDetailAiUpdateRequested>(_onAiUpdate);
  }

  final TemplatesRepository _repo;
  final String _id;

  /// Snapshot mutable de base: solo Loaded/MutationFailed traen una
  /// Template con versión CAS sobre la cual editar.
  Template? get _snapshot => switch (state) {
    TemplateDetailLoaded(template: final t) => t,
    TemplateDetailMutationFailed(template: final t) => t,
    _ => null,
  };

  Future<void> _onRename(
    TemplateDetailRenameRequested event,
    Emitter<TemplateDetailState> emit,
  ) async {
    final t = _snapshot;
    if (t == null) return;
    emit(TemplateDetailMutating(t));
    try {
      // ai:null deja la config IA intacta — renombrar NO toca el motor
      // (separación de responsabilidades: el motor se edita en su página).
      final updated = await _repo.update(
        id: _id,
        name: event.name,
        version: t.version,
        ai: null,
      );
      emit(TemplateDetailLoaded(updated));
    } on TemplatesConflictFailure catch (f) {
      // CAS stale: refresca para que el siguiente intento parta de la
      // versión nueva. Si el re-GET también falla, conserva el snapshot.
      try {
        final refreshed = await _repo.byId(_id);
        emit(TemplateDetailMutationFailed(refreshed, f));
      } on TemplatesFailure {
        emit(TemplateDetailMutationFailed(t, f));
      }
    } on TemplatesFailure catch (f) {
      emit(TemplateDetailMutationFailed(t, f));
    }
  }

  Future<void> _onAiUpdate(
    TemplateDetailAiUpdateRequested event,
    Emitter<TemplateDetailState> emit,
  ) async {
    final t = _snapshot;
    if (t == null) return;
    emit(TemplateDetailMutating(t));
    try {
      // El name viaja INTACTO: editar el motor no renombra (el rename
      // tiene su propio evento y su propio sheet).
      final updated = await _repo.update(
        id: _id,
        name: t.name,
        version: t.version,
        ai: event.ai,
      );
      emit(TemplateDetailLoaded(updated));
    } on TemplatesConflictFailure catch (f) {
      try {
        final refreshed = await _repo.byId(_id);
        emit(TemplateDetailMutationFailed(refreshed, f));
      } on TemplatesFailure {
        emit(TemplateDetailMutationFailed(t, f));
      }
    } on TemplatesFailure catch (f) {
      emit(TemplateDetailMutationFailed(t, f));
    }
  }

  Future<void> _onLoad(
    TemplateDetailLoadRequested event,
    Emitter<TemplateDetailState> emit,
  ) async {
    // Sólo emitimos Loading si venimos de un estado distinto (retry desde
    // Failed o Loaded). Si ya estamos en Loading — caso del primer load
    // post-construcción — evitar la emisión duplicada mantiene el stream
    // limpio para los suscriptores.
    if (state is! TemplateDetailLoading) {
      emit(const TemplateDetailLoading());
    }
    try {
      final tpl = await _repo.byId(_id);
      emit(TemplateDetailLoaded(tpl));
    } on TemplatesFailure catch (f) {
      emit(TemplateDetailFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class TemplateDetailEvent {
  const TemplateDetailEvent();
}

class TemplateDetailLoadRequested extends TemplateDetailEvent {
  const TemplateDetailLoadRequested();
  @override
  bool operator ==(Object other) => other is TemplateDetailLoadRequested;
  @override
  int get hashCode => (TemplateDetailLoadRequested).hashCode;
}

/// Renombra la plantilla (PUT con CAS, `ai:null` ⇒ motor intacto).
class TemplateDetailRenameRequested extends TemplateDetailEvent {
  const TemplateDetailRenameRequested(this.name);

  final String name;

  @override
  bool operator ==(Object other) =>
      other is TemplateDetailRenameRequested && other.name == name;
  @override
  int get hashCode => name.hashCode;
}

/// Actualiza la config del Motor IA (PUT con CAS; el `name` viaja intacto).
class TemplateDetailAiUpdateRequested extends TemplateDetailEvent {
  const TemplateDetailAiUpdateRequested(this.ai);

  final AIConfig ai;

  @override
  bool operator ==(Object other) =>
      other is TemplateDetailAiUpdateRequested && other.ai == ai;
  @override
  int get hashCode => ai.hashCode;
}

// States --------------------------------------------------------------------

sealed class TemplateDetailState {
  const TemplateDetailState();
}

class TemplateDetailLoading extends TemplateDetailState {
  const TemplateDetailLoading();
  @override
  bool operator ==(Object other) => other is TemplateDetailLoading;
  @override
  int get hashCode => (TemplateDetailLoading).hashCode;
}

class TemplateDetailLoaded extends TemplateDetailState {
  const TemplateDetailLoaded(this.template);

  final Template template;

  @override
  bool operator ==(Object other) =>
      other is TemplateDetailLoaded && other.template == template;
  @override
  int get hashCode => template.hashCode;
}

class TemplateDetailFailed extends TemplateDetailState {
  const TemplateDetailFailed(this.failure);

  final TemplatesFailure failure;

  @override
  bool operator ==(Object other) =>
      other is TemplateDetailFailed && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}

/// PUT en vuelo. Conserva el snapshot para que la UI siga pintando el
/// detalle (sin flash a Loading) mientras la mutación corre.
class TemplateDetailMutating extends TemplateDetailState {
  const TemplateDetailMutating(this.template);

  final Template template;

  @override
  bool operator ==(Object other) =>
      other is TemplateDetailMutating && other.template == template;
  @override
  int get hashCode => template.hashCode;
}

/// La mutación falló. `template` es la base del siguiente intento — tras un
/// 409 viene REFRESCADA del re-GET (versión CAS nueva).
class TemplateDetailMutationFailed extends TemplateDetailState {
  const TemplateDetailMutationFailed(this.template, this.failure);

  final Template template;
  final TemplatesFailure failure;

  @override
  bool operator ==(Object other) =>
      other is TemplateDetailMutationFailed &&
      other.template == template &&
      other.failure == failure;
  @override
  int get hashCode => Object.hash(template, failure);
}
