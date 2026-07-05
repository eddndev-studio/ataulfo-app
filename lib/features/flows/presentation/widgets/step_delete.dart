import 'package:flutter/material.dart';

import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../domain/entities/step.dart' as fdom;
import 'step_edit_support.dart';

/// Confirmación de borrado de un paso, no contradictoria: si el paso es
/// destino de un condicional, el backend rechazaría el borrado (409), así
/// que la acción condenada NO se ofrece — el diálogo explica el bloqueo con
/// una CTA única "Entendido" y devuelve `false`. Solo un paso libre pasa por
/// la confirmación destructiva canónica.
///
/// Devuelve `true` únicamente cuando el operador confirmó un borrado viable;
/// el caller dispatcha la mutación.
Future<bool> confirmStepDelete(
  BuildContext context, {
  required String stepId,
  required List<fdom.Step> steps,
}) async {
  if (referencedByConditional(stepId, steps)) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('No se puede eliminar'),
        content: const Text(
          'Este paso es destino de un condicional del flujo. Para '
          'eliminarlo, primero cambia ese destino en el condicional.',
        ),
        actions: <Widget>[
          AppButton.filled(
            key: const Key('step_edit.delete_blocked.ok'),
            label: 'Entendido',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
    return false;
  }
  return showAppConfirmDialog(
    context,
    title: 'Eliminar paso',
    message: '¿Eliminar este paso? La acción no se puede deshacer.',
    confirmLabel: 'Eliminar',
    confirmKey: const Key('step_edit.delete_confirm.ok'),
    cancelKey: const Key('step_edit.delete_confirm.cancel'),
  );
}
