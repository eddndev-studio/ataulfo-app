import 'package:flutter/material.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../labels/domain/entities/label.dart';
import '../../../labels/presentation/widgets/label_dot.dart';

enum InboxLabelMutation { add, remove }

class InboxLabelAction {
  const InboxLabelAction({required this.labelId, required this.mutation});

  final String labelId;
  final InboxLabelMutation mutation;
}

/// Selector explícito de agregar/quitar una etiqueta interna. Cada operación
/// toca sólo el label elegido; las demás asociaciones del chat permanecen.
class InboxLabelActionSheet extends StatefulWidget {
  const InboxLabelActionSheet({super.key, required this.labels});

  final List<Label> labels;

  static Future<InboxLabelAction?> open(
    BuildContext context, {
    required List<Label> labels,
  }) => showAppBottomSheet<InboxLabelAction>(
    context,
    isScrollControlled: true,
    backgroundColor: AppTokens.surface1,
    builder: (_) => InboxLabelActionSheet(labels: labels),
  );

  @override
  State<InboxLabelActionSheet> createState() => _InboxLabelActionSheetState();
}

class _InboxLabelActionSheetState extends State<InboxLabelActionSheet> {
  InboxLabelMutation _mutation = InboxLabelMutation.add;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      key: const Key('inbox.labels.action_sheet'),
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp6,
        AppTokens.sp5,
        AppTokens.sp6,
        AppTokens.sp6 + context.sheetBottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Editar etiquetas', style: textTheme.titleLarge),
          const SizedBox(height: AppTokens.sp2),
          Text(
            'La acción se aplicará a las conversaciones seleccionadas.',
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp4),
          Wrap(
            spacing: AppTokens.sp2,
            children: <Widget>[
              AppChoiceChip(
                key: const Key('inbox.labels.mode.add'),
                label: 'Agregar',
                selected: _mutation == InboxLabelMutation.add,
                onSelected: (_) =>
                    setState(() => _mutation = InboxLabelMutation.add),
              ),
              AppChoiceChip(
                key: const Key('inbox.labels.mode.remove'),
                label: 'Quitar',
                selected: _mutation == InboxLabelMutation.remove,
                onSelected: (_) =>
                    setState(() => _mutation = InboxLabelMutation.remove),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.sp4),
          if (widget.labels.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.sp4),
              child: Text(
                'No hay etiquetas internas disponibles.',
                style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
              ),
            )
          else
            for (final label in widget.labels)
              _LabelActionTile(
                label: label,
                onTap: () => Navigator.of(
                  context,
                ).pop(InboxLabelAction(labelId: label.id, mutation: _mutation)),
              ),
        ],
      ),
    );
  }
}

class _LabelActionTile extends StatelessWidget {
  const _LabelActionTile({required this.label, required this.onTap});

  final Label label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: Key('inbox.labels.label.${label.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp3),
        child: Row(
          children: <Widget>[
            LabelDot(hex: label.color),
            const SizedBox(width: AppTokens.sp3),
            Expanded(child: Text(label.name)),
            const Icon(Icons.chevron_right, color: AppTokens.text2),
          ],
        ),
      ),
    ),
  );
}
