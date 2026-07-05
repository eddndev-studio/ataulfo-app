import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/label_step_metadata.dart';
import '../../domain/entities/step.dart' as sdom;
import '../bloc/flow_steps_bloc.dart';
import 'step_card_conditional.dart';
import 'step_delete.dart';
import 'step_edit_support.dart';
import 'step_media_field.dart';
import 'step_row_bubble.dart';
import 'step_type_label.dart';

/// Contenido de una fila del timeline de pasos. Los pasos de MENSAJE
/// (texto y multimedia) se pintan como burbuja compacta — el idioma de
/// `chat_bubble`: contenido/miniatura al frente, cola hacia el riel del
/// índice. Los pasos de LÓGICA (condicional, fin, etiqueta) usan una fila
/// técnica diferenciada: glifo + resumen estructurado, sin burbuja.
///
/// El tipo y el retraso viven como caption quieta bajo el cuerpo (el
/// retraso deja de gritar en pill); "Solo IA"/"Solo disparadores" SÍ
/// siguen como pill — son lo excepcional.
///
/// Toda la fila es tappable (abre el editor) y el long-press ofrece el
/// borrado directo, una capa menos que la ruta fila → sheet → basura.
class StepRow extends StatelessWidget {
  const StepRow({
    super.key,
    required this.step,
    required this.onTap,
    this.resolvedMediaName,
    this.labelNames = const <String, String>{},
    this.stepRefs = const <String, ({int order, String label})>{},
    this.thumbResolver,
  });

  final sdom.Step step;

  /// Abre el editor del paso. Lo inyecta el listado para que la fila no
  /// conozca el sheet ni el picker de multimedia.
  final VoidCallback onTap;

  /// Nombre EN VIVO del recurso multimedia ya resuelto por el caller (lee
  /// el `MediaNamesCubit` por encima del listado). Plano a propósito: al
  /// reordenar, el item se eleva al overlay del Navigator (fuera del scope
  /// del provider) y un lookup ahí lanzaría ProviderNotFound.
  final String? resolvedMediaName;

  /// Catálogo id→nombre de labels, resuelto por el caller por encima del
  /// listado (mismo motivo de planitud que [resolvedMediaName]).
  final Map<String, String> labelNames;

  /// Índice id → (posición, etiqueta) de los steps del flow, para que el
  /// resumen del condicional resuelva sus destinos por nombre y marque
  /// colgantes/hacia-atrás (mismo motivo de planitud).
  final Map<String, ({int order, String label})> stepRefs;

  /// Resolutor de bytes de la miniatura del paso multimedia. `null` ⇒ el
  /// de sesión con el cache real en disco. Autocontenido a propósito (no
  /// es un provider): el subárbol se eleva al overlay durante el drag.
  final StepMediaThumbResolver? thumbResolver;

  /// Borrado directo desde la fila (long-press). Lee el bloc EN EL GESTO
  /// (no en build): la fila sigue siendo presentación pura y el lookup
  /// ocurre con el item montado en el árbol normal, nunca elevado al
  /// overlay del drag.
  Future<void> _requestDelete(BuildContext context) async {
    final bloc = context.read<FlowStepsBloc>();
    final confirmed = await confirmStepDelete(
      context,
      stepId: step.id,
      steps: stepsFromState(bloc.state),
    );
    if (confirmed) bloc.add(FlowStepsDeleteRequested(step.id));
  }

  bool get _isMessage =>
      step.type == sdom.StepType.text || step.type.isMultimediaStep;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: Key('flow_detail.step_card.${step.id}'),
      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      onTap: onTap,
      onLongPress: () => _requestDelete(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_isMessage)
            StepMessageBubble(
              step: step,
              textTheme: textTheme,
              resolvedMediaName: resolvedMediaName,
              thumbResolver: thumbResolver,
            )
          else
            _LogicRow(
              step: step,
              textTheme: textTheme,
              labelNames: labelNames,
              stepRefs: stepRefs,
            ),
          const SizedBox(height: AppTokens.sp1),
          _StepCaption(step: step, textTheme: textTheme),
        ],
      ),
    );
  }
}

/// Etiqueta corta de un step para el índice `stepRefs`: el contenido para
/// TEXT, el tipo humanizado para el resto. La consume el listado al armar
/// el índice que el resumen del condicional usa para nombrar sus destinos.
String stepRefLabel(sdom.Step st) {
  if (st.type == sdom.StepType.text && st.content.isNotEmpty) {
    return st.content;
  }
  return stepTypeLabel(st.type);
}

