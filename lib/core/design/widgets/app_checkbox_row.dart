import 'package:flutter/material.dart';

import '../tokens.dart';
import 'app_checkbox.dart';

enum AppCheckboxAffinity { leading, trailing }

/// Fila seleccionable canónica: toda la superficie alterna una casilla y el
/// control visual sigue siendo [AppCheckbox]. Centraliza hit-target, tipografía
/// y semántica para que los pickers no reconstruyan palomitas con íconos.
class AppCheckboxRow extends StatelessWidget {
  const AppCheckboxRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.leading,
    this.affinity = AppCheckboxAffinity.leading,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final AppCheckboxAffinity affinity;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final disabled = onChanged == null;
    final control = IgnorePointer(
      child: AppCheckbox(value: value, onChanged: (_) {}),
    );

    final content = <Widget>[
      if (affinity == AppCheckboxAffinity.leading) ...<Widget>[
        control,
        const SizedBox(width: AppTokens.sp2),
      ],
      if (leading != null) ...<Widget>[
        leading!,
        const SizedBox(width: AppTokens.sp3),
      ],
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyLarge,
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: AppTokens.sp1),
              Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
              ),
            ],
          ],
        ),
      ),
      if (affinity == AppCheckboxAffinity.trailing) ...<Widget>[
        const SizedBox(width: AppTokens.sp2),
        control,
      ],
    ];

    return Semantics(
      container: true,
      label: title,
      hint: subtitle,
      checked: value,
      enabled: !disabled,
      onTap: disabled ? null : () => onChanged!(!value),
      child: ExcludeSemantics(
        child: Opacity(
          opacity: disabled ? 0.4 : 1,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: disabled ? null : () => onChanged!(!value),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.sp1,
                    vertical: AppTokens.sp1,
                  ),
                  child: Row(children: content),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
