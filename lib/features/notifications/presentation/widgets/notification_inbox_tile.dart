import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/util/smart_timestamp.dart';
import '../../domain/entities/notification_inbox_item.dart';
import '../../domain/entities/notification_preference.dart';
import '../bloc/notifications_bloc.dart';

/// Fila de la bandeja de notificaciones. El tap de la tarjeta marca leído (y,
/// para un agent.alert con chat conocido, navega a la conversación). El detalle
/// técnico (código + razón cruda del servidor) va en una sección colapsable con
/// su propio botón, para soporte/depuración sin ensuciar la lectura normal.
class NotificationInboxTile extends StatefulWidget {
  const NotificationInboxTile({required this.item, super.key});

  final NotificationInboxItem item;

  @override
  State<NotificationInboxTile> createState() => _NotificationInboxTileState();
}

class _NotificationInboxTileState extends State<NotificationInboxTile> {
  bool _expanded = false;

  NotificationInboxItem get _item => widget.item;

  /// El código estable y la razón cruda viajan en el payload (hoy sólo los
  /// flujos fallidos los portan). El `body` ya es la copy humana, así que sólo
  /// ofrecemos expandir cuando hay algo técnico que mostrar.
  String? get _code {
    final v = _item.payload['code'];
    return (v != null && v.isNotEmpty) ? v : null;
  }

  String? get _detail {
    final v = _item.payload['detail'];
    return (v != null && v.isNotEmpty) ? v : null;
  }

  bool get _hasDetail => _code != null || _detail != null;

  /// Un agent.alert con chat conocido navega a la conversación (el bot pidió
  /// ayuda AHÍ) y de paso se marca leído; el resto conserva el tap de
  /// marcar-leído de siempre.
  void _onTap() {
    context.read<NotificationsBloc>().add(
      NotificationMarkReadRequested(_item.id),
    );
    final botId = _item.botId;
    final chatLid = _item.chatLid;
    if (_item.eventType == NotificationEventType.agentAlert &&
        botId != null &&
        chatLid != null) {
      context.push('/bots/$botId/sessions/${Uri.encodeComponent(chatLid)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: Key('notifications.item.${_item.id}'),
      onTap: _onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(_iconFor(_item.eventType), color: _colorFor(_item.priority)),
              const SizedBox(width: AppTokens.sp4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _item.title,
                            style: const TextStyle(
                              color: AppTokens.text1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTokens.sp3),
                        Text(
                          smartTimestamp(
                            _item.updatedAt.millisecondsSinceEpoch,
                          ),
                          style: const TextStyle(
                            color: AppTokens.textDisabled,
                            fontSize: AppTokens.captionSize,
                            fontWeight: AppTokens.captionWeight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.sp2),
                    Text(
                      _item.body,
                      style: const TextStyle(color: AppTokens.text2),
                    ),
                    if (_item.count > 1) ...<Widget>[
                      const SizedBox(height: AppTokens.sp3),
                      Text(
                        '${_item.count} eventos',
                        style: const TextStyle(color: AppTokens.textDisabled),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.sp3),
              _trailing(),
            ],
          ),
          if (_expanded && _hasDetail) ...<Widget>[
            const SizedBox(height: AppTokens.sp3),
            _DetailSection(
              key: Key('notifications.item.${_item.id}.detail'),
              code: _code,
              detail: _detail,
            ),
          ],
        ],
      ),
    );
  }

  /// Con detalle técnico: un botón expandir que absorbe su propio tap (no
  /// dispara el tap de la tarjeta). Sin detalle: el ícono de "hecho" de
  /// siempre —un chevron prometería un detalle que no existe—.
  Widget _trailing() {
    if (!_hasDetail) {
      return const Icon(Icons.done_outlined, color: AppTokens.text2);
    }
    return IconButton(
      key: Key('notifications.item.${_item.id}.expand'),
      icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
      color: AppTokens.text2,
      tooltip: _expanded ? 'Ocultar detalle' : 'Ver detalle técnico',
      visualDensity: VisualDensity.compact,
      onPressed: () => setState(() => _expanded = !_expanded),
    );
  }

  static IconData _iconFor(NotificationEventType type) {
    return switch (type) {
      NotificationEventType.messageInboundNew => Icons.chat_bubble_outline,
      NotificationEventType.botDisconnected => Icons.link_off_outlined,
      NotificationEventType.flowFailed => Icons.error_outline,
      NotificationEventType.agentAlert => Icons.support_agent_outlined,
    };
  }

  static Color _colorFor(NotificationPriority priority) {
    return switch (priority) {
      NotificationPriority.low => AppTokens.success,
      NotificationPriority.normal => AppTokens.primary,
      NotificationPriority.high => AppTokens.danger,
    };
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.code, required this.detail, super.key});

  final String? code;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.sp3),
      decoration: BoxDecoration(
        color: AppTokens.surface3,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (code != null)
            Text(
              code!,
              style: const TextStyle(
                color: AppTokens.text2,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          if (code != null && detail != null)
            const SizedBox(height: AppTokens.sp2),
          if (detail != null)
            SelectableText(
              detail!,
              style: const TextStyle(
                color: AppTokens.text2,
                fontFamily: 'monospace',
                fontSize: AppTokens.captionSize,
              ),
            ),
        ],
      ),
    );
  }
}
