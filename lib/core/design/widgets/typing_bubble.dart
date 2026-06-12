import 'package:flutter/material.dart';

import '../tokens.dart';

/// Indicador de "escribiendo": burbuja del interlocutor con tres puntos que
/// pulsan en cascada. Reemplaza los textos estáticos («Escribiendo…») en
/// todas las superficies de chat — comunica actividad sin prometer un
/// streaming que el turno síncrono no tiene.
///
/// El pulso es un loop continuo: NO montar bajo `pumpAndSettle` en tests
/// (nunca asienta); avanzar frames con `pump(duration)`.
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  static const Duration _cycle = Duration(milliseconds: 900);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _cycle,
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Opacidad del punto [i]: una onda desfasada un tercio de ciclo por punto,
  /// oscilando entre 0.25 y 1.0.
  double _opacityOf(int i) {
    final phase = (_pulse.value + i / 3.0) % 1.0;
    final wave = (phase < 0.5 ? phase : 1.0 - phase) * 2.0; // triángulo 0→1→0
    return 0.25 + 0.75 * wave;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.sp4,
            vertical: AppTokens.sp3,
          ),
          decoration: const BoxDecoration(
            color: AppTokens.surface2,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppTokens.radiusCard),
              topRight: Radius.circular(AppTokens.radiusCard),
              bottomLeft: Radius.circular(AppTokens.radiusSm),
              bottomRight: Radius.circular(AppTokens.radiusCard),
            ),
          ),
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < 3; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: AppTokens.sp1),
                  Opacity(
                    opacity: _opacityOf(i),
                    child: Container(
                      key: Key('typing_bubble.dot.$i'),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTokens.text2,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
