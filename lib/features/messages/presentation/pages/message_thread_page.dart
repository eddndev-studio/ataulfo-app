import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../domain/entities/message.dart';
import '../../domain/failures/messages_failure.dart';
import '../bloc/messages_bloc.dart';

/// Hilo de mensajes de una conversación (S09 `GET
/// /sessions/:botId/:chatLid/messages`). Consume el `MessagesBloc` del scope
/// (lo cabla la ruta con botId+chatLid). Content-only: el Scaffold y el AppBar
/// los aporta la ruta.
///
/// Abre en la cola (mensajes recientes, abajo) y carga hacia arriba al hacer
/// scroll al tope. Slice 1: sólo lectura (enviar es rebanada posterior); los
/// tipos no-texto se pintan como placeholder (la media no se descarga aún).
class MessageThreadPage extends StatelessWidget {
  const MessageThreadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MessagesBloc, MessagesState>(
      builder: (context, state) => switch (state) {
        MessagesInitial() || MessagesLoading() => const _LoadingView(),
        MessagesLoaded(
          items: final items,
          prevCursor: final prevCursor,
          isLoadingOlder: final isLoadingOlder,
        ) =>
          items.isEmpty
              ? const _EmptyView()
              : _ThreadView(
                  items: items,
                  hasMore: prevCursor != null,
                  isLoadingOlder: isLoadingOlder,
                ),
        MessagesFailed(failure: final f) => _FailedView(failure: f),
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
    required this.hasMore,
    required this.isLoadingOlder,
  });

  final List<Message> items;
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
    // items viene ASC (más viejo→más nuevo); invertimos para que el índice 0
    // (más nuevo) quede al fondo con reverse:true.
    final newestFirst = items.reversed.toList(growable: false);
    // Índice por externalId para resolver las citas (reply→mensaje citado)
    // contra la ventana cargada. Un citado fuera de la ventana queda sin
    // resolver (la burbuja muestra el fallback).
    final byId = <String, Message>{for (final m in items) m.externalId: m};
    return NotificationListener<ScrollNotification>(
      onNotification: (n) => _onScroll(context, n),
      child: ListView.builder(
        reverse: true,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp4,
          AppTokens.sp4,
          AppTokens.sp4,
          AppTokens.sp4 + context.safeBottomInset,
        ),
        itemCount: newestFirst.length + (isLoadingOlder ? 1 : 0),
        itemBuilder: (context, i) {
          // El item extra cae al final de la lista invertida ⇒ se pinta arriba:
          // el spinner de "cargando más viejos".
          if (i == newestFirst.length) {
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
          final m = newestFirst[i];
          return _MessageBubble(
            message: m,
            quoted: m.quotedId == null ? null : byId[m.quotedId],
          );
        },
      ),
    );
  }
}

/// Burbuja de un mensaje. INBOUND a la izquierda (`surface2`), OUTBOUND a la
/// derecha (`surface3`). En grupos, el INBOUND muestra el autor (`senderLid`,
/// no hay nombre aún). Tipos no-texto → placeholder `[tipo]` (la media no se
/// descarga en este slice). El OUTBOUND muestra su estado de entrega.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.quoted});

  final Message message;

  /// El mensaje citado por `message.quotedId`, ya resuelto contra la ventana
  /// cargada; `null` si `message` no es reply o si el citado quedó fuera de la
  /// ventana (la cita muestra entonces su fallback).
  final Message? quoted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final m = message;
    final isOutbound = m.direction == MessageDirection.outbound;
    final isGroupInbound = m.kind == MessageKind.group && !isOutbound;
    final isText = m.type == 'text';
    final body = isText ? m.content : '[${m.type}]';

    final caption = textTheme.bodyMedium?.copyWith(
      color: AppTokens.text2,
      fontSize: AppTokens.captionSize,
    );

    return Align(
      key: Key('message.${m.externalId}'),
      alignment: isOutbound ? Alignment.centerRight : Alignment.centerLeft,
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
              color: isOutbound ? AppTokens.surface3 : AppTokens.surface2,
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
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
                Text(
                  body,
                  style: isText
                      ? textTheme.bodyLarge
                      : textTheme.bodyLarge?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppTokens.text2,
                        ),
                ),
                const SizedBox(height: AppTokens.sp1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(_hhmm(m.timestampMs), style: caption),
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

/// Hora local HH:mm del epoch en ms. Formateo manual para no arrastrar `intl`
/// por un caption; el hilo no necesita fecha completa en este slice.
String _hhmm(int timestampMs) {
  final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
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
