import 'package:flutter/material.dart';

import '../tokens.dart';

/// Fila de opción de un picker del design system: la comparten los sheets de
/// selección (etiqueta interna, vínculo WA, modelo/razonamiento de IA) para
/// que "elegir de una lista" se vea y se comporte igual en todo el producto.
///
/// Anatomía: InkWell de fila completa + [leading] opcional, título a una
/// línea con ellipsis, [trailing] extra (badges informativos) y un check de
/// marca cuando [selected]. `onTap` null deja la fila inerte (mutación en
/// vuelo o fila informativa). El padding vertical `sp3` da un piso táctil
/// ≥44px para acertar con el pulgar.
class AppOptionRow extends StatelessWidget {
  const AppOptionRow({
    super.key,
    this.leading,
    required this.title,
    this.trailing = const <Widget>[],
    this.selected = false,
    this.selectedIconKey,
    this.onTap,
  });

  /// Adorno a la izquierda del título (dot de color, ícono). Null ⇒ sin él.
  final Widget? leading;

  final String title;

  /// Widgets informativos entre el título y el check (badges de capacidad).
  final List<Widget> trailing;

  final bool selected;

  /// Key del ícono de check, para consumidores cuyo contrato de test ancla
  /// al indicador de selección y no a la fila.
  final Key? selectedIconKey;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTokens.sp3,
          horizontal: AppTokens.sp1,
        ),
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading!,
              const SizedBox(width: AppTokens.sp3),
            ],
            Expanded(
              child: Text(
                title,
                style: textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ...trailing,
            if (selected) ...<Widget>[
              const SizedBox(width: AppTokens.sp2),
              Icon(
                Icons.check,
                key: selectedIconKey,
                color: AppTokens.primary,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
