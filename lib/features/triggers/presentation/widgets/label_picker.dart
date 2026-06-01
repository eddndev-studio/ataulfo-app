import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../labels/domain/entities/label.dart';
import '../../../labels/presentation/bloc/labels_bloc.dart';
import '../../../labels/presentation/widgets/label_dot.dart';

/// Selector de la etiqueta interna sobre la que dispara el trigger LABEL.
/// Lee el catálogo (`LabelsBloc`, org-scoped) y deja elegir por nombre +
/// color, en vez de teclear el id. El `labelId` que produce es el id de
/// la `SessionLabel` — exactamente lo que el backend evalúa al cambiar la
/// etiqueta internamente (sea por acción manual o por una etiqueta de
/// WhatsApp mapeada).
///
/// El estado de carga vive en el bloc, no aquí: el picker dibuja
/// loading / error+reintento / vacío / lista según el estado. Un fallo
/// cargando el catálogo solo afecta a este selector — un trigger TEXT no
/// lo consume y queda intacto.
///
/// Requiere un `LabelsBloc` en el scope del context (lo provee el editor
/// de disparadores).
class LabelPicker extends StatelessWidget {
  const LabelPicker({
    super.key,
    required this.selectedLabelId,
    required this.enabled,
    required this.onSelected,
  });

  /// Id elegido (o hidratado en edición). `null` ⇒ sin selección.
  final String? selectedLabelId;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      key: const Key('trigger_edit.label_picker'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Etiqueta',
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp1),
        BlocBuilder<LabelsBloc, LabelsState>(
          builder: (context, state) => switch (state) {
            LabelsLoading() => const Padding(
              key: Key('trigger_edit.label_picker.loading'),
              padding: EdgeInsets.symmetric(vertical: AppTokens.sp4),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            LabelsFailed() => _ErrorRetry(enabled: enabled),
            LabelsLoaded(labels: final ls) => _LabelOptions(
              labels: ls,
              selectedLabelId: selectedLabelId,
              enabled: enabled,
              onSelected: onSelected,
            ),
          },
        ),
      ],
    );
  }
}

/// Error + reintento del catálogo. El reintento redispatcha la carga al
/// `LabelsBloc`; el resto del sheet (acción de etiqueta, activo) sigue
/// operable.
class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('trigger_edit.label_picker.error'),
      children: <Widget>[
        const Expanded(
          child: Text(
            'No pudimos cargar las etiquetas.',
            style: TextStyle(color: AppTokens.danger),
          ),
        ),
        AppButton.text(
          key: const Key('trigger_edit.label_picker.retry'),
          label: 'Reintentar',
          onPressed: enabled
              ? () =>
                    context.read<LabelsBloc>().add(const LabelsLoadRequested())
              : null,
        ),
      ],
    );
  }
}

/// Lista seleccionable del catálogo. Si el id vigente no está en el
/// catálogo (label borrado o desconocido), antepone una fila
/// "desconocida" con el id crudo para no descartarlo en silencio. Si el
/// catálogo está vacío y no hay nada seleccionado, muestra el empty
/// state que invita a crear una etiqueta primero.
class _LabelOptions extends StatelessWidget {
  const _LabelOptions({
    required this.labels,
    required this.selectedLabelId,
    required this.enabled,
    required this.onSelected,
  });

  final List<Label> labels;
  final String? selectedLabelId;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selectedId = selectedLabelId?.trim();
    final hasSelection = selectedId != null && selectedId.isNotEmpty;
    final isKnown = hasSelection && labels.any((l) => l.id == selectedId);

    if (labels.isEmpty && !hasSelection) {
      return Text(
        'Aún no hay etiquetas. Crea una primero en la sección de etiquetas.',
        key: const Key('trigger_edit.label_picker.empty'),
        style: textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppTokens.text2,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (hasSelection && !isKnown) _UnknownOption(rawId: selectedId),
        for (final l in labels)
          _LabelOptionTile(
            label: l,
            selected: l.id == selectedId,
            enabled: enabled,
            onTap: () => onSelected(l.id),
          ),
      ],
    );
  }
}

class _LabelOptionTile extends StatelessWidget {
  const _LabelOptionTile({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Label label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: Key('trigger_edit.label_picker.option.${label.id}'),
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTokens.sp2,
          horizontal: AppTokens.sp1,
        ),
        child: Row(
          children: <Widget>[
            LabelDot(hex: label.color),
            const SizedBox(width: AppTokens.sp2),
            Expanded(
              child: Text(
                label.name,
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                key: Key('trigger_edit.label_picker.selected'),
                color: AppTokens.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

/// Fila para un id que ya no está en el catálogo. No se descarta en
/// silencio: muestra el id crudo para que el operador vea qué tenía y
/// decida si lo reemplaza por una etiqueta vigente.
class _UnknownOption extends StatelessWidget {
  const _UnknownOption({required this.rawId});

  final String rawId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: const Key('trigger_edit.label_picker.unknown'),
      padding: const EdgeInsets.symmetric(
        vertical: AppTokens.sp2,
        horizontal: AppTokens.sp1,
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.help_outline, color: AppTokens.text2, size: 16),
          const SizedBox(width: AppTokens.sp2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Etiqueta desconocida',
                  style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
                ),
                Text(
                  rawId,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTokens.text2,
                    fontFamily: 'monospace',
                    fontFamilyFallback: const <String>[
                      'RobotoMono',
                      'Courier',
                      'monospace',
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle,
            key: Key('trigger_edit.label_picker.selected'),
            color: AppTokens.primary,
            size: 20,
          ),
        ],
      ),
    );
  }
}
