import 'package:flutter/material.dart';

import '../tokens.dart';
import 'app_avatar.dart';

/// Chrome superior neutro para las pantallas principales del shell.
///
/// Mantiene la geometría compacta de Bandeja y Ataúlfo: una barra de 56 px
/// sobre [AppTokens.surface1], un divisor inferior y, cuando la sección lo
/// necesita, un segundo renglón de controles. No es una card destacada ni usa
/// gradiente; el amarillo queda reservado para acciones y estados.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.avatarInitial,
    this.avatarColorKey,
    this.onAvatarTap,
    this.content,
  }) : assert(
         (avatarInitial == null) == (onAvatarTap == null),
         'el avatar del header exige su acción (y viceversa)',
       );

  final String title;

  /// Inicial visible del perfil. Va en pareja con [onAvatarTap].
  final String? avatarInitial;

  /// Clave estable opcional para conservar el color del avatar entre vistas.
  final String? avatarColorKey;
  final VoidCallback? onAvatarTap;

  /// Controles o contexto propios de la sección, bajo la barra principal.
  final Widget? content;

  static const double _toolbarHeight = 56;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('app_page_header.surface'),
      color: AppTokens.surface1,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: _toolbarHeight,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppTokens.sp4,
                  right: AppTokens.sp2,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTokens.text1,
                        ),
                      ),
                    ),
                    if (avatarInitial != null)
                      _ProfileButton(
                        initial: avatarInitial!,
                        colorKey: avatarColorKey,
                        onTap: onAvatarTap!,
                      ),
                  ],
                ),
              ),
            ),
            if (content != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.sp5,
                  AppTokens.sp2,
                  AppTokens.sp5,
                  AppTokens.sp4,
                ),
                child: content!,
              ),
            const SizedBox(
              height: 2,
              child: ColoredBox(
                key: Key('app_page_header.divider'),
                color: AppTokens.divider,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Acceso al perfil con objetivo táctil de 48 px y avatar visual de 32 px.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton({
    required this.initial,
    required this.onTap,
    this.colorKey,
  });

  final String initial;
  final String? colorKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Perfil',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('app_page_header.avatar'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: ExcludeSemantics(
                child: AppAvatar(
                  name: initial,
                  size: 32,
                  colorKey: colorKey ?? initial,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
