import 'package:flutter/material.dart';

import '../tokens.dart';

/// Primitivo InputChip del design system.
///
/// Representa un valor seleccionado y removible (filtros activos, tags de un
/// formulario). Relleno [AppTokens.primary] con primer plano oscuro
/// [AppTokens.onPrimary] — el amarillo de marca exige contraste oscuro — y
/// radio [AppTokens.radiusChip] (no pill: el chip es más anguloso que botones
/// y campos).
///
/// El cuerpo y el botón de borrar son zonas de toque INDEPENDIENTES: tocar el
/// cuerpo dispara [onPressed] (p. ej. editar el valor) sin removerlo, y solo
/// el icono close dispara [onDeleted]. Así un gesto no se confunde con el otro.
class AppInputChip extends StatelessWidget {
  const AppInputChip({
    super.key,
    required this.label,
    this.onPressed,
    this.onDeleted,
  });

  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTokens.radiusChip);

    // El Container raíz porta el contrato visual (fondo + radio) y debe ser el
    // primer Container del árbol — el test lo lee como tal.
    return Container(
      decoration: BoxDecoration(
        color: AppTokens.primary,
        borderRadius: radius,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          splashColor: Colors.white.withValues(alpha: 0.06),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppTokens.sp3,
                right: AppTokens.sp1,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: AppTokens.fontSans,
                      fontSize: AppTokens.bodyMSize,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.onPrimary,
                    ),
                  ),
                  const SizedBox(width: AppTokens.sp1),
                  _DeleteButton(onDeleted: onDeleted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón de borrar del chip: zona tappable propia del icono close.
///
/// Separado del cuerpo para que su gesto no se solape con [onPressed]; el área
/// de toque (≥48 vía hit-test) envuelve al icono de 18 px.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onDeleted});

  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDeleted,
      child: const Padding(
        padding: EdgeInsets.all(AppTokens.sp2),
        child: Icon(
          Icons.close,
          size: 18,
          color: AppTokens.onPrimary,
        ),
      ),
    );
  }
}
