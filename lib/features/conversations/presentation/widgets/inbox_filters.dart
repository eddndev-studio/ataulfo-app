import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../../core/design/widgets/app_section_header.dart';
import '../../../../core/design/widgets/app_select_field.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../bots/domain/entities/bot.dart';
import '../../../labels/domain/entities/label.dart';
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
    required this.onLabelToggled,
  });

  final InboxQuery query;
  final List<Bot> bots;
  final List<Label> labels;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<InboxStatus> onStatusChanged;
  final ValueChanged<String?> onChannelChanged;
  final ValueChanged<String> onLabelToggled;

  @override
  Widget build(BuildContext context) {
    // Un deep link puede traer una conexión que todavía no cargó o que fue
    // eliminada. DropdownButton exige que el value exista en sus opciones;
    // degradamos visualmente a “Todos” mientras el bloc reconcilia la faceta.
    final selectedBotId = bots.any((bot) => bot.id == query.botId)
        ? query.botId
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTextField(
          key: const Key('inbox.search'),
          label: 'Buscar conversaciones',
          hint: 'Contacto, teléfono, Asistente o Canal',
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
        const SizedBox(height: AppTokens.sp4),
        _StatusFilters(
          key: const Key('inbox.status.filters'),
          selected: query.status,
          onChanged: onStatusChanged,
        ),
        const SizedBox(height: AppTokens.sp4),
        AppSelectField<String>(
          key: const Key('inbox.channel.filter'),
          label: 'Canal conectado',
          helperText: 'Una conexión concreta, no sólo el tipo de canal.',
          value: selectedBotId ?? '',
          options: <AppSelectOption<String>>[
            const AppSelectOption<String>('', 'Todos los canales'),
            for (final bot in bots)
              AppSelectOption<String>(bot.id, _channelLabel(bot)),
          ],
          onChanged: (value) =>
              onChannelChanged(value == null || value.isEmpty ? null : value),
        ),
        const SizedBox(height: AppTokens.sp4),
        Column(
          key: const Key('inbox.labels.filters'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const AppSectionHeader(
              title: 'Etiquetas internas',
              caption: 'Si eliges varias, la conversación debe tenerlas todas.',
            ),
            const SizedBox(height: AppTokens.sp3),
            if (labels.isEmpty)
              Text(
                'No hay etiquetas internas disponibles.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    for (var index = 0; index < labels.length; index++) ...[
                      if (index > 0) const SizedBox(width: AppTokens.sp2),
                      AppChoiceChip(
                        key: Key('inbox.label.${labels[index].id}'),
                        label: labels[index].name,
                        selected: query.labelIds.contains(labels[index].id),
                        onSelected: (_) => onLabelToggled(labels[index].id),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ],
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
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
      ),
    );
  }
}

String _channelLabel(Bot bot) {
  final identifier = bot.identifier?.trim() ?? '';
  return identifier.isEmpty ? bot.name : '${bot.name} · $identifier';
}
