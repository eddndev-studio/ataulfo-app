import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';

/// Una barra del waveform en vivo lista para pintar: a qué muestra del buffer
/// corresponde y dónde va su centro en X. La altura la resuelve el pintor con
/// el valor de amplitud de esa muestra.
@immutable
class WaveBar {
  const WaveBar({required this.sampleIndex, required this.xCenter});

  /// Índice en el buffer de muestras (el más nuevo es `count - 1`).
  final int sampleIndex;

  /// Centro horizontal de la barra en el lienzo.
  final double xCenter;
}

/// Geometría del waveform en vivo: barras de grosor ([barWidth]) y separación
/// ([gap]) CONSTANTES, ancladas a la derecha —la muestra más nueva
/// (`count - 1`) entra por el borde derecho— y deslizándose a la izquierda con
/// [phase] (0..1, avance hacia la siguiente muestra). Devuelve sólo las barras
/// visibles, de la más nueva a la más vieja.
///
/// Es un carrusel: el grosor y el paso no dependen de cuántas muestras haya
/// (no reescala ni se "empuja"); al llegar una muestra el tren simplemente se
/// corre un paso a la izquierda.
@visibleForTesting
List<WaveBar> waveformBars({
  required int count,
  required double width,
  required double barWidth,
  required double gap,
  required double phase,
}) {
  final pitch = barWidth + gap;
  if (count <= 0 || width <= 0 || pitch <= 0) return const <WaveBar>[];
  final out = <WaveBar>[];
  for (var k = 0; k < count; k++) {
    final xCenter = width - barWidth / 2 - (k + phase) * pitch;
    // Ya salió por completo por la izquierda: nada más que dibujar.
    if (xCenter + barWidth / 2 < 0) break;
    out.add(WaveBar(sampleIndex: count - 1 - k, xCenter: xCenter));
  }
  return out;
}

/// Waveform en vivo de la grabación: mantiene un buffer de las últimas
/// amplitudes y las pinta como un tren de barras que se desliza de derecha a
/// izquierda (la más nueva entra por la derecha). Es feedback visual efímero
/// (no es el waveform de 64 muestras que viaja al wire — ese lo computa el
/// grabador).
///
/// El deslizamiento es continuo: entre muestra y muestra un controlador anima
/// `phase` de 0 a 1 (un paso de barra) sincronizado con la cadencia del
/// grabador, de modo que el tren fluye en vez de saltar un paso por muestra.
class LiveWaveform extends StatefulWidget {
  const LiveWaveform({
    required this.amplitude,
    this.paused = false,
    this.barWidth = 3.0,
    this.gap = 2.0,
    super.key,
  });

  /// Amplitud del micrófono (0-100) en vivo.
  final Stream<double> amplitude;

  /// En pausa: el tren se congela (ni avanza ni desliza) hasta reanudar.
  final bool paused;

  final double barWidth;
  final double gap;

  @override
  State<LiveWaveform> createState() => _LiveWaveformState();
}

class _LiveWaveformState extends State<LiveWaveform>
    with SingleTickerProviderStateMixin {
  // El grabador emite amplitud cada ~100ms; el controlador desliza un paso en
  // esa ventana para que el avance sea continuo y se re-sincronice al llegar
  // cada muestra.
  static const Duration _slide = Duration(milliseconds: 100);

  // Tope del buffer: las muestras que se salen por la izquierda se cullan en
  // [waveformBars], así que esto sólo acota la memoria a un par de pantallas.
  static const int _maxBars = 96;

  final List<double> _bars = <double>[];
  late final AnimationController _phase = AnimationController(
    vsync: this,
    duration: _slide,
  );
  StreamSubscription<double>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.amplitude.listen(_onSample);
  }

  void _onSample(double v) {
    if (!mounted || widget.paused) return;
    setState(() {
      _bars.add(v.clamp(0, 100));
      if (_bars.length > _maxBars) _bars.removeAt(0);
    });
    // Re-sincroniza el deslizamiento con la llegada de la muestra: el tren
    // arranca su paso desde cero justo cuando entra la barra nueva.
    _phase.forward(from: 0);
  }

  @override
  void didUpdateWidget(LiveWaveform old) {
    super.didUpdateWidget(old);
    if (widget.paused && !old.paused) {
      _phase.stop();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: AnimatedBuilder(
        animation: _phase,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _WaveformPainter(
            bars: _bars,
            phase: widget.paused ? 0.0 : _phase.value,
            barWidth: widget.barWidth,
            gap: widget.gap,
            color: AppTokens.chatAccent,
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.bars,
    required this.phase,
    required this.barWidth,
    required this.gap,
    required this.color,
  });

  final List<double> bars;
  final double phase;
  final double barWidth;
  final double gap;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = waveformBars(
      count: bars.length,
      width: size.width,
      barWidth: barWidth,
      gap: gap,
      phase: phase,
    );
    if (layout.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    final mid = size.height / 2;
    for (final b in layout) {
      final h = (bars[b.sampleIndex] / 100 * size.height).clamp(
        2.0,
        size.height,
      );
      canvas.drawLine(
        Offset(b.xCenter, mid - h / 2),
        Offset(b.xCenter, mid + h / 2),
        paint,
      );
    }
  }

  // `bars` es la MISMA lista mutable entre rebuilds (se muta in-place), así que
  // comparar su longitud daría siempre igual. El pintor se reconstruye en cada
  // tick del controlador de `phase` (vía AnimatedBuilder) y al llegar una
  // muestra (setState), que es justo la cadencia a la que hay que repintar.
  @override
  bool shouldRepaint(_WaveformPainter old) => true;
}
