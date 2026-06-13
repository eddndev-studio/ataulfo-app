import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../labels/domain/entities/label.dart';
import '../../../labels/presentation/bloc/labels_bloc.dart';
import '../../../labels/presentation/widgets/label_dot.dart';

/// Multi-select de etiquetas de la organización ante cuya presencia el motor
/// IA debe guardar silencio (gate de silencio de la plantilla). Reusa el
/// catálogo org-scoped (`LabelsBloc`, `GET /labels`). Al guardar hace `pop`
/// con la lista de ids elegidos; cancelar no hace pop (no toca la config).
///
/// Requiere un `LabelsBloc` en el scope (el call site lo provee con
/// `BlocProvider.value`). Un id ya seleccionado que ya no está en el catálogo
/// (etiqueta borrada) NO se descarta en silencio: se muestra como fila
/// "eliminada", removible, y se conserva si el operador no la quita.
class SilenceLabelsSheet extends StatefulWidget {
  const SilenceLabelsSheet({super.key, required this.initialSelectedIds});

  final List<String> initialSelectedIds;

  @override
  State<SilenceLabelsSheet> createState() => _SilenceLabelsSheetState();
}

class _SilenceLabelsSheetState extends State<SilenceLabelsSheet> {
  late final Set<String> _selected = <String>{...widget.initialSelectedIds};

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  /// Resultado determinista: las del catálogo en su orden, luego las
  /// seleccionadas que ya no existen en él (preservadas, no descartadas).
  List<String> _result(List<Label> catalog) {
    final known = catalog.map((l) => l.id).toSet();
    return <String>[
      for (final l in catalog)
        if (_selected.contains(l.id)) l.id,
      for (final id in widget.initialSelectedIds)
        if (!known.contains(id) && _selected.contains(id)) id,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp6,
          AppTokens.sp6,
          AppTokens.sp6,
          AppTokens.sp6 + context.sheetBottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Etiquetas de silencio', style: textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              'Cuando el chat tenga alguna de estas etiquetas, el bot no '
              'responderá: el control queda en manos de una persona.',
              style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp4),
            Flexible(
              child: BlocBuilder<LabelsBloc, LabelsState>(
                builder: (context, state) => switch (state) {
                  LabelsLoading() => const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppTokens.sp6),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  LabelsFailed() => const _ErrorRetry(),
                  LabelsLoaded(labels: final ls) => _options(ls, textTheme),
                },
              ),
            ),
            const SizedBox(height: AppTokens.sp4),
            BlocBuilder<LabelsBloc, LabelsState>(
              builder: (context, state) => AppButton.filled(
                key: const Key('template_ai.sheet.silence.save'),
                label: 'Guardar',
                fullWidth: true,
                // Solo guardable con el catálogo cargado: el resultado se arma
                // contra él (saber qué ids son "huérfanos" exige conocerlo).
                onPressed: state is LabelsLoaded
                    ? () => Navigator.of(context).pop(_result(state.labels))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _options(List<Label> labels, TextTheme textTheme) {
    final known = labels.map((l) => l.id).toSet();
    final orphans = widget.initialSelectedIds
        .where((id) => !known.contains(id) && _selected.contains(id))
        .toList(growable: false);

    if (labels.isEmpty && orphans.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp4),
        child: Text(
          'Aún no hay etiquetas. Crea una primero en la sección de etiquetas.',
          key: const Key('template_ai.sheet.silence.empty'),
          style: textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: AppTokens.text2,
          ),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      children: <Widget>[
        for (final id in orphans)
          _OrphanRow(rawId: id, onRemove: () => _toggle(id)),
        for (final l in labels)
          _CheckRow(
            label: l,
            selected: _selected.contains(l.id),
            onTap: () => _toggle(l.id),
          ),
      ],
    );
  }
}

/// Fila seleccionable de una etiqueta del catálogo (color + nombre + check).
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Label label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: Key('template_ai.sheet.silence.option.${label.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTokens.sp3,
          horizontal: AppTokens.sp1,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              color: selected ? AppTokens.primary : AppTokens.text2,
              size: 22,
            ),
            const SizedBox(width: AppTokens.sp2),
            LabelDot(hex: label.color),
            const SizedBox(width: AppTokens.sp2),
            Expanded(
              child: Text(
                label.name,
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila para un id seleccionado que ya no está en el catálogo (etiqueta
/// borrada). No se descarta en silencio: se muestra para que el operador
/// decida si la quita; mientras siga marcada, se conserva al guardar.
class _OrphanRow extends StatelessWidget {
  const _OrphanRow({required this.rawId, required this.onRemove});

  final String rawId;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: Key('template_ai.sheet.silence.orphan.$rawId'),
      padding: const EdgeInsets.symmetric(
        vertical: AppTokens.sp3,
        horizontal: AppTokens.sp1,
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.help_outline, color: AppTokens.text2, size: 22),
          const SizedBox(width: AppTokens.sp2),
          Expanded(
            child: Text(
              'Etiqueta eliminada del catálogo',
              style: textTheme.bodyMedium?.copyWith(
                color: AppTokens.text2,
                fontStyle: FontStyle.italic,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppButton.text(
            key: Key('template_ai.sheet.silence.orphan.$rawId.remove'),
            label: 'Quitar',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Error + reintento del catálogo de etiquetas. Redispatcha la carga al
/// `LabelsBloc`; el resto del sheet sigue operable (Guardar queda inerte).
class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry();

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('template_ai.sheet.silence.error'),
      children: <Widget>[
        const Expanded(
          child: Text(
            'No pudimos cargar las etiquetas.',
            style: TextStyle(color: AppTokens.danger),
          ),
        ),
        AppButton.text(
          key: const Key('template_ai.sheet.silence.retry'),
          label: 'Reintentar',
          onPressed: () =>
              context.read<LabelsBloc>().add(const LabelsLoadRequested()),
        ),
      ],
    );
  }
}
