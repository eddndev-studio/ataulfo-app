import 'package:flutter/material.dart';

import '../../../../core/design/app_selection_sheet.dart';
import '../../../../core/design/tokens.dart';
import '../../domain/entities/step.dart' as fdom;
import 'step_type_label.dart';

/// Primer tiempo del creador de pasos: el operador elige el TIPO en un
/// selector rico agrupado (Mensajes / Lógica / Acciones), con glifo y una
/// caption que explica qué hace cada tipo ANTES de elegirlo — la semántica
/// de "Fin" o "Etiqueta" ya no se descubre después de seleccionar.
///
/// Devuelve el [fdom.StepType] elegido, o `null` si el operador descarta la
/// hoja (cancelar el selector no abre nada). Solo aplica al CREAR: al editar
/// el tipo es inmutable y el sheet de composición lo muestra como identidad.
Future<fdom.StepType?> showStepTypeSelector(BuildContext context) {
  return showAppSelectionSheet<fdom.StepType>(
    context,
    title: 'Tipo de paso',
    sections: <AppSelectionSection<fdom.StepType>>[
      AppSelectionSection<fdom.StepType>(
        header: 'Mensajes',
        options: <AppSelectionOption<fdom.StepType>>[
          _option(fdom.StepType.text, caption: 'Envía un mensaje de texto'),
          _option(fdom.StepType.image, caption: 'Envía una imagen'),
          _option(fdom.StepType.video, caption: 'Envía un video'),
          _option(
            fdom.StepType.document,
            caption: 'Envía un archivo como adjunto descargable',
          ),
          _option(fdom.StepType.audio, caption: 'Envía un audio reproducible'),
          _option(
            fdom.StepType.ptt,
            caption: 'Envía el audio como nota de voz grabada',
          ),
          _option(fdom.StepType.sticker, caption: 'Envía un sticker'),
        ],
      ),
      AppSelectionSection<fdom.StepType>(
        header: 'Lógica',
        options: <AppSelectionOption<fdom.StepType>>[
          _option(
            fdom.StepType.conditionalTime,
            title: 'Condición de horario',
            caption: 'Ramifica según día y hora',
          ),
          _option(
            fdom.StepType.end,
            title: 'Fin de rama',
            caption: 'Termina el flujo aquí',
          ),
        ],
      ),
      AppSelectionSection<fdom.StepType>(
        header: 'Acciones',
        options: <AppSelectionOption<fdom.StepType>>[
          _option(
            fdom.StepType.label,
            caption: 'Aplica una etiqueta al chat, sin enviar nada',
          ),
        ],
      ),
    ],
  );
}

/// Opción del selector para [type]: key estable `step_edit.type.<name>`
/// (heredada del contrato de tests del picker viejo), glifo discreto y
/// [title] opcional cuando el nombre del selector difiere del label corto
/// de las cards ("Condición de horario" vs "Condicional").
AppSelectionOption<fdom.StepType> _option(
  fdom.StepType type, {
  String? title,
  required String caption,
}) {
  return AppSelectionOption<fdom.StepType>(
    key: Key('step_edit.type.${type.name}'),
    value: type,
    title: title ?? stepTypeLabel(type),
    caption: caption,
    leading: Icon(stepTypeGlyph(type), size: 20, color: AppTokens.text2),
  );
}

/// Glifo por tipo de paso. Espeja el vocabulario visual del resto de la app
/// (mic para nota de voz, label para etiqueta) para que el selector se lea
/// con los mismos símbolos que el hilo de mensajes.
IconData stepTypeGlyph(fdom.StepType t) => switch (t) {
  fdom.StepType.text => Icons.chat_bubble_outline,
  fdom.StepType.image => Icons.image_outlined,
  fdom.StepType.video => Icons.videocam_outlined,
  fdom.StepType.document => Icons.description_outlined,
  fdom.StepType.audio => Icons.audiotrack_outlined,
  fdom.StepType.ptt => Icons.mic_none_outlined,
  fdom.StepType.sticker => Icons.emoji_emotions_outlined,
  fdom.StepType.conditionalTime => Icons.alt_route_outlined,
  fdom.StepType.label => Icons.label_outline,
  fdom.StepType.end => Icons.stop_circle_outlined,
  fdom.StepType.unsupported => Icons.help_outline,
};
