import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_thread_event_card.dart';
import '../../domain/entities/pa_tool_result.dart';

/// Tarjeta interactiva de un requires_confirmation: nombra los Bots impactados y
/// ofrece Confirmar/Cancelar. Confirmar dispara onConfirm (la página reenvía la
/// autorización al asistente, que re-llama el tool con confirm=true) y, tras
/// actuar, retira los botones para no permitir una doble confirmación.
class PaConfirmationCard extends StatefulWidget {
  const PaConfirmationCard({
    super.key,
    required this.result,
    required this.onConfirm,
  });

  final PaToolResult result;
  final VoidCallback onConfirm;

  @override
  State<PaConfirmationCard> createState() => _PaConfirmationCardState();
}

class _PaConfirmationCardState extends State<PaConfirmationCard> {
  // null = pendiente; true = confirmado; false = cancelado.
  bool? _decision;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bots = widget.result.bots;
    final n = bots.length;
    final lead = n > 0
        ? 'Esta acción afecta a $n bot${n == 1 ? '' : 's'}: ${bots.join(', ')}.'
        : 'Esta acción requiere tu confirmación.';
    return AppThreadEventCard(
      maxWidth: 520,
      fill: true,
      padding: const EdgeInsets.all(AppTokens.sp3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.help_outline,
                size: 16,
                color: AppTokens.primary,
              ),
              const SizedBox(width: AppTokens.sp2),
              Expanded(
                child: Text(
                  lead,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTokens.text1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.sp2),
          if (_decision == null)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                AppButton.text(
                  key: const Key('pa.confirm.cancel'),
                  label: 'Cancelar',
                  onPressed: () => setState(() => _decision = false),
                ),
                const SizedBox(width: AppTokens.sp2),
                AppButton.filled(
                  key: const Key('pa.confirm.accept'),
                  label: 'Confirmar',
                  onPressed: () {
                    widget.onConfirm();
                    setState(() => _decision = true);
                  },
                ),
              ],
            )
          else
            Text(
              _decision! ? 'Confirmado.' : 'Cancelado.',
              key: const Key('pa.confirm.outcome'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTokens.text2,
              ),
            ),
        ],
      ),
    );
  }
}

/// Tarjeta de una acción ejecutada por el asistente. Colapsada es un chip
/// centrado "Usó {toolName}"; si el resultado trae detalle (changeset o error)
/// muestra un chevron y expande al tocarlo dentro de la misma tarjeta. Sin
/// detalle, es un chip plano.
class PaExpandableToolCard extends StatefulWidget {
  const PaExpandableToolCard({super.key, required this.result});

  final PaToolResult result;

  @override
  State<PaExpandableToolCard> createState() => _PaExpandableToolCardState();
}

class _PaExpandableToolCardState extends State<PaExpandableToolCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final label = r.toolName.isNotEmpty
        ? 'Usó ${r.toolName}'
        : 'Acción ejecutada';
    final isError = r.errorKind.isNotEmpty;

    if (!r.hasDetail) {
      return AppThreadEventCard(
        child: AppThreadEventHeader(icon: Icons.bolt_outlined, label: label),
      );
    }

    return AppThreadEventCard(
      key: const Key('pa.tool_card.header'),
      maxWidth: 520,
      error: isError,
      expanded: _expanded,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppThreadEventHeader(
            icon: isError ? Icons.error_outline : Icons.bolt_outlined,
            label: label,
            error: isError,
            showChevron: true,
            expanded: _expanded,
          ),
          if (_expanded) ...<Widget>[
            const SizedBox(height: AppTokens.sp2),
            PaToolDetail(result: r),
          ],
        ],
      ),
    );
  }
}

/// Cuerpo de una tarjeta de tool: el error (si lo hay) o el changeset campo a
/// campo. Vive DENTRO de la tarjeta (la caja compartida ya aporta la superficie
/// y el borde), no como una caja aparte. Público para que la traza lo inyecte
/// como cuerpo de un nodo tool.
class PaToolDetail extends StatelessWidget {
  const PaToolDetail({super.key, required this.result});

  final PaToolResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (result.errorKind.isNotEmpty) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: AppTokens.danger,
          ),
          const SizedBox(width: AppTokens.sp2),
          Expanded(
            child: Text(
              paToolErrorCopy(result.errorKind),
              key: const Key('pa.tool_card.error'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTokens.text1,
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final c in result.changed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1 / 2),
            child: Text(
              '${c.field}: ${c.from} → ${c.to}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTokens.text1,
              ),
            ),
          ),
      ],
    );
  }
}
