import '../../../../core/ai/ai_config.dart';

/// Label humanizado del nivel de razonamiento. Compartido entre la página
/// Motor IA (valor del stat) y el caption de la fila Motor IA del hub.
String thinkingLabel(ThinkingLevel t) => switch (t) {
  ThinkingLevel.low => 'Bajo',
  ThinkingLevel.medium => 'Medio',
  ThinkingLevel.high => 'Alto',
};
