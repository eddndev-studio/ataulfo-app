import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../media/domain/entities/media_asset.dart';
import '../../domain/entities/conditional_time_metadata.dart';
import '../../domain/entities/label_step_metadata.dart';
import '../../domain/entities/step.dart' as fdom;
import 'conditional_time_form.dart';
import 'label_step_form.dart';
import 'step_edit_support.dart';
import 'step_media_field.dart';
import 'step_type_label.dart';
import 'step_type_selector.dart';

/// Header de identidad del sheet de composición, SIEMPRE visible: al crear,
/// el título nombra el tipo elegido en el selector ("Nuevo paso · Imagen");
/// al editar, el tipo —antes oculto— se muestra como pill junto a "Editar
/// paso" y una caption explica por qué es inmutable. La acción de borrado
/// solo existe en edición.
class StepEditHeader extends StatelessWidget {
  const StepEditHeader({
    super.key,
    required this.type,
    required this.isEditing,
    required this.enabled,
    required this.onDelete,
  });

  final fdom.StepType type;
  final bool isEditing;
  final bool enabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (!isEditing) {
      return Text(
        'Nuevo paso · ${stepTypeLabel(type)}',
        style: textTheme.titleLarge,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('Editar paso', style: textTheme.titleLarge),
            const SizedBox(width: AppTokens.sp3),
            AppPill.outline(
              key: const Key('step_edit.type_pill'),
              label: stepTypeLabel(type),
              icon: stepTypeGlyph(type),
            ),
            const Spacer(),
            IconButton(
              key: const Key('step_edit.delete'),
              tooltip: 'Eliminar paso',
              icon: const Icon(Icons.delete_outline, color: AppTokens.danger),
              onPressed: enabled ? onDelete : null,
            ),
          ],
        ),
        const SizedBox(height: AppTokens.sp1),
        Text(
          'El tipo se fija al crear el paso; para usar otro, crea un '
          'paso nuevo.',
          key: const Key('step_edit.type_caption'),
          style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
        ),
      ],
    );
  }
}

/// Pie del sheet de composición: Cancelar + Guardar. Cancelar pasa por
/// `maybePop`, es decir por el guard de descarte del sheet — con cambios
/// pide confirmación; sin cambios cierra directo. Guardar se deshabilita
/// sin campos válidos y muestra progreso durante la mutación.
class StepEditFooter extends StatelessWidget {
  const StepEditFooter({
    super.key,
    required this.isMutating,
    required this.canSubmit,
    required this.onSubmit,
  });

  final bool isMutating;
  final bool canSubmit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: AppButton.tonal(
            key: const Key('step_edit.cancel'),
            label: 'Cancelar',
            onPressed: isMutating
                ? null
                : () => Navigator.of(context).maybePop(),
          ),
        ),
        const SizedBox(width: AppTokens.sp3),
        Expanded(
          child: AppButton.filled(
            key: const Key('step_edit.submit'),
            label: 'Guardar',
            onPressed: canSubmit ? onSubmit : null,
            loading: isMutating,
          ),
        ),
      ],
    );
  }
}

/// Campo principal del tipo, PRIMERO en el cuerpo del sheet: mensaje para
/// TEXT, recurso + caption para multimedia, form propio para CT/LABEL y el
/// resumen de comportamiento para END. El estado (controllers, metadata
/// emitida) vive en el sheet; este widget solo despacha por familia.
class StepMainField extends StatelessWidget {
  const StepMainField({
    super.key,
    required this.type,
    required this.enabled,
    required this.contentController,
    required this.mediaController,
    required this.pickMediaRef,
    required this.onMediaPicked,
    required this.ctInitial,
    required this.ctRecovered,
    required this.ctTargets,
    required this.onCtChanged,
    required this.labelInitial,
    required this.onLabelChanged,
  });

  final fdom.StepType type;
  final bool enabled;
  final TextEditingController contentController;
  final TextEditingController mediaController;
  final MediaRefPicker? pickMediaRef;
  final ValueChanged<MediaAsset> onMediaPicked;
  final ConditionalTimeMetadata? ctInitial;
  final bool ctRecovered;
  final List<CtTargetOption> ctTargets;
  final ValueChanged<String?> onCtChanged;
  final LabelStepMetadata? labelInitial;
  final ValueChanged<String?> onLabelChanged;

  bool get _isMultimedia => type.isMultimediaStep;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (type == fdom.StepType.conditionalTime) {
      return ConditionalTimeForm(
        key: const Key('step_edit.ct_form'),
        initial: ctInitial,
        targets: ctTargets,
        enabled: enabled,
        showRecoveredWarning: ctRecovered,
        onChanged: onCtChanged,
      );
    }
    if (type == fdom.StepType.end) {
      return Text(
        'El flujo termina al llegar a este paso. Úsalo para '
        'cerrar la rama de un condicional: sin él, la rama '
        'continúa con los pasos siguientes.',
        key: const Key('step_edit.end_helper'),
        style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
      );
    }
    if (type == fdom.StepType.label) {
      return LabelStepForm(
        initial: labelInitial,
        enabled: enabled,
        onChanged: onLabelChanged,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_isMultimedia) ...<Widget>[
          StepMediaField(
            controller: mediaController,
            // Tanto al crear como al editar el selector es interactivo: en
            // edición el operador puede reemplazar el recurso (el ref BARE
            // resultante viaja en el PATCH). Sin `pickMediaRef` el selector
            // no abre nada — el sheet sigue usable aislado.
            pickMediaRef: pickMediaRef,
            // La galería-picker se abre filtrada por la familia del tipo
            // del paso (alineación tipo↔asset).
            family: stepMediaFamilyFor(type),
            onPicked: onMediaPicked,
            enabled: enabled,
          ),
          const SizedBox(height: AppTokens.sp4),
        ],
        AppTextField(
          key: const Key('step_edit.content'),
          label: _isMultimedia ? 'Caption (opcional)' : 'Mensaje',
          hint: _isMultimedia
              ? 'Texto que acompaña al recurso (opcional)'
              : 'Lo que el bot enviará al usuario',
          controller: contentController,
          enabled: enabled,
          autofocus: !_isMultimedia,
          maxLines: 4,
        ),
      ],
    );
  }
}
