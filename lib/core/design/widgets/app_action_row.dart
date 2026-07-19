import 'package:flutter/material.dart';

import '../tokens.dart';

enum AppActionRowTone { normal, primary, danger }

/// Acción de menú o sheet en formato fila. A diferencia de [AppSectionLink],
/// no promete navegación: puede ejecutar, copiar, pausar o eliminar.
class AppActionRow extends StatelessWidget {
  const AppActionRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.tone = AppActionRowTone.normal,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final AppActionRowTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = switch (tone) {
      AppActionRowTone.normal => AppTokens.text1,
      AppActionRowTone.primary => AppTokens.primary,
      AppActionRowTone.danger => AppTokens.danger,
    };
    final disabled = onTap == null;

    return Semantics(
      container: true,
      button: true,
      enabled: !disabled,
      label: title,
      hint: subtitle,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: disabled ? 0.4 : 1,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.sp1,
                    vertical: AppTokens.sp2,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(icon, color: color, size: 24),
                      const SizedBox(width: AppTokens.sp4),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              title,
                              style: textTheme.bodyLarge?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (subtitle != null) ...<Widget>[
                              const SizedBox(height: AppTokens.sp1),
                              Text(
                                subtitle!,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppTokens.text2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (trailing != null) ...<Widget>[
                        const SizedBox(width: AppTokens.sp3),
                        trailing!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
