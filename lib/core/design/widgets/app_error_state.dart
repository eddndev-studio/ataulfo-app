import 'package:flutter/material.dart';

import '../tokens.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Estado de error canónico: una card sobria (no toda roja) con el mensaje del
/// fallo, una descripción opcional y un botón de reintento opcional. Es la
/// anatomía que las páginas del producto usan cuando una carga falla.
///
/// El botón aparece solo si se pasa [onRetry]; algunos errores no ofrecen
/// reintento local (la acción vive en otra parte o el estado es terminal).
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.description,
    this.retryLabel = 'Reintentar',
    this.onRetry,
  });

  final String message;
  final String? description;
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onTap = onRetry;
    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(message, style: textTheme.titleMedium),
          if (description != null) ...<Widget>[
            const SizedBox(height: AppTokens.sp2),
            Text(
              description!,
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
          ],
          if (onTap != null) ...<Widget>[
            const SizedBox(height: AppTokens.sp4),
            AppButton.tonal(label: retryLabel, onPressed: onTap),
          ],
        ],
      ),
    );
  }
}
