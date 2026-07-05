import '../../domain/entities/step.dart';

/// Etiqueta humanizada en español para cada `StepType`. Vive en
/// presentación porque el dominio no decide cómo se lee — el wire usa
/// tokens UPPERCASE canónicos (TEXT/IMAGE/...), pero el operador ve el
/// texto traducido en el selector de tipo, el header del sheet de
/// composición y las pills de las cards. Centralizar acá evita drift
/// entre superficies. PTT se nombra por lo que es para el operador
/// ("Nota de voz"); la sigla de protocolo no sale del wire.
///
/// CONDITIONAL_TIME se nombra "Condicional" como label corto de card y
/// header; el selector de tipo lo presenta como "Condición de horario"
/// con su caption explicativa.
String stepTypeLabel(StepType t) => switch (t) {
  StepType.text => 'Texto',
  StepType.image => 'Imagen',
  StepType.video => 'Video',
  StepType.document => 'Documento',
  StepType.audio => 'Audio',
  StepType.ptt => 'Nota de voz',
  StepType.sticker => 'Sticker',
  StepType.conditionalTime => 'Condicional',
  StepType.label => 'Etiqueta',
  StepType.end => 'Fin',
  StepType.unsupported => 'No soportado',
};
