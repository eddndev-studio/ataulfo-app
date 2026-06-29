// Nota de tamaño (>400 LOC): este archivo concentra el render cohesivo del
// hilo —burbujas inbound/outbound, citas, reacciones, media por tipo, ticks de
// entrega y burbujas optimistas pendientes/fallidas—. Son piezas acopladas por
// el mismo layout de lista invertida; partirlas dispersaría la presentación sin
// ganar claridad. El composer sí vive aparte (`MessageComposer`).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/auth/role_privilege.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/util/smart_timestamp.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/message.dart';
import '../../domain/failures/messages_failure.dart';
import '../../domain/reactions.dart';
import '../bloc/messages_bloc.dart';
import '../bloc/thread_audio_cubit.dart';
import '../../../monitor/presentation/widgets/alert_banner.dart';
import '../../../monitor/presentation/widgets/live_activity.dart';
import '../widgets/message_composer.dart';
import '../widgets/message_media.dart';

/// Hilo de mensajes de una conversación (S09 `GET
/// /sessions/:botId/:chatLid/messages`). Consume el `MessagesBloc` del scope
/// (lo cabla la ruta con botId+chatLid). Content-only: el Scaffold y el AppBar
/// los aporta la ruta.
///
/// Abre en la cola (mensajes recientes, abajo) y carga hacia arriba al hacer
/// scroll al tope; al abrir marca el chat como leído. Lleva el composer de
/// envío al fondo (`MessageComposer`) y pinta burbujas optimistas
/// pendientes/fallidas. La media se renderiza por tipo: imagen/sticker desde la
/// URL firmada, el resto como tarjeta de tipo.
class MessageThreadPage extends StatelessWidget {
  const MessageThreadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _AudioFailuresListener(
      child: _ReactFailuresListener(
        child: BlocBuilder<MessagesBloc, MessagesState>(
          builder: (context, state) => Column(
            children: <Widget>[
              Expanded(
                child: switch (state) {
                  MessagesInitial() ||
                  MessagesLoading() => const _LoadingView(),
                  MessagesLoaded(
                    items: final items,
                    prevCursor: final prevCursor,
                    isLoadingOlder: final isLoadingOlder,
                    pending: final pending,
                  ) =>
                    (items.isEmpty && pending.isEmpty)
                        ? const _EmptyView()
                        : _ThreadView(
                            items: items,
                            pending: pending,
                            hasMore: prevCursor != null,
                            isLoadingOlder: isLoadingOlder,
                          ),
                  MessagesFailed(failure: final f) => _FailedView(failure: f),
                },
              ),
              // Alerta crítica del bot (desconexión, etc.) y actividad EN VIVO
              // entre el hilo y el composer. Inertes para no-admin (cubit sin
              // observar) ⇒ no pintan.
              const AlertBanner(),
              const LiveActivity(),
              // El composer sólo con hilo cargado: enviar exige una conversación
              // abierta (en Loading/Failed no hay a dónde escribir).
              if (state is MessagesLoaded) const MessageComposer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Anuncia con SnackBar cuando una nota de voz/audio no se pudo cargar o
/// reproducir (firma vencida, plataforma sin player). El cubit señala la URL
/// fallida en `failedUrl`; sólo el CAMBIO de ese campo dispara el aviso.
class _AudioFailuresListener extends StatelessWidget {
  const _AudioFailuresListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ThreadAudioCubit, ThreadAudioState>(
      listenWhen: (prev, next) =>
          next.failedUrl != null && prev.failedUrl != next.failedUrl,
      listener: (context, _) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo reproducir el audio')),
      ),
      child: child,
    );
  }
}

/// Anuncia los fallos de reacción con un SnackBar. La reacción se materializa
/// por el eco SSE (el bloc no emite estados al reaccionar), así que el
/// side-channel `reactFailures` es la única señal de que el POST falló; sin
/// este aviso el operador vería que su reacción "no aparece" sin explicación.
class _ReactFailuresListener extends StatefulWidget {
  const _ReactFailuresListener({required this.child});

  final Widget child;

  @override
  State<_ReactFailuresListener> createState() => _ReactFailuresListenerState();
}

class _ReactFailuresListenerState extends State<_ReactFailuresListener> {
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = context.read<MessagesBloc>().reactFailures.listen((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar la reacción')),
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('messages.empty'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Text(
          'No hay mensajes en esta conversación',
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final MessagesFailure failure;

  @override
  Widget build(BuildContext context) {
    final isNotFound = failure is MessagesNotFoundFailure;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: isNotFound
          ? const Key('messages.error.not_found')
          : const Key('messages.error.generic'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              isNotFound
                  ? 'Este bot ya no existe en tu organización'
                  : 'No pudimos cargar los mensajes',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () => context.read<MessagesBloc>().add(
                const MessagesLoadRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista del hilo. `reverse: true` ancla el render en el mensaje más reciente
/// (abajo): el item 0 (más nuevo) se pinta al fondo y el scroll hacia arriba
/// recorre lo más viejo. Al acercarse al tope (`maxScrollExtent` en una lista
/// invertida) y habiendo más tramo, dispara la carga hacia atrás.
class _ThreadView extends StatelessWidget {
  const _ThreadView({
    required this.items,
    required this.pending,
    required this.hasMore,
    required this.isLoadingOlder,
  });

  final List<Message> items;

  /// Envíos optimistas en vuelo o fallidos; se pintan como burbujas salientes
  /// al fondo del hilo (lo más nuevo), bajo el último mensaje real.
  final List<PendingSend> pending;
  final bool hasMore;
  final bool isLoadingOlder;

  bool _onScroll(BuildContext context, ScrollNotification n) {
    if (n is ScrollUpdateNotification &&
        hasMore &&
        !isLoadingOlder &&
        n.metrics.pixels >= n.metrics.maxScrollExtent - 240) {
      context.read<MessagesBloc>().add(const MessagesOlderRequested());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Las reacciones (type:'reaction') se doblan sobre su target en vez de
    // pintarse como burbuja; `renderable` son los mensajes que sí se pintan.
    final folded = foldReactions(items);
    final renderable = folded.renderable;
    // Índice por externalId para resolver las citas (reply→mensaje citado)
    // contra la ventana cargada. Un citado fuera de la ventana queda sin
    // resolver (la burbuja muestra el fallback).
    final byId = <String, Message>{for (final m in renderable) m.externalId: m};
    // Filas en ASC: separador al cambiar el día calendario + burbuja por
    // mensaje. Se construyen ASC (donde "cambio de día" es natural) y se
    // invierten para la lista reverse:true (índice 0 = fondo, lo más nuevo).
    final rowsAsc = <Widget>[];
    DateTime? day;
    for (final m in renderable) {
      final dt = DateTime.fromMillisecondsSinceEpoch(m.timestampMs);
      final mDay = DateTime(dt.year, dt.month, dt.day);
      if (day != mDay) {
        rowsAsc.add(_DaySeparator(timestampMs: m.timestampMs));
        day = mDay;
      }
      rowsAsc.add(
        _MessageBubble(
          message: m,
          quoted: m.quotedId == null ? null : byId[m.quotedId],
          reactions: folded.byTarget[m.externalId],
        ),
      );
    }
    final rows = rowsAsc.reversed.toList(growable: false);
    // Las pendientes son lo más nuevo: en la lista invertida (índice 0 = fondo)
    // ocupan el tramo inicial, en orden nueva→vieja, BAJO el último mensaje real.
    final pendingNewestFirst = pending.reversed.toList(growable: false);
    final pendingCount = pendingNewestFirst.length;
    final rowCount = rows.length;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) => _onScroll(context, n),
      child: ListView.builder(
        reverse: true,
        physics: const AlwaysScrollableScrollPhysics(),
        // El padding inferior NO suma el safe-area: el composer (abajo) lo
        // absorbe; sumarlo aquí dejaría un hueco doble sobre el composer.
        padding: const EdgeInsets.all(AppTokens.sp4),
        itemCount: pendingCount + rowCount + (isLoadingOlder ? 1 : 0),
        itemBuilder: (context, i) {
          // Tramo inferior (índices [0, pendingCount)): burbujas optimistas.
          if (i < pendingCount) {
            return _PendingBubble(pending: pendingNewestFirst[i]);
          }
          final j = i - pendingCount;
          // El item extra cae al final de la lista invertida ⇒ se pinta arriba:
          // el spinner de "cargando más viejos".
          if (j == rowCount) {
            return const Padding(
              key: Key('messages.older_loading'),
              padding: EdgeInsets.all(AppTokens.sp4),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTokens.primary,
                    ),
                  ),
                ),
              ),
            );
          }
          return rows[j];
        },
      ),
    );
  }
}

/// Separador de día estilo mensajería: cápsula centrada con la etiqueta del
/// día calendario ("Hoy"/"Ayer"/fecha). Una por día, sobre el primer mensaje
/// de ese día en la ventana cargada (paginar hacia atrás la reubica sola).
class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.timestampMs});

  final int timestampMs;

  @override
  Widget build(BuildContext context) {
    return Align(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppTokens.sp2),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp3,
          vertical: AppTokens.sp1,
        ),
        decoration: BoxDecoration(
          color: AppTokens.surface1,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(color: AppTokens.divider),
        ),
        child: Text(
          dayLabel(timestampMs),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
      ),
    );
  }
}

/// Burbuja de un envío optimista (S09): en vuelo muestra "Enviando" + reloj; si
/// falló, el motivo y acciones de reintentar/descartar. Siempre a la derecha
/// (OUTBOUND del operador). Su `Key` la indexa por `clientToken`.
class _PendingBubble extends StatelessWidget {
  const _PendingBubble({required this.pending});

  final PendingSend pending;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = pending;
    final caption = textTheme.bodyMedium?.copyWith(
      color: AppTokens.text2,
      fontSize: AppTokens.captionSize,
    );
    // Texto de la burbuja: el contenido, o una etiqueta por tipo cuando el
    // envío de media no trae caption (la nota de voz nunca lo trae).
    final body = p.type == 'text' || p.content.isNotEmpty
        ? p.content
        : _mediaPlaceholder(p.type);
    return Align(
      key: Key('message.pending.${p.clientToken}'),
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.sp4,
              vertical: AppTokens.sp3,
            ),
            decoration: BoxDecoration(
              color: _outboundFill,
              borderRadius: _bubbleRadius(mine: true),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(body, style: textTheme.bodyLarge),
                const SizedBox(height: AppTokens.sp1),
                if (p.isFailed)
                  _PendingFailed(pending: p, caption: caption)
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('Enviando', style: caption),
                      const SizedBox(width: AppTokens.sp2),
                      const Icon(
                        Icons.schedule,
                        size: 14,
                        color: AppTokens.text2,
                        semanticLabel: 'Enviando',
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pie de una burbuja fallida: motivo legible + reintentar/descartar.
class _PendingFailed extends StatelessWidget {
  const _PendingFailed({required this.pending, required this.caption});

  final PendingSend pending;
  final TextStyle? caption;

  @override
  Widget build(BuildContext context) {
    final token = pending.clientToken;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.error_outline,
              size: 14,
              color: AppTokens.danger,
              semanticLabel: 'No enviado',
            ),
            const SizedBox(width: AppTokens.sp1),
            Flexible(
              child: Text(
                _pendingErrorText(pending.failure!),
                style: caption?.copyWith(color: AppTokens.danger),
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextButton(
              key: Key('message.pending.$token.retry'),
              onPressed: () => context.read<MessagesBloc>().add(
                MessagesSendRetryRequested(token),
              ),
              child: const Text('Reintentar'),
            ),
            TextButton(
              key: Key('message.pending.$token.discard'),
              onPressed: () => context.read<MessagesBloc>().add(
                MessagesSendDiscarded(token),
              ),
              child: const Text('Descartar'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Etiqueta de la burbuja optimista de un envío de media sin caption.
String _mediaPlaceholder(String type) => switch (type) {
  'ptt' => '[nota de voz]',
  'image' => '[imagen]',
  'video' => '[video]',
  'document' => '[documento]',
  _ => '[$type]',
};

/// Motivo legible del fallo de un envío para el operador.
String _pendingErrorText(MessagesFailure f) => switch (f) {
  MessagesNotFoundFailure() =>
    'No se pudo enviar: la conversación no está disponible',
  MessagesBotPausedFailure() => 'El bot está pausado',
  MessagesNotConnectedFailure() => 'El bot no está conectado',
  MessagesValidationFailure() => 'Mensaje inválido',
  MessagesForbiddenFailure() => 'No tienes permiso para enviar',
  MessagesNetworkFailure() || MessagesTimeoutFailure() => 'Sin conexión',
  _ => 'No se pudo enviar',
};

/// Fill de la burbuja OUTBOUND: surface3 con un matiz tenue del verde de
/// sección — diferencia los lados como en mensajería sin volver fill un
/// color de acento.
final Color _outboundFill = Color.alphaBlend(
  AppTokens.chatAccent.withValues(alpha: 0.07),
  AppTokens.surface3,
);

/// Radios de burbuja con "cola": el radio inferior del lado del emisor se
/// achica (mismo idioma que `ChatBubble` del kit).
BorderRadius _bubbleRadius({required bool mine}) {
  const tail = Radius.circular(AppTokens.radiusSm);
  const full = Radius.circular(AppTokens.radiusCard);
  return BorderRadius.only(
    topLeft: full,
    topRight: full,
    bottomLeft: mine ? full : tail,
    bottomRight: mine ? tail : full,
  );
}

/// Emojis de reacción rápida del hilo (estilo mensajería).
const List<String> _quickReactions = <String>[
  '👍',
  '❤️',
  '😂',
  '😮',
  '😢',
  '🙏',
];

/// Hoja inferior de acciones sobre un mensaje (long-press): reacciones rápidas
/// y, para mensajes de texto, copiar / seleccionar texto. Para un OUTBOUND y
/// operador ADMIN+ ofrece además saltar a la corrida de IA que lo generó. Al
/// elegir una reacción despacha `MessagesReactRequested` (la reacción aparece
/// por el eco SSE; el bloc no la pinta optimista). Captura bloc/messenger/router
/// ANTES del await del sheet.
Future<void> _showMessageActions(BuildContext context, Message message) async {
  final bloc = context.read<MessagesBloc>();
  final messenger = ScaffoldMessenger.of(context);
  final messageId = message.externalId;
  final isOutbound = message.direction == MessageDirection.outbound;
  // Copiar/seleccionar sólo tienen sentido sobre texto con cuerpo; la media
  // y los mensajes vacíos no los ofrecen.
  final isText = message.type == 'text' && message.content.trim().isNotEmpty;
  // Drill-through inverso: para un OUTBOUND y operador ADMIN+, la hoja ofrece
  // saltar a la corrida de IA que generó el mensaje (el backend igual exige
  // ADMIN+ en la vista; ocultarlo evita la acción rota).
  final auth = context.read<AuthBloc>().state;
  final canDrill =
      isOutbound &&
      auth is AuthAuthenticated &&
      isAdminOrAbove(auth.identity.role);
  // Solo se resuelve el router cuando hay drill (evita exigir GoRouter en el
  // camino de pura reacción).
  final router = canDrill ? GoRouter.of(context) : null;
  // El navigator raíz se captura ANTES del await: lo usa "Seleccionar texto"
  // para abrir su hoja una vez cerrada esta, sin tocar un BuildContext que
  // cruzó el await.
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final emoji = await showAppBottomSheet<String>(
    context,
    backgroundColor: AppTokens.surface1,
    // Las acciones (reacciones + copiar/seleccionar + drill) pueden sumar más
    // alto que el tope de una hoja no controlada en pantallas chicas; con scroll
    // controlado la hoja crece al contenido y nada queda inalcanzable.
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp4,
          vertical: AppTokens.sp5,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  for (final e in _quickReactions)
                    InkWell(
                      key: Key('reaction.pick.$messageId.$e'),
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                      onTap: () => Navigator.of(sheetContext).pop(e),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTokens.sp2),
                        child: Text(e, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                ],
              ),
              if (isText) ...<Widget>[
                const Divider(height: AppTokens.sp6),
                ListTile(
                  key: Key('message.copy.$messageId'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.copy_outlined),
                  title: const Text('Copiar'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Clipboard.setData(ClipboardData(text: message.content));
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Mensaje copiado')),
                    );
                  },
                ),
                ListTile(
                  key: Key('message.select.$messageId'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.text_fields_outlined),
                  title: const Text('Seleccionar texto'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showSelectableText(rootNavigator.context, message.content);
                  },
                ),
              ],
              if (canDrill) ...<Widget>[
                const Divider(height: AppTokens.sp6),
                ListTile(
                  key: Key('message.drill.$messageId'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.psychology_outlined),
                  title: const Text('Ver razonamiento del bot'),
                  subtitle: const Text(
                    'La corrida de IA que generó este mensaje',
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    router!.push(
                      '/bots/${bloc.botId}'
                      '/sessions/${Uri.encodeComponent(bloc.chatLid)}'
                      '/ai-log?msg=${Uri.encodeComponent(messageId)}',
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  if (emoji != null) {
    bloc.add(MessagesReactRequested(messageId: messageId, emoji: emoji));
  }
}

/// Hoja inferior con el cuerpo del mensaje en un `SelectableText`, para que el
/// operador copie un fragmento (un RFC, un número de pedido) en vez del texto
/// completo.
Future<void> _showSelectableText(BuildContext context, String content) {
  final textTheme = Theme.of(context).textTheme;
  return showAppBottomSheet<void>(
    context,
    backgroundColor: AppTokens.surface1,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp4,
          vertical: AppTokens.sp5,
        ),
        child: SelectableText(
          content,
          key: const Key('message.select_sheet.text'),
          style: textTheme.bodyLarge,
        ),
      ),
    ),
  );
}

/// Burbuja de un mensaje. INBOUND a la izquierda (`surface2`), OUTBOUND a la
/// derecha (`surface3`). En grupos, el INBOUND muestra el autor (`senderLid`).
/// El texto se pinta directo; la media va por `_MediaContent`. El OUTBOUND
/// muestra su estado de entrega; las reacciones cuelgan bajo la burbuja.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.quoted, this.reactions});

  final Message message;

  /// El mensaje citado por `message.quotedId`, ya resuelto contra la ventana
  /// cargada; `null` si `message` no es reply o si el citado quedó fuera de la
  /// ventana (la cita muestra entonces su fallback).
  final Message? quoted;

  /// Reacciones agregadas sobre este mensaje (emoji + conteo), o `null`/vacío
  /// si nadie reaccionó. Las pinta una fila de pills bajo la burbuja.
  final List<ReactionTally>? reactions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final m = message;
    final isOutbound = m.direction == MessageDirection.outbound;
    final isGroupInbound = m.kind == MessageKind.group && !isOutbound;
    final isText = m.type == 'text';

    final caption = textTheme.bodyMedium?.copyWith(
      color: AppTokens.text2,
      fontSize: AppTokens.captionSize,
    );

    return Align(
      key: Key('message.${m.externalId}'),
      alignment: isOutbound ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
        child: Column(
          crossAxisAlignment: isOutbound
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            GestureDetector(
              onLongPress: () => _showMessageActions(context, m),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.sp4,
                    vertical: AppTokens.sp3,
                  ),
                  decoration: BoxDecoration(
                    // El OUTBOUND lleva un matiz sutil del verde de sección
                    // sobre surface3: distingue los lados sin gritar (el
                    // verde pleno es de acentos, no de fills).
                    color: isOutbound ? _outboundFill : AppTokens.surface2,
                    borderRadius: _bubbleRadius(mine: isOutbound),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (isGroupInbound) ...<Widget>[
                        Text(
                          m.senderLid,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTokens.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      if (m.quotedId != null) ...<Widget>[
                        _QuotedPreview(parentId: m.externalId, quoted: quoted),
                        const SizedBox(height: AppTokens.sp1),
                      ],
                      if (isText)
                        Text(m.content, style: textTheme.bodyLarge)
                      else
                        MessageMediaContent(message: m),
                      const SizedBox(height: AppTokens.sp1),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(smartTimestamp(m.timestampMs), style: caption),
                          if (isOutbound && m.status != null) ...<Widget>[
                            const SizedBox(width: AppTokens.sp2),
                            _statusTick(m.status!),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (reactions != null && reactions!.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppTokens.sp1),
              _ReactionPills(parentId: m.externalId, reactions: reactions!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fila de pills de reacción bajo la burbuja: un chip por emoji con su conteo
/// (el conteo sólo se muestra si más de uno reaccionó igual, como WhatsApp).
class _ReactionPills extends StatelessWidget {
  const _ReactionPills({required this.parentId, required this.reactions});

  final String parentId;
  final List<ReactionTally> reactions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      key: Key('message.reactions.$parentId'),
      spacing: AppTokens.sp1,
      runSpacing: AppTokens.sp1,
      children: <Widget>[
        for (final r in reactions)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.sp2,
              vertical: 1,
            ),
            decoration: BoxDecoration(
              color: AppTokens.surface2,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              border: Border.all(color: AppTokens.divider),
            ),
            child: Text(
              r.count > 1 ? '${r.emoji} ${r.count}' : r.emoji,
              style: textTheme.labelSmall?.copyWith(color: AppTokens.text1),
            ),
          ),
      ],
    );
  }
}

/// Bloque de cita estilo WhatsApp dentro de una burbuja reply: barra izquierda
/// en el verde de sección + autor y preview del mensaje citado. Si el citado no
/// está en la ventana cargada (`quoted == null`) cae a un fallback neutro — la
/// cita igual se dibuja para que el reply no quede huérfano.
class _QuotedPreview extends StatelessWidget {
  const _QuotedPreview({required this.parentId, required this.quoted});

  /// `externalId` del mensaje que contiene esta cita (para el `Key`).
  final String parentId;
  final Message? quoted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final q = quoted;
    final author = q == null
        ? null
        : (q.direction == MessageDirection.outbound ? 'Tú' : q.senderLid);
    final preview = q == null
        ? 'Mensaje original no disponible'
        : (q.type == 'text' ? q.content : '[${q.type}]');

    return Container(
      key: Key('message.quoted.$parentId'),
      decoration: BoxDecoration(
        color: AppTokens.bgBase.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              key: Key('message.quoted.$parentId.bar'),
              width: 3,
              color: AppTokens.chatAccent,
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.sp2,
                  vertical: AppTokens.sp1,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (author != null)
                      Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: AppTokens.chatAccent,
                        ),
                      ),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppTokens.text2,
                        fontStyle: q == null ? FontStyle.italic : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tick de entrega estilo mensajería: ✓ enviado, ✓✓ entregado (gris), ✓✓ leído
/// (verde de la sección de chat), ⚠ falló (rojo). El receipt en vivo
/// (`message.status`) repinta este ícono solo. Conserva la etiqueta de texto
/// como `semanticLabel` para que un lector de pantalla anuncie "Entregado/
/// Leído", no un glifo.
Widget _statusTick(MessageStatus s) {
  final (IconData icon, Color color) = switch (s) {
    MessageStatus.sent => (Icons.done, AppTokens.text2),
    MessageStatus.delivered => (Icons.done_all, AppTokens.text2),
    MessageStatus.read => (Icons.done_all, AppTokens.chatAccent),
    MessageStatus.failed => (Icons.error_outline, AppTokens.danger),
  };
  return Icon(icon, size: 16, color: color, semanticLabel: _statusLabel(s));
}

String _statusLabel(MessageStatus s) => switch (s) {
  MessageStatus.sent => 'Enviado',
  MessageStatus.delivered => 'Entregado',
  MessageStatus.read => 'Leído',
  MessageStatus.failed => 'Falló',
};
