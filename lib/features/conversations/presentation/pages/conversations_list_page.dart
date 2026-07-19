import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../../core/design/widgets/app_empty_state.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/util/smart_timestamp.dart';
import '../../../monitor/presentation/cubit/monitor_attention_cubit.dart';
import '../../../profile/data/cache/profile_photo_cache.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../../wa_labels/domain/entities/wa_label.dart';
import '../../../wa_labels/presentation/widgets/wa_label_palette.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/failures/conversations_failure.dart';
import '../bloc/conversations_bloc.dart';
import '../cubit/inbox_labels_cubit.dart';
import '../widgets/chat_labels_sheet.dart';

/// Listado de conversaciones de un bot (S07 RF#7). Consume el
/// `ConversationsBloc` del scope (lo cabla la ruta `/bots/:id/sessions` con el
/// botId). Es content-only: el Scaffold y el AppBar los aporta la ruta, como
/// el detalle/conexión del bot.
///
/// La fila navega al hilo de mensajes (S09, `/bots/:id/sessions/:chatLid`); el
/// botId lo aporta el `ConversationsBloc` del scope.
class ConversationsListPage extends StatelessWidget {
  const ConversationsListPage({
    super.key,
    this.needsAttention = const <String>{},
  });

  /// chatLids con una señal de atención del bot (falló / alerta). La ruta los
  /// inyecta desde el MonitorAttentionCubit; vacío por defecto.
  final Set<String> needsAttention;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConversationsBloc, ConversationsState>(
      builder: (context, state) => switch (state) {
        ConversationsInitial() ||
        ConversationsLoading() => const _LoadingView(),
        ConversationsLoaded(items: final items) => _LoadedView(
          items: items,
          needsAttention: needsAttention,
        ),
        ConversationsFailed(failure: final f) => _FailedView(failure: f),
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const AppLoadingIndicator();
}

/// Vista del filtro de la bandeja. `all` esconde las archivadas (viven bajo
/// su propio filtro, como en mensajería); `unread` = pendientes de atender.
enum _TrayFilter { all, unread, archived }

/// Diámetro del avatar de la fila. Compartido entre el avatar y el sangrado
/// del divisor para que ambos deriven del mismo valor (el divisor alinea con
/// el inicio del texto: padding + avatar + gap).
const double _kInboxAvatarSize = 40;

class _LoadedView extends StatefulWidget {
  const _LoadedView({
    required this.items,
    this.needsAttention = const <String>{},
  });

  final List<Conversation> items;
  final Set<String> needsAttention;

  @override
  State<_LoadedView> createState() => _LoadedViewState();
}

class _LoadedViewState extends State<_LoadedView> {
  final TextEditingController _searchCtrl = TextEditingController();
  _TrayFilter _filter = _TrayFilter.all;

  /// Etiqueta WhatsApp activa como filtro (`waLabelId`), o `null` si el filtro
  /// activo es una vista (Todas/No leídas/Archivadas). La fila de chips es de
  /// selección única: una etiqueta y una vista no están activas a la vez.
  String? _labelFilter;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Selecciona una vista (Todas/No leídas/Archivadas) y limpia el filtro de
  /// etiqueta: las dos caras de la fila de chips son mutuamente excluyentes.
  void _selectView(_TrayFilter f) => setState(() {
    _filter = f;
    _labelFilter = null;
  });

  /// Alterna el filtro por una etiqueta. Activarla resetea la vista a Todas
  /// (la etiqueta pasa a ser el único filtro); re-tocar la activa vuelve a
  /// Todas.
  void _toggleLabel(String waLabelId) => setState(() {
    if (_labelFilter == waLabelId) {
      _labelFilter = null;
    } else {
      _labelFilter = waLabelId;
      _filter = _TrayFilter.all;
    }
  });

  /// Bandeja visible: filtro de vista o de etiqueta + búsqueda por
  /// nombre/teléfono, con las fijadas primero (orden estable en cada grupo).
  /// `labelFilter` es el filtro de etiqueta ya reconciliado contra el catálogo.
  List<Conversation> _visibleWith(
    Map<String, List<WaLabel>> byChat,
    String? labelFilter,
  ) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final byFilter = widget.items.where(
      (c) => switch (_filter) {
        _TrayFilter.all => !c.isArchived,
        _TrayFilter.unread =>
          !c.isArchived && (c.unreadCount > 0 || c.isMarkedUnread),
        _TrayFilter.archived => c.isArchived,
      },
    );
    final byLabel = labelFilter == null
        ? byFilter
        : byFilter.where(
            (c) => (byChat[c.chatLid] ?? const <WaLabel>[]).any(
              (l) => l.waLabelId == labelFilter,
            ),
          );
    final byQuery = query.isEmpty
        ? byLabel
        : byLabel.where(
            (c) =>
                _titleOf(c).toLowerCase().contains(query) ||
                (c.phone?.contains(query) ?? false),
          );
    final matched = byQuery.toList(growable: false);
    return <Conversation>[
      ...matched.where((c) => c.isPinned),
      ...matched.where((c) => !c.isPinned),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final inboxLabels = context.watch<InboxLabelsCubit>().state;
    final labelsByChat = inboxLabels.byChat;
    // Filtro efectivo: si la etiqueta activa ya no está en el catálogo (la
    // borraron o WhatsApp cayó al recargar), su chip desaparece — reconciliamos
    // a "sin filtro de etiqueta" para no dejar la bandeja vacía y sin chip
    // marcado. El estado crudo `_labelFilter` no se toca aquí (sin setState en
    // build); el render simplemente lo ignora cuando ya no aplica.
    final effectiveLabel =
        inboxLabels.catalog.any((l) => l.waLabelId == _labelFilter)
        ? _labelFilter
        : null;
    final visible = _visibleWith(labelsByChat, effectiveLabel);
    final filterChips = <Widget>[
      AppChoiceChip(
        key: const Key('conversations.filter.all'),
        label: 'Todas',
        selected: effectiveLabel == null && _filter == _TrayFilter.all,
        onSelected: (_) => _selectView(_TrayFilter.all),
      ),
      AppChoiceChip(
        key: const Key('conversations.filter.unread'),
        label: 'No leídas',
        selected: effectiveLabel == null && _filter == _TrayFilter.unread,
        onSelected: (_) => _selectView(_TrayFilter.unread),
      ),
      AppChoiceChip(
        key: const Key('conversations.filter.archived'),
        label: 'Archivadas',
        selected: effectiveLabel == null && _filter == _TrayFilter.archived,
        onSelected: (_) => _selectView(_TrayFilter.archived),
      ),
      for (final l in inboxLabels.catalog)
        AppChoiceChip(
          key: Key('conversations.filter.label.${l.waLabelId}'),
          label: l.name,
          selected: effectiveLabel == l.waLabelId,
          onSelected: (_) => _toggleLabel(l.waLabelId),
        ),
    ];
    return RefreshIndicator(
      onRefresh: () async {
        final bloc = context.read<ConversationsBloc>();
        // El pull-to-refresh también recarga las etiquetas WhatsApp (blobs y
        // chips): viajan en otra fuente, así que se refrescan en paralelo.
        unawaited(context.read<InboxLabelsCubit>().load());
        bloc.add(const ConversationsRefreshRequested());
        await bloc.stream.firstWhere(
          (s) =>
              (s is ConversationsLoaded && !s.isRefreshing) ||
              s is ConversationsFailed,
        );
      },
      child: widget.items.isEmpty
          ? const _EmptyView()
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              // Padding solo vertical: las filas van a sangre (full-bleed) con
              // su propio padding interno, como una bandeja de mensajería; el
              // buscador y los filtros conservan su margen horizontal.
              padding: EdgeInsets.only(
                top: AppTokens.sp4,
                bottom: AppTokens.sp4 + context.safeBottomInset,
              ),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.sp4,
                  ),
                  child: AppTextField(
                    key: const Key('conversations.search'),
                    label: 'Buscar conversación',
                    hint: 'Nombre o teléfono',
                    controller: _searchCtrl,
                  ),
                ),
                const SizedBox(height: AppTokens.sp3),
                // Fila de filtros en scroll horizontal (vistas + etiquetas):
                // una sola línea que crece con el catálogo sin robar alto, al
                // estilo de la bandeja de mensajería.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.sp4,
                  ),
                  child: Row(
                    children: <Widget>[
                      for (var i = 0; i < filterChips.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(width: AppTokens.sp2),
                        filterChips[i],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.sp2),
                if (visible.isEmpty)
                  Padding(
                    key: const Key('conversations.no_results'),
                    padding: const EdgeInsets.all(AppTokens.sp6),
                    child: Text(
                      'Sin resultados con este filtro',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
                    ),
                  )
                else
                  for (var i = 0; i < visible.length; i++) ...<Widget>[
                    _ConversationTile(
                      conversation: visible[i],
                      needsAttention: widget.needsAttention.contains(
                        visible[i].chatLid,
                      ),
                      labels:
                          labelsByChat[visible[i].chatLid] ?? const <WaLabel>[],
                      catalog: inboxLabels.catalog,
                    ),
                    if (i < visible.length - 1) const _InboxDivider(),
                  ],
              ],
            ),
    );
  }
}

