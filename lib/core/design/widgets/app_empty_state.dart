import 'package:flutter/material.dart';

import '../tokens.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'app_entity_icon.dart';

/// Estado vacío canónico: una card glass centrada con un glifo destacado, un
/// título, una descripción opcional y un CTA opcional. Es la anatomía del vacío
/// rico que las listas del producto comparten (bots, plantillas, etiquetas…).
///
/// No aporta scroll ni pull-to-refresh: eso es responsabilidad de la página que
/// lo coloca (habitualmente dentro de un `RefreshIndicator` con scroll para que
/// el gesto de refresco siga vivo sobre el vacío). Aquí vive solo la tarjeta.
///
/// El CTA aparece únicamente si se pasan [ctaLabel] y [onCta]; sin ellos el
/// vacío es informativo (no toda lista vacía ofrece crear desde aquí).
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.ctaLabel,
    this.ctaIcon,
    this.onCta,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? ctaLabel;

  /// Ícono opcional del CTA (p.ej. `Icons.add` en los vacíos de creación).
  final IconData? ctaIcon;

  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = ctaLabel;
    final onTap = onCta;
    return AppCard.glass(
      padding: const EdgeInsets.all(AppTokens.cardPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          AppEntityIcon(icon: icon, size: 56, highlighted: true),
          const SizedBox(height: AppTokens.sp4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium,
          ),
          if (description != null) ...<Widget>[
            const SizedBox(height: AppTokens.sp2),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
          ],
          if (label != null && onTap != null) ...<Widget>[
            const SizedBox(height: AppTokens.sp5),
            AppButton.filled(
              label: label,
              icon: ctaIcon,
              fullWidth: true,
              onPressed: onTap,
            ),
          ],
        ],
      ),
    );
  }
}
