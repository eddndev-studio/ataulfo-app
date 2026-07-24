import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_avatar.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_page_header.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_section_link.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/domain/entities/identity.dart';

/// Preferencias personales del operador. La organización activa y toda su
/// administración viven en el selector global y en `/organization`; esta pantalla
/// conserva únicamente identidad personal, notificaciones, apariencia y
/// sesión.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    this.headerLeading,
    this.headerActions = const <Widget>[],
  });

  final Widget? headerLeading;
  final List<Widget> headerActions;

  /// Confirmación previa al logout: cerrar sesión descarta el estado local y
  /// obliga a re-autenticarse, así que un tap accidental no debe bastar.
  Future<void> _confirmLogout(BuildContext context) async {
    // Capturado antes del await: el dialog desmonta/remonta contextos.
    final authBloc = context.read<AuthBloc>();
    final ok = await showAppConfirmDialog(
      context,
      title: '¿Cerrar sesión?',
      message: 'Tendrás que volver a iniciar sesión para acceder.',
      confirmLabel: 'Cerrar sesión',
      destructive: false,
      confirmKey: const Key('settings.logout_confirm'),
    );
    if (ok) {
      authBloc.add(const AuthLoggedOut());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          // El redirect del router cambia la ruta dentro del frame;
          // mostramos nada para evitar parpadeos UI durante transiciones.
          return const SizedBox.shrink();
        }
        final identity = state.identity;
        return Column(
          children: <Widget>[
            _ProfileHeader(
              identity: identity,
              leading: headerLeading,
              actions: headerActions,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppTokens.sp5,
                  AppTokens.sp5,
                  AppTokens.sp5,
                  AppTokens.sp5 + context.safeBottomInset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _PersonalSectionsCard(),
                    const SizedBox(height: AppTokens.sp7),
                    AppButton.danger(
                      label: 'Cerrar sesión',
                      fullWidth: true,
                      onPressed: () => _confirmLogout(context),
                    ),
                    const SizedBox(height: AppTokens.sp5),
                    const _VersionFooter(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Header personal: el rol se omite deliberadamente porque pertenece a la
/// organización activa y ya se muestra en el selector global.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.identity,
    required this.leading,
    required this.actions,
  });

  final Identity identity;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AppPageHeader(
      key: const Key('settings.header'),
      title: 'Ajustes',
      leading: leading,
      actions: actions,
      content: Row(
        children: <Widget>[
          AppAvatar(name: identity.email, size: 48, colorKey: identity.email),
          const SizedBox(width: AppTokens.sp4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  identity.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTokens.fontSans,
                    fontSize: AppTokens.bodyLSize,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.text1,
                  ),
                ),
                const SizedBox(height: AppTokens.sp2),
                const AppPill.neutral(label: 'Cuenta personal'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Preferencias cuyo dueño es la persona o el dispositivo. Mantener esta lista
/// corta evita que Ajustes vuelva a convertirse en el índice de toda la app.
class _PersonalSectionsCard extends StatelessWidget {
  const _PersonalSectionsCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('settings.card.personal'),
      child: Column(
        children: <Widget>[
          AppSectionLink(
            rowKey: const Key('settings.notifications_tile'),
            icon: Icons.notifications_outlined,
            title: 'Notificaciones',
            caption: 'Bandeja y preferencias de avisos',
            onTap: () => context.push('/notifications'),
          ),
          const Divider(height: AppTokens.sp5, color: AppTokens.divider),
          AppSectionLink(
            rowKey: const Key('settings.appearance_tile'),
            icon: Icons.palette_outlined,
            title: 'Apariencia',
            caption: 'Animaciones de la interfaz',
            onTap: () => context.push('/appearance'),
          ),
        ],
      ),
    );
  }
}

/// Versión instalada al pie ("¿qué versión traes?" en soporte). La trae el
/// plugin de plataforma de forma asíncrona; mientras llega (o si falla en un
/// host sin plugin) no se pinta nada — es información auxiliar, no bloqueante.
class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final info = snap.data;
        if (info == null) return const SizedBox.shrink();
        return Center(
          child: Text(
            '${info.appName} v${info.version} (${info.buildNumber})',
            key: const Key('settings.version'),
            style: textTheme.bodySmall?.copyWith(color: AppTokens.textDisabled),
          ),
        );
      },
    );
  }
}
