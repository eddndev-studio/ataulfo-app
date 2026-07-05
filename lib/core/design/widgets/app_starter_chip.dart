import 'package:flutter/material.dart';

import '../tokens.dart';

/// Chip de sugerencia de arranque: una cápsula con borde hairline y un ícono
/// (por defecto `auto_awesome`, el idioma del kit para "sugerencia de la IA")
/// que, al tocarse, PREFIJA el composer con un texto propuesto — el operador lo
/// edita y envía. Deliberadamente NO auto-envía un turno: un tap no debe gastar
/// una corrida del modelo por sí solo.
///
/// Es un contorno, no un CTA: sin fill, para no competir con el botón de envío.
/// No se auto-centra; su ubicación (un `Wrap` centrado del estado vacío) la
/// decide el llamador.
class AppStarterChip extends StatelessWidget {
  const AppStarterChip({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.auto_awesome,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTokens.radiusPill);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.sp3,
            vertical: AppTokens.sp2,
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppTokens.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 14, color: AppTokens.primary),
              const SizedBox(width: AppTokens.sp1),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTokens.text1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
