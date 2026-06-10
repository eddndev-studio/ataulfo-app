import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../domain/entities/label.dart';
import '../bloc/labels_bloc.dart';
import 'label_dot.dart';

/// Selector de una etiqueta interna del catálogo org-scoped. Lee el catálogo
/// (`LabelsBloc`) y deja elegir por nombre + color, en vez de teclear el id.
/// El `labelId` que produce es el id de la etiqueta — exactamente lo que el
/// backend evalúa (trigger LABEL) o aplica (paso LABEL).
///
/// El estado de carga vive en el bloc, no aquí: el picker dibuja
/// loading / error+reintento / vacío / lista según el estado. Un fallo
/// cargando el catálogo solo afecta a este selector.
///
/// Reutilizable por más de un editor (disparadores y pasos): [keyPrefix]
/// namespacea las Keys de los sub-widgets para que cada call site tenga
/// selectores de test propios. Requiere un `LabelsBloc` en el scope del
/// context (lo provee el editor que lo usa).
class LabelPicker extends StatelessWidget {
  const LabelPicker({
    super.key,
    required this.selectedLabelId,
    required this.enabled,
    required this.onSelected,
    this.keyPrefix = 'trigger_edit.label_picker',
  });

  /// Id elegido (o hidratado en edición). `null` ⇒ sin selección.
  final String? selectedLabelId;
  final bool enabled;
  final ValueChanged<String> onSelected;

  /// Prefijo de las Keys de los sub-widgets (namespacing por call site).
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      key: Key(keyPrefix),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Etiqueta',
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp1),
        BlocBuilder<LabelsBloc, LabelsState>(
          builder: (context, state) => switch (state) {
            LabelsLoading() => Padding(
              key: Key('$keyPrefix.loading'),
              padding: const EdgeInsets.symmetric(vertical: AppTokens.sp4),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            LabelsFailed() => _ErrorRetry(
              enabled: enabled,
              keyPrefix: keyPrefix,
            ),
            LabelsLoaded(labels: final ls) => _LabelOptions(
              labels: ls,
              selectedLabelId: selectedLabelId,
              enabled: enabled,
              onSelected: onSelected,
              keyPrefix: keyPrefix,
            ),
          },
        ),
      ],
    );
  }
}

/// Error + reintento del catálogo. El reintento redispatcha la carga al
/// `LabelsBloc`; el resto del editor sigue operable.
class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.enabled, required this.keyPrefix});

  final bool enabled;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: Key('$keyPrefix.error'),
      children: <Widget>[
        const Expanded(
          child: Text(
            'No pudimos cargar las etiquetas.',
            style: TextStyle(color: AppTokens.danger),
          ),
        ),
        AppButton.text(
          key: Key('$keyPrefix.retry'),
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

/// Lista seleccionable del catálogo. Si el id vigente no está en el catálogo
/// (label borrado o desconocido), antepone una fila "desconocida" con el id
/// crudo para no descartarlo en silencio. Si el catálogo está vacío y no hay
/// nada seleccionado, muestra el empty state que invita a crear una etiqueta.
class _LabelOptions extends StatelessWidget {
  const _LabelOptions({
    required this.labels,
    required this.selectedLabelId,
    required this.enabled,
    required this.onSelected,
    required this.keyPrefix,
  });

  final List<Label> labels;
  final String? selectedLabelId;
  final bool enabled;
  final ValueChanged<String> onSelected;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selectedId = selectedLabelId?.trim();
    final hasSelection = selectedId != null && selectedId.isNotEmpty;
    final isKnown = hasSelection && labels.any((l) => l.id == selectedId);

    if (labels.isEmpty && !hasSelection) {
      return Text(
        'Aún no hay etiquetas. Crea una primero en la sección de etiquetas.',
        key: Key('$keyPrefix.empty'),
        style: textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppTokens.text2,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (hasSelection && !isKnown)
          _UnknownOption(rawId: selectedId, keyPrefix: keyPrefix),
        for (final l in labels)
          _LabelOptionTile(
            label: l,
            selected: l.id == selectedId,
            enabled: enabled,
            onTap: () => onSelected(l.id),
            keyPrefix: keyPrefix,
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
    required this.keyPrefix,
  });

  final Label label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: Key('$keyPrefix.option.${label.id}'),
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        // sp3 vertical ⇒ fila ≥44px: piso táctil para acertar con el pulgar.
        padding: const EdgeInsets.symmetric(
          vertical: AppTokens.sp3,
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
              Icon(
                Icons.check_circle,
                key: Key('$keyPrefix.selected'),
                color: AppTokens.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

/// Fila para un id que ya no está en el catálogo. No se descarta en silencio:
/// muestra el id crudo para que el operador vea qué tenía y decida si lo
/// reemplaza por una etiqueta vigente.
class _UnknownOption extends StatelessWidget {
  const _UnknownOption({required this.rawId, required this.keyPrefix});

  final String rawId;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: Key('$keyPrefix.unknown'),
      padding: const EdgeInsets.symmetric(
        vertical: AppTokens.sp3,
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
                // El rawId NO se renderiza (es ruido para el operador) pero
                // sigue viajando aguas arriba: el submit lo preserva.
                Text(
                  'Fue eliminada del catálogo. Elige otra etiqueta.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTokens.text2,
                    fontStyle: FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle,
            key: Key('$keyPrefix.selected'),
            color: AppTokens.primary,
            size: 20,
          ),
        ],
      ),
    );
  }
}
