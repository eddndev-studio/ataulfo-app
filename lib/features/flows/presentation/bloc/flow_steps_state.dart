// Estados del FlowStepsBloc. Parte de la librería del bloc: la máquina
// de estados sellada vive en su archivo hermano para que la unidad
// quede legible sin inflar el archivo del orquestador.
part of 'flow_steps_bloc.dart';

sealed class FlowStepsState {
  const FlowStepsState();
}

class FlowStepsLoading extends FlowStepsState {
  const FlowStepsLoading();
  @override
  bool operator ==(Object other) => other is FlowStepsLoading;
  @override
  int get hashCode => (FlowStepsLoading).hashCode;
}

class FlowStepsLoaded extends FlowStepsState {
  const FlowStepsLoaded(this.steps);

  final List<fdom.Step> steps;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowStepsLoaded) return false;
    if (other.steps.length != steps.length) return false;
    for (var i = 0; i < steps.length; i++) {
      if (other.steps[i] != steps[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(steps);
}

class FlowStepsFailed extends FlowStepsState {
  const FlowStepsFailed(this.failure);

  final FlowsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is FlowStepsFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}

/// Lista vigente durante una mutación. La UI muestra la lista intacta y
/// gates el botón de añadir / sheet en loading para evitar enviar dos
/// requests sobre el mismo snapshot.
class FlowStepsMutating extends FlowStepsState {
  const FlowStepsMutating(this.steps);

  final List<fdom.Step> steps;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowStepsMutating) return false;
    if (other.steps.length != steps.length) return false;
    for (var i = 0; i < steps.length; i++) {
      if (other.steps[i] != steps[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(steps);
}

/// La mutación ya PERSISTIÓ y el refetch del listado corre con la lista
/// visible intacta. Distinto de [FlowStepsMutating] (el request de la
/// mutación aún puede fallar) y de [FlowStepsLoading] (sin lista que
/// mostrar): quien espera confirmación de la mutación —p. ej. el sheet
/// de edición— puede cerrarse en cuanto ve este estado.
class FlowStepsRefreshing extends FlowStepsState {
  const FlowStepsRefreshing(this.steps);

  final List<fdom.Step> steps;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowStepsRefreshing) return false;
    if (other.steps.length != steps.length) return false;
    for (var i = 0; i < steps.length; i++) {
      if (other.steps[i] != steps[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(steps);
}

/// La mutación PERSISTIÓ pero el refetch posterior falló: la lista
/// visible (posiblemente desactualizada) se conserva y la UI ofrece
/// reintentar el listado vía [FlowStepsRefreshRequested]. Distinto de
/// [FlowStepsMutationFailed] (nada persistió) y de [FlowStepsFailed]
/// (no hay lista que conservar).
class FlowStepsRefreshFailed extends FlowStepsState {
  const FlowStepsRefreshFailed(this.steps, this.failure);

  final List<fdom.Step> steps;
  final FlowsFailure failure;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowStepsRefreshFailed) return false;
    if (other.failure != failure) return false;
    if (other.steps.length != steps.length) return false;
    for (var i = 0; i < steps.length; i++) {
      if (other.steps[i] != steps[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(failure, Object.hashAll(steps));
}

/// Mutación falló pero la lista anterior sigue intacta — la UI reabre
/// el sheet o muestra snackbar para que el operador reintente con el
/// mismo o distinto input. Distinto de Failed (load), que es terminal.
class FlowStepsMutationFailed extends FlowStepsState {
  const FlowStepsMutationFailed(this.steps, this.failure);

  final List<fdom.Step> steps;
  final FlowsFailure failure;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FlowStepsMutationFailed) return false;
    if (other.failure != failure) return false;
    if (other.steps.length != steps.length) return false;
    for (var i = 0; i < steps.length; i++) {
      if (other.steps[i] != steps[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(failure, Object.hashAll(steps));
}
