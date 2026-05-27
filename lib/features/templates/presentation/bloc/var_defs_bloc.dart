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
    on<VarDefsUpdateRequested>(_onUpdate);
    on<VarDefsDeleteRequested>(_onDelete);
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
    await _runMutation(emit, (version) async {
      // El POST devuelve la nueva def, pero el bloc refetchea el
      // listado completo después; descartamos el retorno.
      await _repo.addVarDef(
        templateId: _templateId,
        name: event.name,
        type: event.type,
        defaultValue: event.defaultValue,
        description: event.description,
        version: version,
      );
    });
  }

  Future<void> _onUpdate(
    VarDefsUpdateRequested event,
    Emitter<VarDefsState> emit,
  ) async {
    await _runMutation(
      emit,
      (version) => _repo.updateVarDef(
        varDefId: event.varDefId,
        version: version,
        name: event.name,
        defaultValue: event.defaultValue,
        description: event.description,
      ),
    );
  }

  Future<void> _onDelete(
    VarDefsDeleteRequested event,
    Emitter<VarDefsState> emit,
  ) async {
    await _runMutation(
      emit,
      (version) =>
          _repo.removeVarDef(varDefId: event.varDefId, version: version),
    );
  }

  /// Orquesta el ciclo común de una mutación de var-def:
  /// 1. lee snapshot vigente (Loaded o MutationFailed) — desde
  ///    Loading/Failed/Mutating ignora (no hay version para CAS),
  /// 2. emit Mutating(snapshot),
  /// 3. corre `mutate(version)` — failure ⇒ MutationFailed con el
  ///    snapshot intacto,
  /// 4. emit Loading + refetch — failure ⇒ Failed (NO enmascarar
  ///    success de la mutación; el server ya persistió).
  ///
  /// Add/Update/Delete sólo aportan el cuerpo de `mutate`; el shape
  /// del state machine es idéntico. La función recibe la version del
  /// snapshot — la mutación la usa como CAS contra el Template padre.
  Future<void> _runMutation(
    Emitter<VarDefsState> emit,
    Future<void> Function(int version) mutate,
  ) async {
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
      await mutate(snapshot.version);
    } on TemplatesFailure catch (f) {
      emit(VarDefsMutationFailed(snapshot.defs, snapshot.version, f));
      return;
    }
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

/// Pide editar una variable-definition existente. Los campos nullables
/// son only-changed: `null` ⇒ no-op del campo, `''` ⇒ clear explícito
/// (consistente con el patch `*string` del backend). Una mutación sin
/// ningún campo es válida pero no-op del lado servidor — la UI no debe
/// dispatcharlo.
class VarDefsUpdateRequested extends VarDefsEvent {
  const VarDefsUpdateRequested({
    required this.varDefId,
    this.name,
    this.defaultValue,
    this.description,
  });

  final String varDefId;
  final String? name;
  final String? defaultValue;
  final String? description;

  @override
  bool operator ==(Object other) =>
      other is VarDefsUpdateRequested &&
      other.varDefId == varDefId &&
      other.name == name &&
      other.defaultValue == defaultValue &&
      other.description == description;

  @override
  int get hashCode => Object.hash(varDefId, name, defaultValue, description);
}

/// Pide eliminar una variable-definition. El backend rechaza con 409
/// si algún bot ya tiene un valor para esta variable (E2 in-use); el
/// operador debe limpiar el valor en los bots primero. La UI confirma
/// antes de dispatchar (acción destructiva).
class VarDefsDeleteRequested extends VarDefsEvent {
  const VarDefsDeleteRequested({required this.varDefId});

  final String varDefId;

  @override
  bool operator ==(Object other) =>
      other is VarDefsDeleteRequested && other.varDefId == varDefId;

  @override
  int get hashCode => varDefId.hashCode;
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
