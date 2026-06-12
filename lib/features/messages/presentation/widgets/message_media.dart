import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/media_opener.dart';
import '../bloc/thread_audio_cubit.dart';
import 'media_viewer.dart';

/// Contenido de un mensaje no-texto del hilo, interaccionable como en
/// mensajería:
///
///   - imagen/sticker: miniatura desde la URL firmada; tap → visor fullscreen.
///   - audio/ptt: burbuja reproducible inline ([ThreadAudioCubit]).
///   - video/documento: tarjeta que descarga y abre con una app externa
///     ([MediaOpener]).
///
/// Sin `mediaUrl` (firma caída, R2 sin configurar) todo degrada a la tarjeta
/// de tipo no interaccionable. Si la media trae caption, se pinta debajo.
class MessageMediaContent extends StatelessWidget {
  const MessageMediaContent({required this.message, super.key});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final m = message;
    final url = m.mediaUrl;
    final media = switch (m.type) {
      'image' || 'sticker' when url != null => _TappableImage(
        id: m.externalId,
        url: url,
        sticker: m.type == 'sticker',
      ),
      'image' => _typedCard(context, Icons.image_outlined, 'Imagen'),
      'sticker' => _typedCard(
        context,
        Icons.emoji_emotions_outlined,
        'Sticker',
      ),
      'audio' || 'ptt' when url != null => _AudioContent(
        id: m.externalId,
        url: url,
        ptt: m.type == 'ptt',
      ),
      'audio' || 'ptt' => _typedCard(context, Icons.mic_none_outlined, 'Audio'),
      'video' when url != null => _OpenableCard(
        id: m.externalId,
        url: url,
        icon: Icons.videocam_outlined,
        label: 'Video',
      ),
      'video' => _typedCard(context, Icons.videocam_outlined, 'Video'),
      'document' when url != null => _OpenableCard(
        id: m.externalId,
        url: url,
        icon: Icons.description_outlined,
        label: 'Documento',
      ),
      'document' => _typedCard(
        context,
        Icons.description_outlined,
        'Documento',
      ),
      _ => Text(
        '[${m.type}]',
        style: textTheme.bodyLarge?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppTokens.text2,
        ),
      ),
    };
    if (m.content.isEmpty) {
      return media;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        media,
        const SizedBox(height: AppTokens.sp1),
        Text(m.content, style: textTheme.bodyLarge),
      ],
    );
  }
}

/// Tarjeta de tipo para media sin URL firmada (o tipo no interaccionable):
/// ícono en el verde de sección + etiqueta legible.
Widget _typedCard(BuildContext context, IconData icon, String label) {
  final textTheme = Theme.of(context).textTheme;
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppTokens.sp3,
      vertical: AppTokens.sp2,
    ),
    decoration: BoxDecoration(
      color: AppTokens.bgBase.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(AppTokens.radiusChip),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 20, color: AppTokens.chatAccent),
        const SizedBox(width: AppTokens.sp2),
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(color: AppTokens.text1),
        ),
      ],
    ),
  );
}

/// Miniatura de imagen/sticker; tap abre el visor fullscreen con zoom.
class _TappableImage extends StatelessWidget {
  const _TappableImage({
    required this.id,
    required this.url,
    required this.sticker,
  });

  final String id;
  final String url;
  final bool sticker;

  @override
  Widget build(BuildContext context) {
    final side = sticker ? 120.0 : 220.0;
    return GestureDetector(
      key: Key('message.image.$id'),
      onTap: () => showMediaViewer(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        child: Image.network(
          url,
          width: side,
          height: side,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: side,
              height: side,
              child: const Center(
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
          },
          errorBuilder: (context, error, stack) => _typedCard(
            context,
            Icons.broken_image_outlined,
            sticker ? 'Sticker no disponible' : 'Imagen no disponible',
          ),
        ),
      ),
    );
  }
}

/// Burbuja de audio reproducible: botón play/pausa + barra de progreso +
/// posición. El estado vive en el [ThreadAudioCubit] del hilo (un player):
/// esta burbuja está "activa" sólo si la fuente del player es SU URL.
class _AudioContent extends StatelessWidget {
  const _AudioContent({required this.id, required this.url, required this.ptt});

  final String id;
  final String url;
  final bool ptt;

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocBuilder<ThreadAudioCubit, ThreadAudioState>(
      builder: (context, state) {
        final active = state.url == url;
        final playing = active && state.playing;
        final duration = active ? state.duration : null;
        final position = active ? state.position : Duration.zero;
        final progress =
            (duration != null && duration.inMilliseconds > 0 && active)
            ? (position.inMilliseconds / duration.inMilliseconds).clamp(
                0.0,
                1.0,
              )
            : 0.0;
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
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: AppTokens.onPrimary,
                    semanticLabel: playing ? 'Pausar' : 'Reproducir',
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTokens.sp3),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    child: LinearProgressIndicator(
                      key: Key('message.audio.$id.progress'),
                      value: progress,
                      minHeight: 4,
                      backgroundColor: AppTokens.bgBase.withValues(alpha: 0.4),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTokens.chatAccent,
                      ),
                    ),
                  ),
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
                    Text(
                      active
                          ? '${_fmt(position)}'
                                '${duration != null ? ' / ${_fmt(duration)}' : ''}'
                          : (ptt ? 'Nota de voz' : 'Audio'),
                      style: textTheme.labelSmall?.copyWith(
                        color: AppTokens.text2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Tarjeta de video/documento con URL firmada: tap descarga y abre con la
/// app externa del sistema (estado de "abriendo" + SnackBar ante fallo).
class _OpenableCard extends StatefulWidget {
  const _OpenableCard({
    required this.id,
    required this.url,
    required this.icon,
    required this.label,
  });

  final String id;
  final String url;
  final IconData icon;
  final String label;

  @override
  State<_OpenableCard> createState() => _OpenableCardState();
}

class _OpenableCardState extends State<_OpenableCard> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    final opener = context.read<MediaOpener>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _opening = true);
    try {
      await opener.open(url: widget.url);
    } on MediaOpenException {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el archivo')),
      );
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppTokens.bgBase.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      child: InkWell(
        key: Key('message.open.${widget.id}'),
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.sp3,
            vertical: AppTokens.sp2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_opening)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTokens.chatAccent,
                    ),
                  ),
                )
              else
                Icon(widget.icon, size: 20, color: AppTokens.chatAccent),
              const SizedBox(width: AppTokens.sp2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    widget.label,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTokens.text1,
                    ),
                  ),
                  Text(
                    _opening ? 'Abriendo…' : 'Toca para abrir',
                    style: textTheme.labelSmall?.copyWith(
                      color: AppTokens.text2,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppTokens.sp2),
              const Icon(Icons.open_in_new, size: 16, color: AppTokens.text2),
            ],
          ),
        ),
      ),
    );
  }
}
