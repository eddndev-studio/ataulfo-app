import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_media_thumb.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/label_step_metadata.dart';
import '../../domain/entities/step.dart' as sdom;
import '../bloc/flow_steps_bloc.dart';
import '../media_step_name.dart';
import 'step_card_conditional.dart';
import 'step_delete.dart';
import 'step_edit_support.dart';
import 'step_media_field.dart';
import 'step_type_label.dart';

/// Card read-only por step. Muestra index (order+1), label humanizado del
/// type, contenido (`content` para TEXT, `mediaRef` para multimedia,
/// resumen de metadata para CONDITIONAL_TIME), y pills laterales (delay,
/// modo de ejecución si está acotado: "Solo IA" / "Solo disparadores").
///
/// `dragIndex != null` ⇒ se renderiza con drag handle a la derecha,
/// listo para reordenar dentro del `ReorderableListView` padre. El handle
/// captura el gesto antes del InkWell (se monta como sibling del área
/// tappable), así que long-press/drag sobre el handle no abre el sheet.
class StepCard extends StatelessWidget {
  const StepCard({
    super.key,
    required this.step,
    required this.onTap,
    this.dragIndex,
    this.resolvedMediaName,
    this.labelNames = const <String, String>{},
    this.stepRefs = const <String, ({int order, String label})>{},
    this.thumbResolver,
  });

  final sdom.Step step;

  /// Abre el editor del paso. Lo inyecta el listado para que la card no
  /// conozca el sheet ni el picker de multimedia.
  final VoidCallback onTap;

  final int? dragIndex;

  /// Nombre EN VIVO del recurso multimedia ya resuelto por el caller (lee el
  /// `MediaNamesCubit` por encima del listado). Plano a propósito: ver
  /// [_StepBody.resolvedMediaName].
  final String? resolvedMediaName;

  /// Catálogo id→nombre de labels, resuelto por el caller por encima del
  /// listado (mismo motivo de planitud que [resolvedMediaName]).
  final Map<String, String> labelNames;

  /// Índice id → (posición, etiqueta) de los steps del flow, para que el
  /// resumen del condicional resuelva sus destinos por nombre (mismo
  /// motivo de planitud que los otros catálogos).
  final Map<String, ({int order, String label})> stepRefs;

  /// Resolutor de bytes de la miniatura del paso multimedia. `null` ⇒ el de
  /// sesión con el cache real en disco. Autocontenido a propósito (no es un
  /// provider): el subárbol se eleva al overlay durante el drag y un lookup
  /// ahí lanzaría ProviderNotFound.
  final StepMediaThumbResolver? thumbResolver;

