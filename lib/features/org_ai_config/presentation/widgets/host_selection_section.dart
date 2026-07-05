import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../ai_catalog/domain/entities/catalog.dart';
import '../../domain/entities/org_ai_config.dart';

/// Etiqueta legible de un host (el wire viaja en MAYÚSCULAS). Un host
/// desconocido se muestra tal cual (forward-compat).
String hostLabel(String host) => switch (host) {
  'GEMINI' => 'Gemini',
  'OPENAI' => 'OpenAI',
  'MINIMAX' => 'MiniMax',
  'DEEPSEEK' => 'DeepSeek',
  'FIREWORKS' => 'Fireworks',
  _ => host,
};

/// Selección de host POR MODELO. Por cada modelo del catálogo con hosts:
///
///   - un solo host ⇒ fila informativa de solo-lectura ("corre en X"): la org
///     no elige.
///   - dos o más ⇒ chips de elección; el seleccionado = host fijado por la org.
///     Tocar un chip lo fija; tocar el ya fijado lo quita (vuelve al default
///     del backend, fila "Automático").
///
/// Los modelos sin hosts en el catálogo (wire viejo) se omiten.
class HostSelectionSection extends StatelessWidget {
  const HostSelectionSection({
    super.key,
    required this.catalog,
    required this.config,
    required this.enabled,
    required this.onHostChanged,
  });

  final Catalog catalog;
  final OrgAiConfig config;

  /// false durante un guardado en vuelo: los chips no responden.
  final bool enabled;

  /// host == null ⇒ quitar el pin (volver al default).
  final void Function(String model, String? host) onHostChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rows = <Widget>[];
    for (final p in catalog.providers) {
      for (final m in p.models) {
        if (m.hosts.isEmpty) continue;
        rows.add(
          _ModelHostRow(
            model: m,
            selected: config.hostFor(m.id),
            enabled: enabled,
            onHostChanged: onHostChanged,
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Proveedor por modelo', style: textTheme.titleMedium),
        const SizedBox(height: AppTokens.sp1),
        Text(
          'Elige en qué proveedor corre cada modelo. Los de un solo proveedor '
          'quedan fijos.',
          style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp3),
        ...rows,
      ],
    );
  }
}

class _ModelHostRow extends StatelessWidget {
  const _ModelHostRow({
    required this.model,
    required this.selected,
    required this.enabled,
    required this.onHostChanged,
  });

  final AIModel model;
  final String? selected;
  final bool enabled;
  final void Function(String model, String? host) onHostChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final locked = model.hosts.length < 2;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.sp2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(model.id, style: textTheme.bodyLarge),
          const SizedBox(height: AppTokens.sp1),
          if (locked)
            // Un solo host: informativo, sin elección.
            Row(
              children: <Widget>[
                const Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: AppTokens.text2,
                ),
                const SizedBox(width: AppTokens.sp1),
                Text(
                  'Corre en ${hostLabel(model.hosts.first)}',
                  style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
                ),
              ],
            )
          else
            Wrap(
              spacing: AppTokens.sp2,
              children: <Widget>[
                for (final h in model.hosts)
                  AppChoiceChip(
                    key: Key('org_ai.host.${model.id}.$h'),
                    label: hostLabel(h),
                    selected: selected == h,
                    onSelected: enabled
                        ? (isSel) => onHostChanged(model.id, isSel ? h : null)
                        : null,
                  ),
                // Chip "Automático": refleja "sin fijar" y permite volver al
                // default tocándolo.
                AppChoiceChip(
                  key: Key('org_ai.host.${model.id}.auto'),
                  label: 'Automático',
                  selected: selected == null,
                  onSelected: enabled
                      ? (_) => onHostChanged(model.id, null)
                      : null,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
