import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/entities/message.dart';

/// Estado de entrega de un mensaje saliente.
///
/// La forma del glifo diferencia enviado, entregado y fallido; el color de
/// conversación distingue el leído. La etiqueta semántica evita que el lector
/// de pantalla tenga que interpretar una o dos palomitas visuales.
class MessageDeliveryIndicator extends StatelessWidget {
  const MessageDeliveryIndicator({super.key, required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (status) {
      MessageStatus.sent => (Icons.done, AppTokens.text2, 'Enviado'),
      MessageStatus.delivered => (Icons.done_all, AppTokens.text2, 'Entregado'),
      MessageStatus.read => (Icons.done_all, AppTokens.chatAccent, 'Leído'),
      MessageStatus.failed => (Icons.error_outline, AppTokens.danger, 'Falló'),
    };
    return Icon(
      icon,
      key: const ValueKey<String>('message_delivery_indicator.icon'),
      size: 16,
      color: color,
      semanticLabel: label,
    );
  }
}