  /// Borrado directo desde la card (long-press): una capa menos que la
  /// ruta card → sheet → basura. Lee el bloc EN EL GESTO (no en build):
  /// la card sigue siendo presentación pura y el lookup ocurre con el item
  /// montado en el árbol normal, nunca elevado al overlay del drag.
  Future<void> _requestDelete(BuildContext context) async {
    final bloc = context.read<FlowStepsBloc>();
    final confirmed = await confirmStepDelete(
      context,
      stepId: step.id,
      steps: stepsFromState(bloc.state),
    );
    if (confirmed) bloc.add(FlowStepsDeleteRequested(step.id));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '${step.order + 1}.',
              style: textTheme.titleMedium?.copyWith(color: AppTokens.text2),
            ),
            const SizedBox(width: AppTokens.sp2),
            AppPill.outline(label: stepTypeLabel(step.type)),
          ],
        ),
        const SizedBox(height: AppTokens.sp2),
        _StepBody(
          step: step,
          textTheme: textTheme,
          resolvedMediaName: resolvedMediaName,
          labelNames: labelNames,
          stepRefs: stepRefs,
          thumbResolver: thumbResolver,
        ),
        const SizedBox(height: AppTokens.sp3),
        Wrap(
          spacing: AppTokens.sp2,
          runSpacing: AppTokens.sp2,
          children: <Widget>[
            AppPill.neutral(label: _delayLabel(step)),
            if (step.aiOnly) const AppPill.primary(label: 'Solo IA'),
            if (step.manualOnly)
              const AppPill.outline(label: 'Solo disparadores'),
          ],
        ),
      ],
    );
    final dragIdx = dragIndex;
    return AppCard(
      padding: AppTokens.sp4,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: InkWell(
              key: Key('flow_detail.step_card.${step.id}'),
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              onTap: onTap,
              onLongPress: () => _requestDelete(context),
              child: content,
            ),
          ),
          if (dragIdx != null)
            ReorderableDragStartListener(
              index: dragIdx,
              // 48x48: área de agarre táctil mínima (el ícono solo mide 24 y
              // es demasiado fino para el pulgar). ExcludeSemantics colapsa el
              // nodo del ícono en uno solo con la etiqueta de acción.
              child: Semantics(
                label: 'Mover paso',
                child: ExcludeSemantics(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      Icons.drag_handle,
                      key: Key('flow_detail.step_card.drag_handle.${step.id}'),
                      color: AppTokens.text2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Etiqueta corta de un step para el índice `stepRefs`: el contenido para
/// TEXT, el tipo humanizado para el resto. La consume el listado al armar
/// el índice que la card del condicional usa para nombrar sus destinos.
String stepRefLabel(sdom.Step st) {
  if (st.type == sdom.StepType.text && st.content.isNotEmpty) {
    return st.content;
  }
  return stepTypeLabel(st.type);
}

/// Cuerpo del step según tipo. TEXT muestra content; multimedia muestra
/// mediaRef truncado; CONDITIONAL_TIME interpreta `metadataJson` y
/// muestra TZ + ventanas formateadas + destinos onMatch/onElse. Si el
/// metadata no parsea (corrupto/legacy), cae a un fallback honesto.
class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.step,
    required this.textTheme,
    this.resolvedMediaName,
    this.labelNames = const <String, String>{},
    this.stepRefs = const <String, ({int order, String label})>{},
    this.thumbResolver,
  });

  final sdom.Step step;
  final TextTheme textTheme;

  /// Resolutor de bytes de la miniatura (ver [StepCard.thumbResolver]).
  final StepMediaThumbResolver? thumbResolver;

  /// Catálogo id→nombre de labels, plano por el mismo motivo que
  /// [resolvedMediaName].
  final Map<String, String> labelNames;

  /// Índice id → (posición, etiqueta) de los steps del flow, para el
  /// resumen del condicional.
  final Map<String, ({int order, String label})> stepRefs;

  /// Nombre EN VIVO del recurso (alias/filename del catálogo) ya resuelto por
  /// el caller, que lee el `MediaNamesCubit` POR ENCIMA del `ReorderableListView`.
  /// Se recibe como dato plano —no se hace lookup del cubit aquí— para que el
  /// subárbol de la tarjeta sea autocontenido: al reordenar, el item se eleva al
  /// overlay del Navigator (fuera del scope del provider) y un lookup ahí
  /// lanzaría ProviderNotFound (RenderErrorBox gris estirado). null ⇒ aún
  /// cargando o asset borrado (el respaldo por paso decide el texto).
  final String? resolvedMediaName;

  @override
  Widget build(BuildContext context) {
    final t = step.type;
    if (t == sdom.StepType.text) {
      final content = step.content.isEmpty ? '—' : step.content;
      return Text(
        content,
        style: textTheme.bodyMedium?.copyWith(
          color: step.content.isEmpty ? AppTokens.text2 : null,
        ),
      );
    }
    if (t == sdom.StepType.conditionalTime) {
      return ConditionalTimeSummary(
        step: step,
        textTheme: textTheme,
        stepRefs: stepRefs,
      );
    }
    if (t == sdom.StepType.end) {
      return Text(
        'Termina el flujo aquí.',
        key: const Key('flow_detail.step.end'),
        style: textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppTokens.text2,
        ),
      );
    }
    if (t == sdom.StepType.label) {
      return _LabelStepSummary(
        step: step,
        textTheme: textTheme,
        labelNames: labelNames,
      );
    }
    if (t == sdom.StepType.unsupported) {
      return Text(
        'Paso no soportado — actualiza la app para verlo.',
        style: textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppTokens.text2,
        ),
      );
    }
    // Multimedia: IMAGE / VIDEO / DOCUMENT / AUDIO / PTT / STICKER.
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
    // `media_filename` guardado al elegirlo → la cola corta del ref BARE en
    // monospace (señal de id, no nombre). El ref completo con el path del
    // tenant nunca se muestra.
    final (mediaText, mono) = mediaStepDisplay(
      mediaRef: step.mediaRef,
      metadataJson: step.metadataJson,
      resolvedName: resolvedMediaName,
    );
    final resolver = thumbResolver ?? StepMediaThumbResolver.session;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Miniatura efímera resuelta SOLO por el ref BARE (la lista no tiene
        // asset a mano): bytes del cache compartido con la galería, o el glifo
        // por tipo cuando el cache está frío. Para VIDEO eso significa poster
        // sólo si la galería ya lo derivó y cacheó — sin cache, glifo de video:
        // derivar un poster localmente exigiría bajar el archivo entero.
        AppMediaThumb(
          mediaRef: step.mediaRef,
          kind: mediaKindForStepType(step.type),
          size: 40,
          loader: (r) => resolver.load(r),
        ),
        const SizedBox(width: AppTokens.sp3),
        Expanded(
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

/// Resumen read-only de un paso LABEL en la StepCard: la acción
/// (Etiquetar / Quitar etiqueta) + el NOMBRE de la etiqueta resuelto del
/// catálogo ([labelNames]); el id crudo queda sólo como respaldo honesto
/// (catálogo cargando, fallo o label borrada) y distingue pasos. Metadata
/// inválida ⇒ fallback "sin configurar".
class _LabelStepSummary extends StatelessWidget {
  const _LabelStepSummary({
    required this.step,
    required this.textTheme,
    this.labelNames = const <String, String>{},
  });

  final sdom.Step step;
  final TextTheme textTheme;
  final Map<String, String> labelNames;

  @override
  Widget build(BuildContext context) {
    final LabelStepMetadata md;
    try {
      md = LabelStepMetadata.fromJsonString(step.metadataJson);
    } on FormatException {
      return Text(
        'Etiqueta sin configurar',
        style: textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppTokens.text2,
        ),
      );
    }
    final isAdd = md.action == LabelStepAction.add;
    final resolvedName = labelNames[md.labelId];
    return Row(
      children: <Widget>[
        Icon(
          isAdd ? Icons.label_outline : Icons.label_off_outlined,
          size: 16,
          color: AppTokens.text2,
        ),
        const SizedBox(width: AppTokens.sp2),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: <TextSpan>[
                TextSpan(
                  text: isAdd ? 'Etiquetar · ' : 'Quitar etiqueta · ',
                  style: textTheme.bodyMedium,
                ),
                if (resolvedName != null)
                  TextSpan(text: resolvedName, style: textTheme.bodyMedium)
                else
                  TextSpan(
                    text: md.labelId,
                    style: textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: AppTokens.text2,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Etiqueta legible del delay. Convierte ms a segundos con un decimal y
/// agrega el jitter si > 0. Ejemplos: "0s" / "1.5s" / "2s ± 10%".
String _delayLabel(sdom.Step s) {
  final secs = s.delayMs / 1000;
  final base = secs == secs.truncate()
      ? '${secs.toInt()}s'
      : '${secs.toStringAsFixed(1)}s';
  if (s.jitterPct <= 0) return base;
  return '$base ± ${s.jitterPct}%';
}
