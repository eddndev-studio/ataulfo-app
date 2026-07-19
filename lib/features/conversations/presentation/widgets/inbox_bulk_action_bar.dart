import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';

/// Barra contextual de la selección múltiple. Mantiene juntas la cardinalidad,
/// la salida del modo selección y únicamente las acciones habilitadas en v0.53.
class InboxBulkActionBar extends StatelessWidget {
  const InboxBulkActionBar({
    super.key,
    required this.count,
    required this.isMutating,
    required this.canClearHistory,
    required this.onCancel,
    required this.onLabels,
    required this.onMarkRead,
    required this.onClearHistory,
  });

  final int count;
  final bool isMutating;
  final bool canClearHistory;
  final VoidCallback onCancel;
  final VoidCallback onLabels;
  final VoidCallback onMarkRead;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) {
    final countLabel = count == 1 ? '1 seleccionada' : '$count seleccionadas';
    return Semantics(
      key: const Key('inbox.selection.bar'),
      container: true,
      liveRegion: true,
      label: countLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTokens.surface2,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: AppTokens.divider),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.sp3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      countLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    key: const Key('inbox.selection.cancel'),
                    tooltip: 'Cancelar selección',
                    onPressed: isMutating ? null : onCancel,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.sp2),
              Wrap(
                spacing: AppTokens.sp2,
                runSpacing: AppTokens.sp2,
                children: <Widget>[
                  AppButton.tonal(
                    key: const Key('inbox.selection.labels'),
                    label: 'Etiquetas',
                    icon: Icons.label_outline,
                    onPressed: isMutating ? null : onLabels,
                  ),
                  AppButton.tonal(
                    key: const Key('inbox.selection.mark_read'),
                    label: 'Marcar atendidas',
                    icon: Icons.done_all,
                    onPressed: isMutating ? null : onMarkRead,
                  ),
                  if (canClearHistory)
                    AppButton.danger(
                      key: const Key('inbox.selection.clear_history'),
                      label: 'Vaciar historial',
                      icon: Icons.delete_sweep_outlined,
                      onPressed: isMutating ? null : onClearHistory,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