/// Nombre visible de la fila: `displayName`, o el teléfono en DM, o "Grupo".
/// El chatLid es jerga de wire — sólo de último recurso.
String _titleOf(Conversation c) {
  final isGroup = c.kind == ConversationKind.group;
  return c.displayName ?? (isGroup ? 'Grupo' : (c.phone ?? c.chatLid));
}

/// Vacío informativo (sin CTA): una bandeja no ofrece crear conversaciones.
/// El scroll propio conserva el pull-to-refresh del RefreshIndicator padre.
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(AppTokens.sp5),
                child: AppEmptyState(
                  key: Key('conversations.empty'),
                  icon: Icons.forum_outlined,
                  title: 'Este Canal todavía no tiene conversaciones',
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp5),
        child: AppErrorState(
          key: isNotFound
              ? const Key('conversations.error.not_found')
              : const Key('conversations.error.generic'),
          message: isNotFound
              ? 'Este Canal ya no existe en tu organización'
              : 'No pudimos cargar las conversaciones',
          onRetry: () => context.read<ConversationsBloc>().add(
            const ConversationsLoadRequested(),
          ),
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
  const _ConversationTile({
    required this.conversation,
    this.needsAttention = false,
    this.labels = const <WaLabel>[],
    this.catalog = const <WaLabel>[],
  });

  final Conversation conversation;

  /// El bot falló o levantó una alerta en este chat (del monitor en vivo).
  final bool needsAttention;

  /// Etiquetas WhatsApp aplicadas a este chat, resueltas para pintarlas como
  /// blobs de color. Vacío si el bot no tiene etiquetas o aún no cargaron.
  final List<WaLabel> labels;

  /// Catálogo WhatsApp del bot, ya cargado por la bandeja. Siembra la hoja de
  /// etiquetas al abrirla para que no re-consulte catálogo + asociaciones.
  final List<WaLabel> catalog;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = conversation;
    final title = _titleOf(c);
    final hasLast = c.lastMessageTimestampMs != null;
    // Sin actividad aún: copy humano para DM y grupo por igual — el chatLid
    // es jerga de wire y nunca se le muestra al operador.
    final secondary = hasLast
        ? _previewLabel(c.lastMessageType, c.lastMessagePreview)
        : 'Sin mensajes';
    final previewIcon = hasLast ? _previewIcon(c.lastMessageType) : null;
    final hasUnread = c.unreadCount > 0 || c.isMarkedUnread;
    // Con pendientes, la línea de preview se enfatiza (texto pleno + w600):
    // la jerarquía visual de una bandeja de mensajería.
    final previewStyle = textTheme.bodyMedium?.copyWith(
      color: hasUnread ? AppTokens.text1 : AppTokens.text2,
      fontWeight: hasUnread ? FontWeight.w600 : null,
    );
    final showSecondaryRow = secondary.isNotEmpty || hasUnread;

    final pills = <Widget>[
      if (needsAttention)
        AppPill.danger(
          key: Key('conversation.attention.${c.chatLid}'),
          label: 'Atención',
          dot: AppPillDot.danger,
        ),
      if (c.isMarkedUnread) const AppPill.primary(label: 'No leído'),
      if (c.isPinned) const AppPill.neutral(label: 'Fijado'),
      if (c.isArchived) const AppPill.neutral(label: 'Archivado'),
    ];

    return InkWell(
      key: Key('conversation.tile.${c.chatLid}'),
      onTap: () async {
        // Abrir el chat lo atiende: su pill «Atención» se limpia y, mientras
        // el hilo está en foco (la bandeja sigue montada bajo el push), sus
        // señales nuevas no acumulan; al volver (el Future del push resuelve
        // con el pop) se reanuda. Entrar al hilo por deep-link/push NO pasa
        // por aquí — misma limitación page-scoped que la web: el subtree del
        // hilo no ve el cubit. Nada usa `context` tras el await; el cubit se
        // captura antes y sus métodos son inofensivos si ya se cerró.
        final attention = context.read<MonitorAttentionCubit>();
        attention
          ..clear(c.chatLid)
          ..suppress(c.chatLid);
        await context.push(
          '/bots/${context.read<ConversationsBloc>().botId}'
          '/sessions/${Uri.encodeComponent(c.chatLid)}',
        );
        attention.unsuppress();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp4,
          vertical: AppTokens.sp3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ProfileAvatar(
              cache: context.read<ProfilePhotoCache>(),
              botId: context.read<ConversationsBloc>().botId,
              chatLid: c.chatLid,
              name: title,
              size: _kInboxAvatarSize,
            ),
            const SizedBox(width: AppTokens.sp3),
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
                          smartTimestamp(c.lastMessageTimestampMs!),
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
                        if (previewIcon != null) ...<Widget>[
                          Icon(
                            previewIcon,
                            size: 14,
                            color: hasUnread
                                ? AppTokens.text1
                                : AppTokens.text2,
                          ),
                          const SizedBox(width: AppTokens.sp1),
                        ],
                        Expanded(
                          child: Text(
                            secondary,
                            key: Key('conversation.preview.${c.chatLid}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: previewStyle,
                          ),
                        ),
                        if (c.unreadCount > 0) ...<Widget>[
                          const SizedBox(width: AppTokens.sp2),
                          _UnreadBadge(
                            count: c.unreadCount,
                            chatLid: c.chatLid,
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (labels.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppTokens.sp1),
                    Wrap(
                      spacing: AppTokens.sp1,
                      runSpacing: AppTokens.sp1,
                      children: <Widget>[
                        for (final l in labels) _LabelBlob(label: l),
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
            // Acción secundaria: etiquetas de este chat (internas + WhatsApp).
            // El tap del icono no dispara el onTap de la fila (lo absorbe el botón).
            IconButton(
              key: Key('conversation.labels.${c.chatLid}'),
              tooltip: 'Etiquetas',
              icon: const Icon(Icons.label_outline, color: AppTokens.text2),
              onPressed: () => ChatLabelsSheet.open(
                context,
                botId: context.read<ConversationsBloc>().botId,
                chatLid: c.chatLid,
                kind: c.kind,
                // Siembra la sección WhatsApp desde el caché de la bandeja: el
                // catálogo completo y las etiquetas ya aplicadas a este chat.
                seedCatalog: catalog,
                seedAssociated: <String>{for (final l in labels) l.waLabelId},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Divisor hairline entre filas de la bandeja, sangrado para alinear con el
/// texto (pasado el avatar), al estilo de una lista de mensajería.
class _InboxDivider extends StatelessWidget {
  const _InboxDivider();

  @override
  Widget build(BuildContext context) => const Divider(
    height: 1,
    thickness: 1,
    indent: AppTokens.sp4 + _kInboxAvatarSize + AppTokens.sp3,
    endIndent: AppTokens.sp4,
    color: AppTokens.divider,
  );
}

/// Blob de color de una etiqueta WhatsApp: cápsula con tinte del color de la
/// etiqueta (resuelto del índice de paleta) y el nombre en ese mismo color.
/// Compacto, para apilarse varios en una fila de la bandeja sin saturar.
class _LabelBlob extends StatelessWidget {
  const _LabelBlob({required this.label});

  final WaLabel label;

  @override
  Widget build(BuildContext context) {
    final color = WaLabelPalette.resolve(label.color);
    // El fondo es el color al 18% sobre el lienzo oscuro; el texto va en el
    // mismo color, pero con un piso de luminancia para que los swatches
    // oscuros (azul/índigo) no caigan bajo el contraste legible.
    final hsl = HSLColor.fromColor(color);
    final textColor = hsl
        .withLightness(hsl.lightness < 0.7 ? 0.7 : hsl.lightness)
        .toColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Text(
        label.name,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
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
    'poll' => 'Encuesta',
    'poll_vote' => 'Voto',
    _ => '[$type]',
  };
}

/// Glifo del tipo de último-mensaje para la línea de preview (sólo media:
/// el texto no necesita ícono). Espeja los glifos del hilo.
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
