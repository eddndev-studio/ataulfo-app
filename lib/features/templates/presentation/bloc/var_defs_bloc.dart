import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/variable_def.dart';
import '../../domain/failures/templates_failure.dart';
import '../../domain/repositories/templates_repository.dart';

/// Bloc del listado de variable-definitions de una Template (S03).
/// Vida del bloc atada a la ruta `/templates/:id`: se construye con el
/// templateId y arranca en `Loading` para no flashear Initial.
///
/// Separado del `TemplateDetailBloc` a propósito: una falla cargando las
/// var-defs NO debe ocultar el detalle de la plantilla (header, AIConfig,
/// prompt). El operador ve la Template y la sección "Variables" expone su
/// propio estado de error con retry.
class VarDefsBloc extends Bloc<VarDefsEvent, VarDefsState> {
  VarDefsBloc({required TemplatesRepository repo, required String templateId})
    : _repo = repo,
      _templateId = templateId,
      super(const VarDefsLoading()) {
    on<VarDefsLoadRequested>(_onLoad);
    on<VarDefsAddRequested>(_onAdd);
  }

  final TemplatesRepository _repo;
  final String _templateId;

  Future<void> _onLoad(
    VarDefsLoadRequested event,
    Emitter<VarDefsState> emit,
  ) async {
    if (state is! VarDefsLoading) {
      emit(const VarDefsLoading());
    }
    try {
      final res = await _repo.listVarDefs(_templateId);
      emit(VarDefsLoaded(res.defs, res.version));
    } on TemplatesFailure catch (f) {
      emit(VarDefsFailed(f));
    }
  }

  Future<void> _onAdd(
    VarDefsAddRequested event,
    Emitter<VarDefsState> emit,
  ) async {
    // El Add requiere la version del Template padre (CAS). Sólo es
    // legítimo desde Loaded — desde Loading/Failed/Mutating ignoramos
    // (la UI debería bloquear el botón, pero el bloc es defensivo).
    // MutationFailed sí permite retry: el snapshot anterior sigue
    // siendo válido para el siguiente intento.
    final current = state;
    final ({List<VariableDef> defs, int version}) snapshot;
    if (current is VarDefsLoaded) {
      snapshot = (defs: current.defs, version: current.version);
    } else if (current is VarDefsMutationFailed) {
      snapshot = (defs: current.defs, version: current.version);
    } else {
      return;
    }

    emit(VarDefsMutating(snapshot.defs, snapshot.version));
    try {
      await _repo.addVarDef(
        templateId: _templateId,
        name: event.name,
        type: event.type,
        defaultValue: event.defaultValue,
        description: event.description,
        version: snapshot.version,
      );
    } on TemplatesFailure catch (f) {
      emit(VarDefsMutationFailed(snapshot.defs, snapshot.version, f));
      return;
    }
    // Re-list para refrescar la nueva version del Template padre y la
    // posición real del nuevo def en el orden del backend. El POST
    // sólo devolvió la def, no el snapshot completo.
    //
    // Crítico: NO enmascarar success del POST si el refetch falla. La
    // mutación YA se persistió en el servidor; el snapshot local está
    // stale. Failed es el terminal honesto — el operador puede
    // reintentar el Load para refrescar.
    emit(const VarDefsLoading());
    try {
      final res = await _repo.listVarDefs(_templateId);
      emit(VarDefsLoaded(res.defs, res.version));
    } on TemplatesFailure catch (f) {
      emit(VarDefsFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class VarDefsEvent {
  const VarDefsEvent();
}

class VarDefsLoadRequested extends VarDefsEvent {
  const VarDefsLoadRequested();
  @override
  bool operator ==(Object other) => other is VarDefsLoadRequested;
  @override
  int get hashCode => (VarDefsLoadRequested).hashCode;
}

/// Pide agregar una nueva variable-definition a la Template. La version
/// del Template padre no viaja en el evento — el bloc la lee del state
/// Loaded vigente y la usa como CAS.
class VarDefsAddRequested extends VarDefsEvent {
  const VarDefsAddRequested({
    required this.name,
    required this.type,
    required this.defaultValue,
    required this.description,
  });

  final String name;
  final VarType type;
  final String defaultValue;
  final String description;

  @override
  bool operator ==(Object other) =>
      other is VarDefsAddRequested &&
      other.name == name &&
      other.type == type &&
      other.defaultValue == defaultValue &&
      other.description == description;

  @override
  int get hashCode => Object.hash(name, type, defaultValue, description);
}

// States --------------------------------------------------------------------

sealed class VarDefsState {
  const VarDefsState();
}

class VarDefsLoading extends VarDefsState {
  const VarDefsLoading();
  @override
  bool operator ==(Object other) => other is VarDefsLoading;
  @override
  int get hashCode => (VarDefsLoading).hashCode;
}

class VarDefsLoaded extends VarDefsState {
  const VarDefsLoaded(this.defs, this.version);

  final List<VariableDef> defs;

  /// Version vigente de la Template padre (CAS optimista). El editor CRUD
  /// la lee de aquí para mandarla en POST/PATCH/DELETE de var-defs. Sólo
  /// se refresca con un nuevo `LoadRequested` — el backend NO la devuelve
  /// en las mutaciones de var-defs, así que cada mutación termina con un
  /// refetch del listado.
  final int version;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VarDefsLoaded) return false;
    if (other.version != version) return false;
    if (other.defs.length != defs.length) return false;
    for (var i = 0; i < defs.length; i++) {
      if (other.defs[i] != defs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(version, Object.hashAll(defs));
}

class VarDefsFailed extends VarDefsState {
  const VarDefsFailed(this.failure);

  final TemplatesFailure failure;

  @override
  bool operator ==(Object other) =>
      other is VarDefsFailed && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}

/// Estado intermedio durante una mutación de var-def (add/update/remove).
/// Lleva el snapshot previo de la lista para que la UI no flashee a
/// Loading; se le puede dibujar un overlay/spinner local sin perder el
/// contexto visual del operador.
class VarDefsMutating extends VarDefsState {
  const VarDefsMutating(this.defs, this.version);

  final List<VariableDef> defs;
  final int version;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VarDefsMutating) return false;
    if (other.version != version) return false;
    if (other.defs.length != defs.length) return false;
    for (var i = 0; i < defs.length; i++) {
      if (other.defs[i] != defs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(version, Object.hashAll(defs));
}

/// Terminal de error de una mutación. Distinto de `VarDefsFailed`: NO
/// es un error del load inicial — la lista está cargada y visible, sólo
/// la mutación falló. La UI escucha este estado para mostrar el feedback
/// (snackbar genérico que cubre la conflación 409 del backend) y deja
/// al operador reintentar desde el mismo snapshot. Otra Load o Add
/// supera este estado.
class VarDefsMutationFailed extends VarDefsState {
  const VarDefsMutationFailed(this.defs, this.version, this.failure);

  final List<VariableDef> defs;
  final int version;
  final TemplatesFailure failure;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VarDefsMutationFailed) return false;
    if (other.version != version || other.failure != failure) return false;
    if (other.defs.length != defs.length) return false;
    for (var i = 0; i < defs.length; i++) {
      if (other.defs[i] != defs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(version, failure, Object.hashAll(defs));
}
