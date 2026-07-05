import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_media_thumb.dart';
import '../../domain/entities/step.dart' as sdom;
import '../media_step_name.dart';
import 'step_media_field.dart';

/// Burbuja compacta de un paso de MENSAJE dentro del timeline: el
/// contenido que el bot va a enviar, leído como mensaje — el idioma de
/// `chat_bubble` con la cola (radio chico) apuntando al riel del índice:
/// el mensaje "sale" de su nodo.
///
/// TEXT pinta su contenido; multimedia pinta miniatura efímera + nombre
/// legible + caption. Presentación pura: los datos resueltos llegan del
/// caller (overlay-safe durante el drag).
class StepMessageBubble extends StatelessWidget {
  const StepMessageBubble({
    super.key,
    required this.step,
    required this.textTheme,
    this.resolvedMediaName,
    this.thumbResolver,
  });

  final sdom.Step step;
  final TextTheme textTheme;

  /// Nombre EN VIVO del recurso, resuelto por el caller (ver `StepRow`).
  final String? resolvedMediaName;

  /// Resolutor de bytes de la miniatura (ver `StepRow.thumbResolver`).
  final StepMediaThumbResolver? thumbResolver;

  @override
  Widget build(BuildContext context) {
    const tail = Radius.circular(AppTokens.radiusSm);
    const full = Radius.circular(AppTokens.radiusCard);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp4,
          vertical: AppTokens.sp3,
        ),
        decoration: const BoxDecoration(
          color: AppTokens.surface2,
          borderRadius: BorderRadius.only(
            topLeft: tail,
            topRight: full,
            bottomLeft: full,
            bottomRight: full,
          ),
        ),
        child: step.type == sdom.StepType.text
            ? _textBody()
            : _mediaBody(context),
      ),
    );
  }

  Widget _textBody() {
    return Text(
      step.content.isEmpty ? '—' : step.content,
      style: textTheme.bodyMedium?.copyWith(
        color: step.content.isEmpty ? AppTokens.text2 : null,
      ),
    );
  }

  /// Cuerpo multimedia: miniatura efímera + nombre legible + caption.
  Widget _mediaBody(BuildContext context) {
    if (step.mediaRef.isEmpty) {
      return Text(
        'Sin media asignada',
        style: textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppTokens.text2,
        ),
      );
    }
    // Nombre legible del recurso. Prioridad: el alias EN VIVO del catálogo
    // (resuelto por ref vía MediaNamesCubit, leído por el caller) → el
    // `media_filename` guardado al elegirlo → la cola corta del ref BARE
    // en monospace (señal de id, no nombre). El ref completo con el path
    // del tenant nunca se muestra.
    final (mediaText, mono) = mediaStepDisplay(
      mediaRef: step.mediaRef,
      metadataJson: step.metadataJson,
      resolvedName: resolvedMediaName,
    );
    final resolver = thumbResolver ?? StepMediaThumbResolver.session;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Miniatura efímera resuelta SOLO por el ref BARE (la lista no
        // tiene asset a mano): bytes del cache compartido con la galería,
        // o el glifo por tipo cuando el cache está frío. Para VIDEO eso
        // significa poster sólo si la galería ya lo derivó y cacheó —
        // derivar un poster localmente exigiría bajar el archivo entero.
        AppMediaThumb(
          mediaRef: step.mediaRef,
          kind: mediaKindForStepType(step.type),
          size: 40,
          loader: (r) => resolver.load(r),
        ),
        const SizedBox(width: AppTokens.sp3),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                mediaText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: mono
                    ? textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: AppTokens.text2,
                      )
                    : textTheme.bodyMedium,
              ),
              if (step.content.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppTokens.sp1),
                Text(step.content, style: textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
