import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../bots/domain/entities/bot.dart';
import '../../../labels/domain/entities/label.dart';
import '../../../labels/presentation/widgets/label_dot.dart';
import '../../domain/entities/inbox_query.dart';

class InboxFilters extends StatelessWidget {
  const InboxFilters({
    super.key,
    required this.query,
    required this.bots,
    required this.labels,
    required this.searchController,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onChannelChanged,
    required this.onLabelChanged,
  });

  final InboxQuery query;
  final List<Bot> bots;
  final List<Label> labels;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<InboxStatus> onStatusChanged;
  final ValueChanged<String?> onChannelChanged;
  final ValueChanged<String?> onLabelChanged;

  @override
  Widget build(BuildContext context) {
    // Un handoff puede traer una faceta cuyo catálogo todavía no cargó o que
    // fue eliminada. Mientras el bloc la reconcilia mostramos el filtro neutro
    // y nunca fabricamos una opción que el operador no pueda volver a elegir.
    final selectedBot = _botWithId(bots, query.botId);
    final selectedLabel = _labelWithId(labels, query.labelId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTextField(
          key: const Key('inbox.search'),
          hint: 'Buscar…',
          controller: searchController,
          prefixIcon: Icons.search,
          onChanged: onSearchChanged,
          suffix: searchController.text.isEmpty
              ? null
              : IconButton(
                  key: const Key('inbox.search.clear'),
                  tooltip: 'Limpiar búsqueda',
                  onPressed: () {
                    searchController.clear();
                    onSearchChanged('');
                  },
                  icon: const Icon(Icons.close, size: 20),
                ),
        ),
        const SizedBox(height: AppTokens.sp3),
        SingleChildScrollView(
          key: const Key('inbox.filters'),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              _FacetMenu(
                menuKey: const Key('inbox.channel.filter'),
                optionKeyPrefix: 'inbox.channel.option',
                tooltip: 'Filtrar por canal',
                label: selectedBot == null
                    ? 'Canal'
                    : _channelLabel(selectedBot),
                icon: Icons.hub_outlined,
                active: selectedBot != null,
                enabled: bots.isNotEmpty,
                selectedValue: selectedBot?.id ?? '',
                options: <_FacetOption>[
                  const _FacetOption('', 'Todos los canales'),
                  for (final bot in bots)
                    _FacetOption(bot.id, _channelLabel(bot)),
                ],
                onSelected: (value) =>
                    onChannelChanged(value.isEmpty ? null : value),
              ),
              const SizedBox(width: AppTokens.sp2),
              _FacetMenu(
                menuKey: const Key('inbox.labels.filters'),
                optionKeyPrefix: 'inbox.label.option',
                tooltip: 'Filtrar por etiqueta',
                label: selectedLabel?.name ?? 'Etiqueta',
                icon: Icons.label_outline,
                active: selectedLabel != null,
                enabled: labels.isNotEmpty,
                selectedValue: selectedLabel?.id ?? '',
                selectedColorHex: selectedLabel?.color,
                options: <_FacetOption>[
                  const _FacetOption('', 'Todas las etiquetas'),
                  for (final label in labels)
                    _FacetOption(label.id, label.name, colorHex: label.color),
                ],
                onSelected: (value) =>
                    onLabelChanged(value.isEmpty ? null : value),
              ),
              const SizedBox(width: AppTokens.sp2),
              _StatusFilters(
                key: const Key('inbox.status.filters'),
                selected: query.status,
                onChanged: onStatusChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FacetOption {
  const _FacetOption(this.value, this.label, {this.colorHex});

  final String value;
  final String label;
  final String? colorHex;
}

/// Faceta compacta de la barra: el estado cerrado ocupa lo mismo que un chip;
/// al tocar abre una lista con targets Material de 48 px y marca la opción
/// vigente. Canal y etiqueta comparten esta anatomía para leerse como filtros
/// pares, no como campos de un formulario web.
class _FacetMenu extends StatelessWidget {
  const _FacetMenu({
    required this.menuKey,
    required this.optionKeyPrefix,
    required this.tooltip,
    required this.label,
    required this.icon,
    required this.active,
    required this.enabled,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
    this.selectedColorHex,
  });

  final Key menuKey;
  final String optionKeyPrefix;
  final String tooltip;
  final String label;
  final IconData icon;
  final bool active;
  final bool enabled;
  final String selectedValue;
  final List<_FacetOption> options;
  final ValueChanged<String> onSelected;
  final String? selectedColorHex;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? AppTokens.primary : AppTokens.text2;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: PopupMenuButton<String>(
        key: menuKey,
        tooltip: tooltip,
        enabled: enabled,
        initialValue: selectedValue,
        color: AppTokens.surface2,
        onSelected: onSelected,
        itemBuilder: (context) => <PopupMenuEntry<String>>[
          for (final option in options)
            PopupMenuItem<String>(
              key: Key(
                '$optionKeyPrefix.${option.value.isEmpty ? 'all' : option.value}',
              ),
              value: option.value,
              child: Row(
                children: <Widget>[
                  if (option.colorHex case final color?)
                    LabelDot(hex: color, size: 14)
                  else
                    Icon(
                      option.value.isEmpty ? Icons.clear_all : icon,
                      size: 18,
                      color: AppTokens.text2,
                    ),
                  const SizedBox(width: AppTokens.sp3),
                  Expanded(
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (option.value == selectedValue) ...<Widget>[
                    const SizedBox(width: AppTokens.sp3),
                    const Icon(Icons.check, size: 18, color: AppTokens.primary),
                  ],
                ],
              ),
            ),
        ],
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36, maxWidth: 228),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active
                  ? AppTokens.primary.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              border: Border.all(
                color: active ? AppTokens.primary : AppTokens.divider,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.sp3,
                vertical: AppTokens.sp1,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (selectedColorHex case final color?)
                    LabelDot(hex: color, size: 14)
                  else
                    Icon(icon, size: 18, color: foreground),
                  const SizedBox(width: AppTokens.sp1),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTokens.fontSans,
                        fontSize: AppTokens.bodyMSize,
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.sp1),
                  Icon(Icons.expand_more, size: 18, color: foreground),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusFilters extends StatelessWidget {
  const _StatusFilters({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final InboxStatus selected;
  final ValueChanged<InboxStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = <(InboxStatus, String)>[
      (InboxStatus.all, 'Todas'),
      (InboxStatus.unread, 'No leídas'),
      (InboxStatus.attention, 'Requieren atención'),
      (InboxStatus.archived, 'Archivadas'),
    ];
    return Row(
      children: <Widget>[
        for (var index = 0; index < options.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(width: AppTokens.sp2),
          AppChoiceChip(
            key: Key('inbox.status.${options[index].$1.name}'),
            label: options[index].$2,
            selected: selected == options[index].$1,
            onSelected: (_) => onChanged(options[index].$1),
          ),
        ],
      ],
    );
  }
}

String _channelLabel(Bot bot) {
  final identifier = bot.identifier?.trim() ?? '';
  return identifier.isEmpty ? bot.name : '${bot.name} · $identifier';
}

Bot? _botWithId(List<Bot> bots, String? id) {
  if (id == null) return null;
  for (final bot in bots) {
    if (bot.id == id) return bot;
  }
  return null;
}

Label? _labelWithId(List<Label> labels, String? id) {
  if (id == null) return null;
  for (final label in labels) {
    if (label.id == id) return label;
  }
  return null;
}
