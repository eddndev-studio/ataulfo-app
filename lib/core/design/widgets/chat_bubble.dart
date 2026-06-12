import 'package:flutter/material.dart';

import '../tokens.dart';

/// Burbuja de chat canónica del design system: el contenedor que comparten
/// TODAS las superficies conversacionales (hilo real, entrenador, probar
/// bot). Resuelve alineación, ancho máximo, color por lado y la "cola"
/// (el radio inferior del lado del emisor se achica, como en mensajería).
///
/// Entra con un fade + deslizamiento sutil: es lo que hace sentir "en vivo"
/// la llegada de mensajes sin fingir streaming. La animación corre una vez
/// por montaje (un item que vuelve a entrar al viewport re-anima apenas
/// `durationFast`; imperceptible en scroll).
class ChatBubble extends StatefulWidget {
  const ChatBubble({
    super.key,
    required this.mine,
    required this.child,
    this.color,
  });

  /// `true` ⇒ emisor local: derecha + [AppTokens.surface3]. `false` ⇒
  /// interlocutor: izquierda + [AppTokens.surface2].
  final bool mine;

  final Widget child;

  /// Override del fill (p. ej. burbujas pendientes/fallidas que matizan).
  final Color? color;

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: AppTokens.durationFast,
  )..forward();

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.mine;
    const tail = Radius.circular(AppTokens.radiusSm);
    const full = Radius.circular(AppTokens.radiusCard);

    final bubble = Container(
      key: const Key('chat_bubble.box'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sp4,
        vertical: AppTokens.sp3,
      ),
      decoration: BoxDecoration(
        color: widget.color ?? (mine ? AppTokens.surface3 : AppTokens.surface2),
        borderRadius: BorderRadius.only(
          topLeft: full,
          topRight: full,
          bottomLeft: mine ? full : tail,
          bottomRight: mine ? tail : full,
        ),
      ),
      child: widget.child,
    );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _entry, curve: AppTokens.ease),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: _entry, curve: AppTokens.ease)),
              child: bubble,
            ),
          ),
        ),
      ),
    );
  }
}
