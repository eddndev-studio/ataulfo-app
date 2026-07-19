import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_checkbox.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/util/smart_timestamp.dart';
import '../../../labels/presentation/widgets/label_dot.dart';
import '../../../profile/data/cache/profile_photo_cache.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../domain/entities/conversation.dart';

const double _avatarSize = 42;

class InboxConversationRow extends StatelessWidget {
  const InboxConversationRow({
    super.key,
    required this.conversation,
    required this.onTap,
    this.selected = false,
    this.multiSelected = false,
    this.showSelectionControl = false,
    this.onSelectionChanged,
    this.onLongPress,
  });

  final Conversation conversation;
  final VoidCallback onTap;
  final bool selected;
  final bool multiSelected;
  final bool showSelectionControl;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final item = conversation;
    final title = _titleOf(item);
    final hasUnread = item.unreadCount > 0 || item.isMarkedUnread;
    final timestamp = item.lastMessageTimestampMs;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      selected: multiSelected || selected,
      child: Material(
        color: multiSelected
            ? AppTokens.primary.withValues(alpha: 0.08)
            : (selected ? AppTokens.surface2 : Colors.transparent),
        child: InkWell(
          key: Key('conversation.tile.${item.botId}.${item.chatLid}'),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.sp4,
              vertical: AppTokens.sp3,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (showSelectionControl) ...<Widget>[
                  Tooltip(
                    message: multiSelected
                        ? 'Quitar de la selección'
                        : 'Seleccionar conversación',
                    child: AppCheckbox(
                      key: Key(
                        'conversation.select.${item.botId}.${item.chatLid}',
                      ),
                      value: multiSelected,
                      onChanged: onSelectionChanged,
                    ),
                  ),
                  const SizedBox(width: AppTokens.sp1),
                ],
                ProfileAvatar(
                  cache: context.read<ProfilePhotoCache>(),
                  botId: item.botId,
                  chatLid: item.chatLid,
                  name: title,
                  size: _avatarSize,
                ),
                const SizedBox(width: AppTokens.sp3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium,
                            ),
                          ),
                          if (timestamp != null) ...<Widget>[
                            const SizedBox(width: AppTokens.sp2),
                            Text(
                              smartTimestamp(timestamp),
                              style: textTheme.labelSmall?.copyWith(
                                color: hasUnread
                                    ? AppTokens.chatAccent
                                    : AppTokens.text2,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: <Widget>[
                          if (_previewIcon(item.lastMessageType)
                              case final icon?) ...[
                            Icon(icon, size: 14, color: AppTokens.text2),
                            const SizedBox(width: AppTokens.sp1),
                          ],
                          Expanded(
                            child: Text(
                              _previewOf(item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium?.copyWith(
                                color: hasUnread
                                    ? AppTokens.text1
                                    : AppTokens.text2,
                                fontWeight: hasUnread ? FontWeight.w600 : null,
                              ),
                            ),
                          ),
                          if (item.unreadCount > 0) ...<Widget>[
                            const SizedBox(width: AppTokens.sp2),
                            _UnreadBadge(conversation: item),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppTokens.sp1),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.call_split_outlined,
                            size: 14,
                            color: AppTokens.text2,
                          ),
                          const SizedBox(width: AppTokens.sp1),
                          Expanded(
                            child: Text(
                              _originOf(item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color: AppTokens.text2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.labels.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppTokens.sp2),
                        Wrap(
                          spacing: AppTokens.sp1,
                          runSpacing: AppTokens.sp1,
                          children: <Widget>[
                            for (final label in item.labels)
                              _InternalLabelBadge(label: label),
                          ],
                        ),
                      ],
                      if (item.needsAttention ||
                          item.isMarkedUnread ||
                          item.isPinned ||
                          item.isArchived) ...<Widget>[
                        const SizedBox(height: AppTokens.sp2),
                        Wrap(
                          spacing: AppTokens.sp2,
                          runSpacing: AppTokens.sp1,
                          children: <Widget>[
                            if (item.needsAttention)
                              AppPill.danger(
                                key: Key(
                                  'conversation.attention.${item.botId}.${item.chatLid}',
                                ),
                                label: 'Atención',
                                dot: AppPillDot.danger,
                              ),
                            if (item.isMarkedUnread)
                              const AppPill.primary(label: 'No leído'),
                            if (item.isPinned)
                              const AppPill.neutral(label: 'Fijado'),
                            if (item.isArchived)
                              const AppPill.neutral(label: 'Archivado'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InboxConversationDivider extends StatelessWidget {
  const InboxConversationDivider({super.key});

  @override
  Widget build(BuildContext context) => const Divider(
    height: 1,
    thickness: 1,
    indent: AppTokens.sp4 + _avatarSize + AppTokens.sp3,
    endIndent: AppTokens.sp4,
    color: AppTokens.divider,
  );
}

class _InternalLabelBadge extends StatelessWidget {
  const _InternalLabelBadge({required this.label});

  final ConversationLabel label;

  @override
  Widget build(BuildContext context) {
    final color = parseLabelHex(label.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label.name,
        style: TextStyle(
          color: color,
          fontSize: AppTokens.captionSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) => Container(
    key: Key(
      'conversation.unread.${conversation.botId}.${conversation.chatLid}',
    ),
    constraints: const BoxConstraints(minWidth: 20),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: const BoxDecoration(
      color: AppTokens.chatAccent,
      borderRadius: BorderRadius.all(Radius.circular(AppTokens.radiusPill)),
    ),
    child: Text(
      '${conversation.unreadCount}',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppTokens.onPrimary,
        fontSize: AppTokens.captionSize,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

String _titleOf(Conversation item) =>
    item.displayName ??
    (item.kind == ConversationKind.group
        ? 'Grupo'
        : (item.phone ?? 'Contacto'));

String _originOf(Conversation item) {
  final channel = item.channelIdentifier?.trim().isNotEmpty == true
      ? '${item.channelName} · ${item.channelIdentifier}'
      : item.channelName;
  final parts = <String>[
    if (item.assistantName.trim().isNotEmpty) item.assistantName,
    if (channel.trim().isNotEmpty) channel,
  ];
  return parts.isEmpty ? 'Procedencia no disponible' : parts.join(' · ');
}

String _previewOf(Conversation item) {
  if (item.lastMessageTimestampMs == null) return 'Sin mensajes';
  final type = item.lastMessageType;
  if (type == null || type == 'text') return item.lastMessagePreview ?? '';
  return switch (type) {
    'image' => 'Imagen',
    'video' => 'Video',
    'audio' || 'ptt' => 'Audio',
    'document' => 'Documento',
    'sticker' => 'Sticker',
    'location' => 'Ubicación',
    'contact' || 'vcard' => 'Contacto',
    'poll' => 'Encuesta',
    'poll_vote' => 'Voto',
    _ => '[$type]',
  };
}

IconData? _previewIcon(String? type) => switch (type) {
  'image' => Icons.image_outlined,
  'video' => Icons.videocam_outlined,
  'audio' || 'ptt' => Icons.mic_none_outlined,
  'document' => Icons.description_outlined,
  'sticker' => Icons.emoji_emotions_outlined,
  'location' => Icons.location_on_outlined,
  'contact' || 'vcard' => Icons.person_outline,
  'poll' => Icons.poll_outlined,
  'poll_vote' => Icons.how_to_vote_outlined,
  _ => null,
};
