import 'package:flutter/material.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import 'live_waveform.dart';

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
    required this.onPauseResume,
    this.paused = false,
    this.sending = false,
    super.key,
  });

  /// Tiempo transcurrido de la grabación (lo emite el grabador).
  final Stream<Duration> elapsed;

  /// Amplitud del micrófono (0-100) en vivo: alimenta el waveform.
  final Stream<double> amplitude;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  /// Pausa/reanuda la grabación (manos libres): el tiempo y el waveform se
  /// congelan sin descartar el clip.
  final VoidCallback onPauseResume;

  /// Grabación pausada: el waveform se congela y el botón muestra "reanudar".
  final bool paused;

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
          Expanded(child: LiveWaveform(amplitude: amplitude, paused: paused)),
          const SizedBox(width: AppTokens.sp1),
          IconButton(
            key: const Key('voice.pauseToggle'),
            tooltip: paused ? 'Reanudar' : 'Pausar',
            color: AppTokens.text1,
            onPressed: sending ? null : onPauseResume,
            icon: Icon(paused ? Icons.play_arrow : Icons.pause),
          ),
          const SizedBox(width: AppTokens.sp1),
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
    this.sending = false,
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

  /// Se soltó manteniendo (envío directo) y el clip se está subiendo: oculta las
  /// pistas de gesto y muestra "Enviando…" en vez de dejar la barra colgada con
  /// "desliza para cancelar" durante la subida.
  final bool sending;

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
          // Mientras sube no hay gesto que guiar: oculta el candado.
          if (!sending)
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
              Expanded(child: _hint(textTheme)),
              const SizedBox(width: AppTokens.sp2),
              trailing,
            ],
          ),
        ],
      ),
    );
  }

  Widget _hint(TextTheme textTheme) {
    if (sending) {
      return Row(
        key: const Key('voice.sending'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppTokens.sp2),
          Flexible(
            child: Text(
              'Enviando…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
          ),
        ],
      );
    }
    if (cancelArmed) {
      return Text(
        'Suelta para cancelar',
        key: const Key('voice.cancelArmed'),
        style: textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.chevron_left, size: 18, color: AppTokens.text2),
        Flexible(
          child: Text(
            'Desliza para cancelar',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
        ),
      ],
    );
  }
}
