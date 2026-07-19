import 'package:flutter/material.dart';

import '../tokens.dart';

/// Encabezado full-bleed para detalles de entidades. Centraliza gradiente,
/// insets, retorno, edición, escala tipográfica y el slot de metadatos.
class AppDetailHeader extends StatelessWidget {
  const AppDetailHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.backKey,
    this.onEdit,
    this.showEdit = false,
    this.editKey,
    this.editTooltip = 'Editar',
    this.metadata = const <Widget>[],
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Key? backKey;
  final VoidCallback? onEdit;
  final bool showEdit;
  final Key? editKey;
  final String editTooltip;
  final List<Widget> metadata;

  static const LinearGradient _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[AppTokens.primary, AppTokens.accent],
  );

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final textTheme = Theme.of(context).textTheme;
    final hasEdit = showEdit || onEdit != null;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(AppTokens.radiusHeader),
        bottomRight: Radius.circular(AppTokens.radiusHeader),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: _gradient),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppTokens.sp5,
            topInset + AppTokens.sp4,
            AppTokens.sp5,
            AppTokens.sp6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                key: backKey,
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                color: AppTokens.onPrimary,
                tooltip: 'Volver',
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              const SizedBox(height: AppTokens.sp3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTokens.heroTitle.copyWith(
                            color: AppTokens.onPrimary,
                          ),
                        ),
                        const SizedBox(height: AppTokens.sp1),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyLarge?.copyWith(
                            color: AppTokens.onPrimary.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasEdit)
                    IconButton(
                      key: editKey,
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      color: AppTokens.onPrimary,
                      tooltip: editTooltip,
                    ),
                ],
              ),
              if (metadata.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppTokens.sp4),
                Wrap(
                  spacing: AppTokens.sp2,
                  runSpacing: AppTokens.sp2,
                  children: metadata,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
