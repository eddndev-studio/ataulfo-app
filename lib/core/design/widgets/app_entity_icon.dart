import 'package:flutter/material.dart';

import '../tokens.dart';

/// Glifo cuadrado de entidad del design system.
///
/// Representa una entidad (carpeta, chat, agente) con una letra o un ícono
/// dentro de un cuadrado de esquinas suaves (radio [AppTokens.radiusSm]). A
/// diferencia de un avatar, NO deriva una inicial: pinta la letra tal cual la
/// recibe.
///
/// El estado [highlighted] eleva el glifo al gradiente de marca; en ese caso
/// el primer plano usa [AppTokens.onPrimary] (el amarillo exige contenido
/// oscuro para contraste, nunca blanco). En reposo el relleno es
/// [AppTokens.surface3] con contenido en [AppTokens.text1].
///
/// Accesibilidad: el glifo es decorativo por defecto. Si se pasa
/// [semanticLabel], el contenido se anuncia con esa etiqueta; si no, se
/// excluye del árbol semántico — una letra suelta o un ícono ornamental sin
/// significado solo agregarían ruido al lector de pantalla.
class AppEntityIcon extends StatelessWidget {
  const AppEntityIcon({
    super.key,
    this.letter,
    this.icon,
    this.size = 44,
    this.highlighted = false,
    this.semanticLabel,
  }) : assert(
         (letter != null) ^ (icon != null),
         'AppEntityIcon requiere letter o icon, no ambos',
       );

  final String? letter;
  final IconData? icon;
  final double size;
  final bool highlighted;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // El primer plano cálido va en oscuro; en reposo, en text1.
    final foreground = highlighted ? AppTokens.onPrimary : AppTokens.text1;

    final Widget content = letter != null
        ? Text(
            letter!,
            // La letra escala con el tile (size * 0.4) en paridad con el
            // ícono (size * 0.5): un tamaño fijo se vería diminuto en tiles
            // grandes y desbordaría en los pequeños.
            style: TextStyle(
              fontFamily: AppTokens.fontSans,
              fontSize: size * 0.4,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          )
        : Icon(icon, size: size * 0.5, color: foreground);

    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // El relleno destacado es un gradiente, no un color sólido: cuando
        // [highlighted] define gradient, color queda en null para que la
        // BoxDecoration pinte con la rampa de marca.
        color: highlighted ? null : AppTokens.surface3,
        gradient: highlighted ? AppTokens.brandGradient : null,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: content,
    );

    // Con etiqueta el glifo se anuncia; sin ella se excluye del árbol
    // semántico por ser decorativo. En ambos casos el contenido interno
    // (letra/ícono) se excluye: o bien la etiqueta lo reemplaza, o bien todo
    // es decorativo — así la etiqueta queda limpia sin el nodo de la letra.
    return semanticLabel != null
        ? Semantics(
            label: semanticLabel,
            child: ExcludeSemantics(child: tile),
          )
        : ExcludeSemantics(child: tile);
  }
}
