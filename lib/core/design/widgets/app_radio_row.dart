import 'package:flutter/material.dart';

import '../tokens.dart';
import 'app_radio.dart';

/// Fila canónica de selección exclusiva. Amplía [AppRadio] a una superficie
/// completa con título, apoyo opcional y un único nodo semántico accionable.
class AppRadioRow<T> extends StatelessWidget {
  const AppRadioRow({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.leading,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;
  final String title;
  final String? subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final disabled = onChanged == null;
    final selected = value == groupValue;

    return Semantics(
      container: true,
      label: title,
      hint: subtitle,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      enabled: !disabled,
      onTap: disabled ? null : () => onChanged!(value),
      child: ExcludeSemantics(
        child: Opacity(
          opacity: disabled ? 0.4 : 1,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: disabled ? null : () => onChanged!(value),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: <Widget>[
                    IgnorePointer(
                      child: AppRadio<T>(
                        value: value,
                        groupValue: groupValue,
                        onChanged: (_) {},
                      ),
                    ),
                    if (leading != null) ...<Widget>[
                      leading!,
                      const SizedBox(width: AppTokens.sp3),
                    ],
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTokens.sp2,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(title, style: textTheme.bodyLarge),
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
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
