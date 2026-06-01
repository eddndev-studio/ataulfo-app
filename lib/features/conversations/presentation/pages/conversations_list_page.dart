import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_avatar.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../wa_labels/presentation/widgets/wa_chat_labels_sheet.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/failures/conversations_failure.dart';
import '../bloc/conversations_bloc.dart';

/// Listado de conversaciones de un bot (S07 RF#7). Consume el
/// `ConversationsBloc` del scope (lo cabla la ruta `/bots/:id/sessions` con el
/// botId). Es content-only: el Scaffold y el AppBar los aporta la ruta, como
/// el detalle/conexión del bot.
///
/// La fila navega al hilo de mensajes (S09, `/bots/:id/sessions/:chatLid`); el
/// botId lo aporta el `ConversationsBloc` del scope.
class ConversationsListPage extends StatelessWidget {
  const ConversationsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConversationsBloc, ConversationsState>(
      builder: (context, state) => switch (state) {
        ConversationsInitial() ||
        ConversationsLoading() => const _LoadingView(),
        ConversationsLoaded(items: final items) => _LoadedView(items: items),
        ConversationsFailed(failure: final f) => _FailedView(failure: f),
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
    ),
  );
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.items});

  final List<Conversation> items;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final bloc = context.read<ConversationsBloc>();
        bloc.add(const ConversationsRefreshRequested());
        await bloc.stream.firstWhere(
          (s) =>
              (s is ConversationsLoaded && !s.isRefreshing) ||
              s is ConversationsFailed,
        );
      },
      child: items.isEmpty
          ? const _EmptyView()
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppTokens.sp4,
                AppTokens.sp4,
                AppTokens.sp4,
                AppTokens.sp4 + context.safeBottomInset,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTokens.cardGap),
              itemBuilder: (_, i) => _ConversationTile(conversation: items[i]),
            ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, c) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(
              key: const Key('conversations.empty'),
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.sp6),
                child: Text(
                  'Este bot todavía no tiene conversaciones',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final ConversationsFailure failure;

  @override
  Widget build(BuildContext context) {
    final isNotFound = failure is ConversationsNotFoundFailure;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: isNotFound
          ? const Key('conversations.error.not_found')
          : const Key('conversations.error.generic'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              isNotFound
                  ? 'Este bot ya no existe en tu organización'
                  : 'No pudimos cargar las conversaciones',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () => context.read<ConversationsBloc>().add(
                const ConversationsLoadRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de una conversación, estilo bandeja de WhatsApp: nombre visible
/// (`displayName`; cae a `phone` en DM o "Grupo"), línea de último-mensaje
/// (preview de texto o etiqueta de tipo para media) con su hora, y un badge
/// verde con el conteo de no-leídos. Las pills verbalizan el app-state
/// (no leído / fijado / archivado); silenciado no se muestra (vive en
/// `mutedUntil`, lo usará una rebanada futura).
class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = conversation;
    final isGroup = c.kind == ConversationKind.group;
    final title = c.displayName ?? (isGroup ? 'Grupo' : (c.phone ?? c.chatLid));
    final hasLast = c.lastMessageTimestampMs != null;
    final secondary = hasLast
        ? _previewLabel(c.lastMessageType, c.lastMessagePreview)
        : (isGroup ? c.chatLid : null);
    final hasUnread = c.unreadCount > 0;
    final showSecondaryRow =
        (secondary != null && secondary.isNotEmpty) || hasUnread;

    final pills = <Widget>[
      if (c.isMarkedUnread) const AppPill.primary(label: 'No leído'),
      if (c.isPinned) const AppPill.neutral(label: 'Fijado'),
      if (c.isArchived) const AppPill.neutral(label: 'Archivado'),
    ];

    return AppCard(
      onTap: () => context.push(
        '/bots/${context.read<ConversationsBloc>().botId}'
        '/sessions/${Uri.encodeComponent(c.chatLid)}',
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppAvatar(name: title),
          const SizedBox(width: AppTokens.sp4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                    if (hasLast) ...<Widget>[
                      const SizedBox(width: AppTokens.sp2),
                      Text(
                        _hhmm(c.lastMessageTimestampMs!),
                        style: textTheme.labelSmall?.copyWith(
                          // La hora se tiñe del verde de sección cuando hay
                          // no-leídos: el acento "ligero" que la bandeja comparte
                          // con el tick de leído del hilo.
                          color: hasUnread
                              ? AppTokens.chatAccent
                              : AppTokens.text2,
                        ),
                      ),
                    ],
                  ],
                ),
                if (showSecondaryRow) ...<Widget>[
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          secondary ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTokens.text2,
                          ),
                        ),
                      ),
                      if (hasUnread) ...<Widget>[
                        const SizedBox(width: AppTokens.sp2),
                        _UnreadBadge(count: c.unreadCount, chatLid: c.chatLid),
                      ],
                    ],
                  ),
                ],
                if (pills.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppTokens.sp2),
                  Wrap(
                    spacing: AppTokens.sp2,
                    runSpacing: AppTokens.sp2,
                    children: pills,
                  ),
                ],
              ],
            ),
          ),
          // Acción secundaria: etiquetar este chat con etiquetas de WhatsApp.
          // El tap del icono no dispara el onTap del card (lo absorbe el botón).
          IconButton(
            key: Key('conversation.labels.${c.chatLid}'),
            tooltip: 'Etiquetas de WhatsApp',
            icon: const Icon(Icons.label_outline, color: AppTokens.text2),
            onPressed: () => WaChatLabelsSheet.open(
              context,
              botId: context.read<ConversationsBloc>().botId,
              chatLid: c.chatLid,
              kind: c.kind,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge circular con el conteo de no-leídos, en el verde de sección. Texto
/// oscuro ([AppTokens.onPrimary]) para contraste sobre el verde brillante.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.chatLid});

  final int count;
  final String chatLid;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('conversation.unread.$chatLid'),
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: const BoxDecoration(
        color: AppTokens.chatAccent,
        borderRadius: BorderRadius.all(Radius.circular(AppTokens.radiusPill)),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTokens.onPrimary,
          fontSize: AppTokens.captionSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Texto de la línea de último-mensaje: el preview tal cual si es texto; una
/// etiqueta legible del tipo si es media (no hay preview útil que mostrar). El
/// backend ya excluye las reacciones de la actividad, así que `reaction` no
/// llega aquí; un tipo no catalogado cae a `[tipo]` como en el hilo.
String _previewLabel(String? type, String? preview) {
  if (type == null || type == 'text') return preview ?? '';
  return switch (type) {
    'image' => 'Imagen',
    'video' => 'Video',
    'audio' || 'ptt' => 'Audio',
    'document' => 'Documento',
    'sticker' => 'Sticker',
    'location' => 'Ubicación',
    'contact' || 'vcard' => 'Contacto',
    _ => '[$type]',
  };
}

/// Hora local HH:mm del epoch en ms para la línea de último-mensaje. Formateo
/// manual para no arrastrar `intl` por una hora; la bandeja no muestra fecha.
String _hhmm(int timestampMs) {
  final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