/// Fila técnica de un paso de LÓGICA: glifo en placa + resumen
/// estructurado, sin burbuja — la estructura no es un mensaje.
class _LogicRow extends StatelessWidget {
  const _LogicRow({
    required this.step,
    required this.textTheme,
    required this.labelNames,
    required this.stepRefs,
  });

  final sdom.Step step;
  final TextTheme textTheme;
  final Map<String, String> labelNames;
  final Map<String, ({int order, String label})> stepRefs;

  IconData get _glyph => switch (step.type) {
    sdom.StepType.conditionalTime => Icons.alt_route,
    sdom.StepType.end => Icons.flag_outlined,
    sdom.StepType.label => _labelGlyph(),
    _ => Icons.help_outline,
  };

  /// El glifo del paso LABEL distingue aplicar de quitar; metadata
  /// ilegible cae al glifo de aplicar (el resumen ya avisa).
  IconData _labelGlyph() {
    try {
      final md = LabelStepMetadata.fromJsonString(step.metadataJson);
      return md.action == LabelStepAction.add
          ? Icons.label_outline
          : Icons.label_off_outlined;
    } on FormatException {
      return Icons.label_outline;
    }
  }

  Widget get _summary => switch (step.type) {
    sdom.StepType.conditionalTime => ConditionalTimeSummary(
      step: step,
      textTheme: textTheme,
      stepRefs: stepRefs,
    ),
    sdom.StepType.end => Text(
      'Termina el flujo aquí.',
      key: const Key('flow_detail.step.end'),
      style: textTheme.bodyMedium?.copyWith(
        fontStyle: FontStyle.italic,
        color: AppTokens.text2,
      ),
    ),
    sdom.StepType.label => _LabelStepSummary(
      step: step,
      textTheme: textTheme,
      labelNames: labelNames,
    ),
    _ => Text(
      'Paso no soportado — actualiza la app para verlo.',
      style: textTheme.bodyMedium?.copyWith(
        fontStyle: FontStyle.italic,
        color: AppTokens.text2,
      ),
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTokens.surface2,
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          ),
          child: Icon(_glyph, size: 18, color: AppTokens.text2),
        ),
        const SizedBox(width: AppTokens.sp3),
        Expanded(child: _summary),
      ],
    );
  }
}

/// Caption quieta bajo el cuerpo: tipo humanizado + retraso (solo si el
/// paso lo tiene y envía al wire) en `text2`, y las pills EXCEPCIONALES
/// de modo de ejecución. El retraso repetido por fila era ambiental y
/// gritaba en pill; aquí calla.
class _StepCaption extends StatelessWidget {
  const _StepCaption({required this.step, required this.textTheme});

  final sdom.Step step;
  final TextTheme textTheme;

  bool get _hasPacing => switch (step.type) {
    sdom.StepType.label ||
    sdom.StepType.end ||
    sdom.StepType.unsupported => false,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final quiet = textTheme.bodySmall?.copyWith(color: AppTokens.text2);
    return Wrap(
      spacing: AppTokens.sp2,
      runSpacing: AppTokens.sp1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(stepTypeLabel(step.type), style: quiet),
        if (_hasPacing && step.delayMs > 0)
          Text('· ${_delayLabel(step)}', style: quiet),
        if (step.aiOnly) const AppPill.primary(label: 'Solo IA'),
        if (step.manualOnly) const AppPill.outline(label: 'Solo disparadores'),
      ],
    );
  }
}

/// Resumen read-only de un paso LABEL: la acción (Etiquetar / Quitar
/// etiqueta) + el NOMBRE de la etiqueta resuelto del catálogo
/// ([labelNames]); el id crudo queda sólo como respaldo honesto (catálogo
/// cargando, fallo o label borrada) y distingue pasos. Metadata inválida
/// ⇒ fallback "sin configurar". El glifo de la acción lo pone la placa de
/// la fila técnica.
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
    return Text.rich(
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
    );
  }
}

/// Etiqueta legible del delay. Convierte ms a segundos con un decimal y
/// agrega el jitter si > 0. Ejemplos: "1.5s" / "2s ± 10%".
String _delayLabel(sdom.Step s) {
  final secs = s.delayMs / 1000;
  final base = secs == secs.truncate()
      ? '${secs.toInt()}s'
      : '${secs.toStringAsFixed(1)}s';
  if (s.jitterPct <= 0) return base;
  return '$base ± ${s.jitterPct}%';
}
