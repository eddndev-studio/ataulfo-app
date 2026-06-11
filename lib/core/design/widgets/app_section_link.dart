import 'package:flutter/material.dart';

import '../tokens.dart';
import 'app_entity_icon.dart';
import 'app_pill.dart';

/// Fila launcher de los hubs de detalle (plantilla, bot): glifo de entidad +
/// título con count opcional + caption de resumen + chevron. Toda la fila es
/// tap-target hacia su página dedicada. Vive en el design system porque los
/// hubs la comparten: una card apila varias separadas por divider.
class AppSectionLink extends StatelessWidget {
  const AppSectionLink({
    super.key,
    required this.rowKey,
    required this.icon,
    required this.title,
    required this.onTap,
    this.count,
    this.caption,
  });

  /// Key de la fila (tap-target) para las pruebas; distinta de la key del
  /// widget para poder remontar la fila sin perder el handle.
  final Key rowKey;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  /// Items del área. Con valor > 0 acompaña al título como pill; null (sin
  /// snapshot) o 0 (vacío) van sin pill — un "0" solo repetiría el caption.
  final int? count;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = count;
    return InkWell(
      key: rowKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
        child: Row(
          children: <Widget>[
            AppEntityIcon(icon: icon, size: 44),
            const SizedBox(width: AppTokens.sp4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(title, style: textTheme.titleMedium),
                      if (c != null && c > 0) ...<Widget>[
                        const SizedBox(width: AppTokens.sp2),
                        AppPill.neutral(label: '$c'),
                      ],
                    ],
                  ),
                  if (caption != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppTokens.text2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.sp2),
            const Icon(Icons.chevron_right, color: AppTokens.text2),
          ],
        ),
      ),
    );
  }
}
