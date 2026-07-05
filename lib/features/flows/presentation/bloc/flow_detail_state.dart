// Estados del FlowDetailBloc. Parte de la librería del bloc: la máquina
// sellada de estados vive en su archivo hermano para que la unidad quede
// legible sin inflar el archivo del orquestador.
part of 'flow_detail_bloc.dart';

sealed class FlowDetailState {
  const FlowDetailState();
}

class FlowDetailLoading extends FlowDetailState {
  const FlowDetailLoading();
  @override
  bool operator ==(Object other) => other is FlowDetailLoading;
  @override
  int get hashCode => (FlowDetailLoading).hashCode;
}

class FlowDetailLoaded extends FlowDetailState {
  const FlowDetailLoaded(
    this.flow,
    this.siblings, {
    required this.siblingsFailed,
  });

  final Flow flow;
  final List<Flow> siblings;

  /// `true` ⇒ siblings está vacío porque listFlows falló (no porque
  /// no haya otros flujos). La UI lo usa para mostrar un aviso "no
  /// pudimos cargar otros flujos" sin tirar la página.
  final bool siblingsFailed;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowDetailLoaded) return false;
    if (other.flow != flow || other.siblingsFailed != siblingsFailed) {
      return false;
    }
    if (other.siblings.length != siblings.length) return false;
    for (var i = 0; i < siblings.length; i++) {
      if (other.siblings[i] != siblings[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(flow, siblingsFailed, Object.hashAll(siblings));
}

/// El flujo fue eliminado por el operador. Terminal: no hay snapshot que
/// mostrar ni acción que reintentar — la página escucha este estado y
/// hace pop de regreso a la lista.
class FlowDetailDeleted extends FlowDetailState {
  const FlowDetailDeleted();
  @override
  bool operator ==(Object other) => other is FlowDetailDeleted;
  @override
  int get hashCode => (FlowDetailDeleted).hashCode;
}

class FlowDetailFailed extends FlowDetailState {
  const FlowDetailFailed(this.failure);

  final FlowsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is FlowDetailFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}

/// Mutación de la cabecera en vuelo (configuración, nombre, estado
/// activo o borrado). Preserva el snapshot anterior para que la UI siga
/// mostrando los valores actuales mientras dibuja un indicador de
/// progreso. Mismo trío de campos que `Loaded` para que la superficie
/// renderice igual.
class FlowDetailMutating extends FlowDetailState {
  const FlowDetailMutating(
    this.flow,
    this.siblings, {
    required this.siblingsFailed,
  });

  final Flow flow;
  final List<Flow> siblings;
  final bool siblingsFailed;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowDetailMutating) return false;
    if (other.flow != flow || other.siblingsFailed != siblingsFailed) {
      return false;
    }
    if (other.siblings.length != siblings.length) return false;
    for (var i = 0; i < siblings.length; i++) {
      if (other.siblings[i] != siblings[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(flow, siblingsFailed, Object.hashAll(siblings));
}

/// La mutación de la cabecera falló pero el snapshot anterior sigue
/// intacto. La superficie que la disparó muestra el failure (Conflict ⇒
/// "recarga", InvalidSettings ⇒ "revisa cooldown / límite") sin perder
/// el estado del form.
class FlowDetailMutationFailed extends FlowDetailState {
  const FlowDetailMutationFailed(
    this.flow,
    this.siblings,
    this.failure, {
    required this.siblingsFailed,
  });

  final Flow flow;
  final List<Flow> siblings;
  final FlowsFailure failure;
  final bool siblingsFailed;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowDetailMutationFailed) return false;
    if (other.flow != flow ||
        other.failure != failure ||
        other.siblingsFailed != siblingsFailed) {
      return false;
    }
    if (other.siblings.length != siblings.length) return false;
    for (var i = 0; i < siblings.length; i++) {
      if (other.siblings[i] != siblings[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(flow, failure, siblingsFailed, Object.hashAll(siblings));
}
