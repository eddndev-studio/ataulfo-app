import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';

/// `mm:ss` del tiempo de grabación (compartido por las barras de voz).
String _fmtClock(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Barra que reemplaza al composer mientras se graba una nota de voz: punto
/// rojo + tiempo transcurrido + waveform en vivo + descartar + enviar. La
/// mecánica de gesto (mantener/bloquear/deslizar a cancelar) se monta encima de
/// esta barra; aquí vive el estado visual mínimo.
class VoiceRecordingBar extends StatelessWidget {
  const VoiceRecordingBar({
    required this.elapsed,
    required this.amplitude,
    required this.onCancel,
    required this.onSend,
    this.sending = false,
    super.key,
  });

  /// Tiempo transcurrido de la grabación (lo emite el grabador).
  final Stream<Duration> elapsed;

  /// Amplitud del micrófono (0-100) en vivo: alimenta el waveform.
  final Stream<double> amplitude;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  /// En vuelo (subiendo el clip): deshabilita enviar y muestra un spinner.
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Reemplaza al composer en el mismo lugar; reproduce su cromo (relleno
    // surface1 + divisor superior + inset de la nav) para que no quede detrás
    // de la barra del sistema ni flote translúcida sobre el chat.
    return Container(
      key: const Key('voice.recording.bar'),
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp3,
        AppTokens.sp2,
        AppTokens.sp3,
        AppTokens.sp2 + context.safeBottomInset,
      ),
      decoration: const BoxDecoration(
        color: AppTokens.surface1,
        border: Border(top: BorderSide(color: AppTokens.divider)),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            key: const Key('voice.cancel'),
            tooltip: 'Descartar',
            color: AppTokens.danger,
            onPressed: sending ? null : onCancel,
            icon: const Icon(Icons.delete_outline),
          ),
          const Icon(
            Icons.fiber_manual_record,
            size: 12,
            color: AppTokens.danger,
          ),
          const SizedBox(width: AppTokens.sp2),
          StreamBuilder<Duration>(
            stream: elapsed,
            initialData: Duration.zero,
            builder: (context, snap) => Text(
              _fmtClock(snap.data ?? Duration.zero),
              key: const Key('voice.timer'),
              style: textTheme.bodyLarge,
            ),
          ),
          const SizedBox(width: AppTokens.sp3),
          Expanded(child: _LiveWaveform(amplitude: amplitude)),
          const SizedBox(width: AppTokens.sp2),
          IconButton.filled(
            key: const Key('voice.send'),
            tooltip: 'Enviar nota de voz',
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

/// Waveform en vivo: mantiene una ventana deslizante de las últimas amplitudes
/// y las pinta como barras. Es feedback visual efímero (no es el waveform de 64
/// muestras que viaja al wire — ese lo computa el grabador).
class _LiveWaveform extends StatefulWidget {
  const _LiveWaveform({required this.amplitude});

  final Stream<double> amplitude;

  @override
  State<_LiveWaveform> createState() => _LiveWaveformState();
}

class _LiveWaveformState extends State<_LiveWaveform> {
  static const int _maxBars = 48;
  final List<double> _bars = <double>[];
  StreamSubscription<double>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.amplitude.listen((v) {
      if (!mounted) return;
      setState(() {
        _bars.add(v.clamp(0, 100));
        if (_bars.length > _maxBars) _bars.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: CustomPaint(
        size: Size.infinite,
        painter: _WaveformPainter(bars: _bars, color: AppTokens.chatAccent),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.bars, required this.color});

  final List<double> bars;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    const gap = 2.0;
    final barW = (size.width / bars.length - gap).clamp(1.0, 6.0);
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barW;
    final mid = size.height / 2;
    for (var i = 0; i < bars.length; i++) {
      final x = i * (size.width / bars.length) + barW / 2;
      final h = (bars[i] / 100 * size.height).clamp(2.0, size.height);
      canvas.drawLine(Offset(x, mid - h / 2), Offset(x, mid + h / 2), paint);
    }
  }

  // `bars` es la MISMA lista mutable entre rebuilds (se muta in-place en el
  // listener), así que comparar referencias daría siempre false y el canvas no
  // se repintaría nunca. El widget sólo se reconstruye al llegar una muestra
  // nueva de amplitud, así que repintar siempre tiene la cadencia correcta.
  @override
  bool shouldRepaint(_WaveformPainter old) => true;
}

/// Barra del estado MANTENIENDO (dedo abajo, aún sin bloquear), al estilo de
/// WhatsApp: mismo cromo que el composer, con la pista de "desliza para
/// cancelar" y, arriba, un candado que se ilumina conforme el dedo sube hacia el
/// umbral de bloqueo. El micrófono —que el gesto del composer sigue rastreando—
/// se monta en [trailing]. Al bloquear, el composer la cambia por la
/// [VoiceRecordingBar] (con botones de enviar/descartar).
class VoiceHoldBar extends StatelessWidget {
  const VoiceHoldBar({
    required this.elapsed,
    required this.cancelArmed,
    required this.lockProgress,
    required this.trailing,
    super.key,
  });

  /// Tiempo transcurrido de la grabación (lo emite el grabador).
  final Stream<Duration> elapsed;

  /// El dedo cruzó el umbral de cancelar (deslizó a la izquierda): la barra lo
  /// señala en rojo; soltar descarta.
  final bool cancelArmed;

  /// Avance hacia el bloqueo (0..1): ilumina el candado conforme el dedo sube.
  final double lockProgress;

  /// El micrófono (lo provee el composer; el gesto lo sigue rastreando).
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final locking = lockProgress >= 1.0;
    return Container(
      key: const Key('voice.hold.bar'),
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp3,
        AppTokens.sp2,
        AppTokens.sp3,
        AppTokens.sp2 + context.safeBottomInset,
      ),
      decoration: const BoxDecoration(
        color: AppTokens.surface1,
        border: Border(top: BorderSide(color: AppTokens.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Opacity(
            opacity: (0.35 + 0.65 * lockProgress).clamp(0.0, 1.0),
            child: Column(
              key: const Key('voice.lock.hint'),
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: locking ? AppTokens.chatAccent : AppTokens.text2,
                ),
                const Icon(
                  Icons.keyboard_arrow_up,
                  size: 16,
                  color: AppTokens.text2,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.sp1),
          Row(
            children: <Widget>[
              const Icon(
                Icons.fiber_manual_record,
                size: 12,
                color: AppTokens.danger,
              ),
              const SizedBox(width: AppTokens.sp2),
              StreamBuilder<Duration>(
                stream: elapsed,
                initialData: Duration.zero,
                builder: (context, snap) => Text(
                  _fmtClock(snap.data ?? Duration.zero),
                  key: const Key('voice.timer'),
                  style: textTheme.bodyLarge,
                ),
              ),
              const SizedBox(width: AppTokens.sp3),
              Expanded(
                child: cancelArmed
                    ? Text(
                        'Suelta para cancelar',
                        key: const Key('voice.cancelArmed'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppTokens.danger,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.chevron_left,
                            size: 18,
                            color: AppTokens.text2,
                          ),
                          Flexible(
                            child: Text(
                              'Desliza para cancelar',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppTokens.text2,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: AppTokens.sp2),
              trailing,
            ],
          ),
        ],
      ),
    );
  }
}
