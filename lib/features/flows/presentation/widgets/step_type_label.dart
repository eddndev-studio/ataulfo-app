import '../../domain/entities/step.dart';

/// Etiqueta humanizada en español para cada `StepType`. Vive en
/// presentación porque el dominio no decide cómo se lee — el wire usa
/// tokens UPPERCASE canónicos (TEXT/IMAGE/...), pero el operador ve el
/// texto traducido en chips del sheet y pills del card. Centralizar
/// acá evita drift entre los dos call sites.
///
/// CONDITIONAL_TIME se nombra "Condicional" — se muestra en card y,
/// cuando aterrice su editor, en el sheet con un form específico.
String stepTypeLabel(StepType t) => switch (t) {
  StepType.text => 'Texto',
  StepType.image => 'Imagen',
  StepType.video => 'Video',
  StepType.document => 'Documento',
  StepType.audio => 'Audio',
  StepType.ptt => 'PTT',
  StepType.sticker => 'Sticker',
  StepType.conditionalTime => 'Condicional',
  StepType.label => 'Etiqueta',
  StepType.unsupported => 'No soportado',
};
