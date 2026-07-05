import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/failures/flows_failure.dart';

/// Copy contextual de un fallo de mutación dentro del sheet de composición:
/// cada cubo de [FlowsFailure] se traduce a una línea accionable en danger,
/// anclada por key para las pruebas. El condicional matiza el copy de paso
/// inválido (sus campos son horario y destinos, no un mensaje).
class StepFailureCopy extends StatelessWidget {
  const StepFailureCopy({
    super.key,
    required this.failure,
    required this.isConditionalTime,
  });

  final FlowsFailure failure;
  final bool isConditionalTime;

  @override
  Widget build(BuildContext context) {
    final (key, copy) = _resolve(failure, isConditionalTime);
    return Text(
      copy,
      key: Key(key),
      style: const TextStyle(color: AppTokens.danger),
    );
  }

  static (String key, String copy) _resolve(
    FlowsFailure f,
    bool isCT,
  ) => switch (f) {
    FlowsInvalidStepFailure() =>
      isCT
          ? (
              'step_edit.error.invalid_step.conditional',
              'Revisa horario o destinos del condicional.',
            )
          : (
              'step_edit.error.invalid_step',
              'Revisa los campos del paso: el mensaje no puede estar vacío.',
            ),
    FlowsForbiddenFailure() => (
      'step_edit.error.forbidden',
      'Tu rol no permite editar pasos. Pide acceso a un admin.',
    ),
    FlowsNetworkFailure() || FlowsTimeoutFailure() => (
      'step_edit.error.network',
      'Sin conexión con el servidor. Revisa tu red y reintenta.',
    ),
    FlowsStepNotFoundFailure() => (
      'step_edit.error.step_not_found',
      'Este paso ya no existe. Cierra y refresca la lista.',
    ),
    FlowsStepReferencedFailure() => (
      'step_edit.error.step_referenced',
      'Este paso es destino de un condicional. Cambia ese destino antes '
          'de eliminarlo.',
    ),
    FlowsNotFoundFailure() ||
    FlowsServerFailure() ||
    FlowsInvalidCreateFailure() ||
    FlowsInvalidSettingsFailure() ||
    FlowsConflictFailure() ||
    FlowsInvalidReorderFailure() ||
    UnknownFlowsFailure() => (
      'step_edit.error.generic',
      'No pudimos guardar el paso. Inténtalo de nuevo.',
    ),
  };
}
