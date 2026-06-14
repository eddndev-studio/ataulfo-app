import 'package:flutter/material.dart';

import '../design/safe_bottom.dart';
import '../design/tokens.dart';
import '../design/widgets/app_button.dart';
import 'tool_groups.dart';

/// Multi-select de grupos de capacidad del agente IA: el operador HABILITA o
/// deshabilita cada grupo. Lo que se guarda es la **deny-list** (los grupos
/// apagados de ESTE nivel) — un casillero marcado = grupo habilitado.
///
/// Compartido por la plantilla (línea base) y el bot (override). El catálogo de
/// grupos es estático del cliente (no se pide al backend); la herramienta núcleo
/// (cerrar turno) no es un grupo y se muestra como una fila informativa siempre
/// activa. La mensajería sí es un grupo configurable más.
///
/// `lockedDisabledGroups` son grupos ya apagados por un nivel superior (la
/// plantilla, cuando se edita un Bot): se muestran apagados y bloqueados, y
/// NUNCA entran en el resultado de este nivel (el Bot sólo añade restricciones
/// propias sobre las de la plantilla). Para editar la plantilla va vacío.
///
/// Al guardar hace `pop` con la deny-list de este nivel; cancelar no hace pop.
/// Un id apagado que no corresponde a ningún grupo conocido (un grupo que un
/// backend futuro podría agregar) se preserva como fila "desconocida", removible.
class ToolGroupsSheet extends StatefulWidget {
  const ToolGroupsSheet({
    super.key,
    required this.initialDisabledGroups,
    this.lockedDisabledGroups = const <String>[],
  });

  /// Deny-list actual de ESTE nivel (los grupos que este nivel apaga).
  final List<String> initialDisabledGroups;

  /// Grupos apagados por un nivel superior (display-only, no editables aquí).
  final List<String> lockedDisabledGroups;

  @override
  State<ToolGroupsSheet> createState() => _ToolGroupsSheetState();
}

class _ToolGroupsSheetState extends State<ToolGroupsSheet> {
  // Set de wires apagados por ESTE nivel (no incluye los bloqueados arriba).
  late final Set<String> _disabled = <String>{...widget.initialDisabledGroups};

  late final Set<String> _locked = <String>{...widget.lockedDisabledGroups};

  void _toggle(String wire) => setState(() {
    if (!_disabled.remove(wire)) _disabled.add(wire);
  });

  /// Resultado: grupos conocidos apagados en orden canónico (del enum), luego
  /// los ids apagados desconocidos preservados. Nunca incluye los bloqueados.
  List<String> _result() {
    final known = ToolGroup.values.map((g) => g.wire).toSet();
    return <String>[
      for (final g in ToolGroup.values)
        if (_disabled.contains(g.wire) && !_locked.contains(g.wire)) g.wire,
      for (final id in widget.initialDisabledGroups)
        if (!known.contains(id) && _disabled.contains(id)) id,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final known = ToolGroup.values.map((g) => g.wire).toSet();
    final orphans = widget.initialDisabledGroups
        .where((id) => !known.contains(id) && _disabled.contains(id))
        .toList(growable: false);

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
            Text('Permisos de herramientas', style: textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              'Marca las capacidades que el bot puede usar. Las que desactives '
              'no se le ofrecen ni se le describen.',
              style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp4),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  const _CoreRow(),
                  for (final g in ToolGroup.values)
                    _GroupRow(
                      group: g,
                      enabled: !_disabled.contains(g.wire),
                      locked: _locked.contains(g.wire),
                      onTap: _locked.contains(g.wire)
                          ? null
                          : () => _toggle(g.wire),
                    ),
                  for (final id in orphans)
                    _OrphanRow(rawId: id, onRemove: () => _toggle(id)),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.sp4),
            AppButton.filled(
              key: const Key('tool_groups.sheet.save'),
              label: 'Guardar',
              fullWidth: true,
              onPressed: () => Navigator.of(context).pop(_result()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila informativa del núcleo: cerrar el turno está SIEMPRE activo (sin él el
/// agente no podría terminar conscientemente), no es configurable.
class _CoreRow extends StatelessWidget {
  const _CoreRow();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: const Key('tool_groups.sheet.core'),
      padding: const EdgeInsets.symmetric(
        vertical: AppTokens.sp3,
        horizontal: AppTokens.sp1,
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.lock_outline, color: AppTokens.text2, size: 22),
          const SizedBox(width: AppTokens.sp2),
          const Icon(Icons.task_alt, color: AppTokens.text2, size: 20),
          const SizedBox(width: AppTokens.sp2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Cierre de turno (núcleo)', style: textTheme.bodyMedium),
                Text(
                  'El bot siempre puede cerrar su turno. Siempre activo.',
                  style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de un grupo de capacidad: ícono + nombre + descripción + casillero
/// (marcado = habilitado). Bloqueado ⇒ apagado, gris y no tappable, con nota.
class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.enabled,
    required this.locked,
    required this.onTap,
  });

  final ToolGroup group;
  final bool enabled;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final on = enabled && !locked;
    final color = locked
        ? AppTokens.text2
        : (on ? AppTokens.primary : AppTokens.text2);
    return InkWell(
      key: Key('tool_groups.sheet.option.${group.wire}'),
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
              on ? Icons.check_box : Icons.check_box_outline_blank,
              color: color,
              size: 22,
            ),
            const SizedBox(width: AppTokens.sp2),
            Icon(group.icon, color: AppTokens.text2, size: 20),
            const SizedBox(width: AppTokens.sp2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(group.label, style: textTheme.bodyMedium),
                  Text(
                    locked ? 'Desactivado por la plantilla' : group.description,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTokens.text2,
                      fontStyle: locked ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila para un id apagado que no corresponde a ningún grupo conocido (un grupo
/// que un backend futuro podría agregar). No se descarta en silencio: se
/// preserva mientras siga marcado; el operador puede quitarlo.
class _OrphanRow extends StatelessWidget {
  const _OrphanRow({required this.rawId, required this.onRemove});

  final String rawId;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: Key('tool_groups.sheet.orphan.$rawId'),
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
              'Grupo desconocido apagado',
              style: textTheme.bodyMedium?.copyWith(
                color: AppTokens.text2,
                fontStyle: FontStyle.italic,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppButton.text(
            key: Key('tool_groups.sheet.orphan.$rawId.remove'),
            label: 'Quitar',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
