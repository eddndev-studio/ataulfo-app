import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../bloc/thread_audio_cubit.dart';

/// Burbuja de audio reproducible: botón play/pausa + barra de progreso buscable
/// + posición/duración + control de velocidad. El estado vive en el
/// [ThreadAudioCubit] del hilo (un player): esta burbuja está "activa" sólo si
/// la fuente del player es SU URL. Selecciona una vista mínima del estado para
/// que los ticks de posición de la fuente activa no reconstruyan las demás
/// burbujas de audio del hilo.
class AudioMessageContent extends StatelessWidget {
  const AudioMessageContent({
    super.key,
    required this.id,
    required this.url,
    required this.ptt,
  });

  final String id;
  final String url;
  final bool ptt;

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static String _fmtSpeed(double speed) {
    final n = speed == speed.truncateToDouble()
        ? speed.toInt().toString()
        : speed.toString();
    return '${n}x';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocSelector<ThreadAudioCubit, ThreadAudioState, _AudioView>(
      selector: (state) => state.url == url
          ? _AudioView(
              active: true,
              playing: state.playing,
              position: state.position,
              duration: state.duration,
              speed: state.speed,
            )
          : const _AudioView.inactive(),
      builder: (context, v) {
        final position = v.active ? v.position : Duration.zero;
        final duration = v.active ? v.duration : null;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 40,
              height: 40,
              child: Material(
                color: AppTokens.chatAccent,
                shape: const CircleBorder(),
                child: InkWell(
                  key: Key('message.audio.$id.toggle'),
                  customBorder: const CircleBorder(),
                  onTap: () => context.read<ThreadAudioCubit>().toggle(url),
                  child: Icon(
                    v.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: AppTokens.onPrimary,
                    semanticLabel: v.playing ? 'Pausar' : 'Reproducir',
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTokens.sp3),
            // Flexible para que en pantallas angostas (split-screen, ~320dp) o
            // con escala de texto grande la barra/etiqueta encojan en vez de
            // desbordar el ancho de la burbuja.
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _AudioSeekBar(
                    id: id,
                    active: v.active,
                    position: position,
                    duration: duration,
                  ),
                  const SizedBox(height: AppTokens.sp1),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        ptt ? Icons.mic_none : Icons.audiotrack_outlined,
                        size: 12,
                        color: AppTokens.text2,
                      ),
                      const SizedBox(width: AppTokens.sp1),
                      Flexible(
                        child: Text(
                          v.active
                              ? '${_fmt(position)}'
                                    '${duration != null ? ' / ${_fmt(duration)}' : ''}'
                              : (ptt ? 'Nota de voz' : 'Audio'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: AppTokens.text2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (v.active) ...<Widget>[
              const SizedBox(width: AppTokens.sp2),
              InkWell(
                key: Key('message.audio.$id.speed'),
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                onTap: () => context.read<ThreadAudioCubit>().cycleSpeed(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.sp2,
                    vertical: AppTokens.sp1,
                  ),
                  decoration: BoxDecoration(
                    color: AppTokens.bgBase.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  ),
                  child: Text(
                    _fmtSpeed(v.speed),
                    style: textTheme.labelSmall?.copyWith(
                      color: AppTokens.chatAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Vista mínima del estado de audio para una burbuja. Si está activa refleja
/// transporte/velocidad; si no, un valor constante — así los ticks de posición
/// de la fuente activa no disparan rebuild en las burbujas inactivas.
class _AudioView {
  const _AudioView({
    required this.active,
    required this.playing,
    required this.position,
    required this.duration,
    required this.speed,
  });

  const _AudioView.inactive()
    : active = false,
      playing = false,
      position = Duration.zero,
      duration = null,
      speed = 1.0;

  final bool active;
  final bool playing;
  final Duration position;
  final Duration? duration;
  final double speed;

  @override
  bool operator ==(Object other) =>
      other is _AudioView &&
      other.active == active &&
      other.playing == playing &&
      other.position == position &&
      other.duration == duration &&
      other.speed == speed;

  @override
  int get hashCode => Object.hash(active, playing, position, duration, speed);
}

/// Barra de progreso buscable de la nota activa: un [Slider] fino con estado de
/// arrastre transitorio. Mientras el dedo arrastra sigue al dedo; al soltar
/// aplica el seek y conserva el valor soltado hasta que el estado del cubit
/// refleja el salto (sin parpadeo de retroceso). Deshabilitada (sin thumb
/// interactivo) si la burbuja no es la fuente activa o aún no hay duración.
class _AudioSeekBar extends StatefulWidget {
  const _AudioSeekBar({
    required this.id,
    required this.active,
    required this.position,
    required this.duration,
  });

  final String id;
  final bool active;
  final Duration position;
  final Duration? duration;

  @override
  State<_AudioSeekBar> createState() => _AudioSeekBarState();
}

class _AudioSeekBarState extends State<_AudioSeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.duration?.inMilliseconds ?? 0;
    final enabled = widget.active && totalMs > 0;
    final progress = enabled
        ? (widget.position.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;
    final value = _dragValue ?? progress;
    return ConstrainedBox(
      // Ancho objetivo de 150; dentro de un Flexible se reduce a lo disponible
      // en pantallas angostas en vez de forzar un desborde.
      constraints: const BoxConstraints(maxWidth: 150),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 4,
          activeTrackColor: AppTokens.chatAccent,
          inactiveTrackColor: AppTokens.bgBase.withValues(alpha: 0.4),
          thumbColor: AppTokens.chatAccent,
          overlayColor: AppTokens.chatAccent.withValues(alpha: 0.15),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        ),
        child: Slider(
          key: Key('message.audio.${widget.id}.progress'),
          value: value,
          onChanged: enabled ? (v) => setState(() => _dragValue = v) : null,
          onChangeEnd: enabled
              ? (v) async {
                  // Conserva el valor soltado mientras el seek viaja al engine;
                  // el cubit emite la posición saltada antes de que el await
                  // resuelva, así al limpiar el drag la barra ya está en el
                  // destino (sin retroceso de un frame). El guard evita pisar
                  // un segundo arrastre iniciado durante la latencia del seek.
                  final cubit = context.read<ThreadAudioCubit>();
                  final ms = (totalMs * v).round();
                  await cubit.seek(Duration(milliseconds: ms));
                  if (mounted && _dragValue == v) {
                    setState(() => _dragValue = null);
                  }
                }
              : null,
        ),
      ),
    );
  }
}
