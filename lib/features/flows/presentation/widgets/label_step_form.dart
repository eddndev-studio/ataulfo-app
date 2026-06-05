import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../labels/presentation/widgets/label_picker.dart';
import '../../domain/entities/label_step_metadata.dart';

/// Editor del cuerpo de un paso LABEL (S11): elige la etiqueta interna (vía
/// [LabelPicker], que consume el `LabelsBloc` del scope) y la acción
/// ADD/REMOVE. Emite por [onChanged] el `metadataJson` `{label_id, action}`
/// listo para persistir, o `null` mientras no haya etiqueta elegida — el sheet
/// gatea el submit con eso, igual que el form de CONDITIONAL_TIME.
///
/// Requiere un `LabelsBloc` en el scope del context (lo provee el editor de
/// pasos al abrir el sheet).
class LabelStepForm extends StatefulWidget {
  const LabelStepForm({
    super.key,
    required this.initial,
    required this.enabled,
    required this.onChanged,
  });

  /// Metadata hidratada al editar (null en creación o si el parse del metadata
  /// guardado falló — el form arranca en ADD sin selección).
  final LabelStepMetadata? initial;
  final bool enabled;

  /// Emite el metadataJson actual, o null si aún no hay etiqueta seleccionada.
  final ValueChanged<String?> onChanged;

  @override
  State<LabelStepForm> createState() => _LabelStepFormState();
}

class _LabelStepFormState extends State<LabelStepForm> {
  String? _labelId;
  late LabelStepAction _action;

  @override
  void initState() {
    super.initState();
    _labelId = widget.initial?.labelId;
    _action = widget.initial?.action ?? LabelStepAction.add;
    // Emite el estado inicial tras el primer frame para que el sheet hidrate
    // su gate de submit (un edit con metadata válida arranca submittable).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emit();
    });
  }

  void _emit() {
    final id = _labelId?.trim();
    if (id == null || id.isEmpty) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(
      LabelStepMetadata(labelId: id, action: _action).toJsonString(),
    );
  }

  void _onLabelSelected(String id) {
    setState(() => _labelId = id);
    _emit();
  }

  void _onActionSelected(LabelStepAction a) {
    setState(() => _action = a);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      key: const Key('step_edit.label_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LabelPicker(
          keyPrefix: 'step_edit.label_picker',
          selectedLabelId: _labelId,
          enabled: widget.enabled,
          onSelected: _onLabelSelected,
        ),
        const SizedBox(height: AppTokens.sp4),
        Text(
          'Acción',
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp2),
        Wrap(
          spacing: AppTokens.sp2,
          children: <Widget>[
            AppChoiceChip(
              key: const Key('step_edit.label_action.add'),
              label: 'Etiquetar',
              selected: _action == LabelStepAction.add,
              onSelected: widget.enabled
                  ? (_) => _onActionSelected(LabelStepAction.add)
                  : null,
            ),
            AppChoiceChip(
              key: const Key('step_edit.label_action.remove'),
              label: 'Quitar etiqueta',
              selected: _action == LabelStepAction.remove,
              onSelected: widget.enabled
                  ? (_) => _onActionSelected(LabelStepAction.remove)
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
