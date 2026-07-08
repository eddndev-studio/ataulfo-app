import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/auth/role_privilege.dart';
import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_avatar.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_header_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_section_link.dart';
import '../../../../core/i18n/role_labels.dart';
import '../../../../core/util/user_greeting.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/domain/entities/identity.dart';

/// Pantalla de Ajustes del shell. Header gradiente propio con el PERFIL del
/// operador (avatar + email + rol) — la identidad es el contenido principal
/// de esta tab, no un texto suelto — y las áreas como filas launcher
/// agrupadas en una card con caption (paridad con los hubs). Al pie: cerrar
/// sesión (confirmado) y la versión instalada (soporte: "¿qué versión
/// traes?").
///
/// Sin UUIDs visibles: el operador no acciona sobre `userId`/`orgId`;
/// `orgId` se interpreta al humano en `/memberships` (badge "Activa"
/// sobre el nombre legible).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
        return SingleChildScrollView(
          // Sin padding aquí: el header es full-bleed y va pegado arriba. El
          // resto del contenido lleva su propio padding más abajo.
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _ProfileHeader(identity: identity),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTokens.sp5,
                  AppTokens.sp5,
                  AppTokens.sp5,
                  AppTokens.sp5 + context.safeBottomInset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _SectionsCard(identity: identity),
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
            ],
          ),
        );
      },
    );
  }
}

/// Header de Ajustes: el AppHeaderCard del kit con la identidad del operador
/// como contenido principal (quién soy, con qué rol), no un texto suelto al
/// inicio de una lista. Sin saludo ni avatar de perfil arriba: esta tab ES el
/// perfil, así que la identidad vive en el slot de contenido.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.identity});

  final Identity identity;

  @override
  Widget build(BuildContext context) {
    final user = userGreeting(identity.email);
    return AppHeaderCard(
      key: const Key('settings.header'),
      title: 'Ajustes',
      content: Row(
        children: <Widget>[
          AppAvatar(name: user.initial, size: 56, colorKey: identity.email),
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
                    color: AppTokens.onPrimary,
                  ),
                ),
                const SizedBox(height: AppTokens.sp2),
                AppPill.glass(label: roleLabel(identity.role)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Las áreas de Ajustes como filas launcher en UNA card (paridad con los
/// hubs): título + caption de qué hay detrás + chevron. Miembros queda
/// gateado ADMIN+ porque el backend 403ea a roles por debajo (RequireRole);
/// el gate es cosmético — la autoridad real es el 403 del servidor.
class _SectionsCard extends StatelessWidget {
  const _SectionsCard({required this.identity});

  final Identity identity;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('settings.card.sections'),
      child: Column(
        children: <Widget>[
          AppSectionLink(
            rowKey: const Key('settings.memberships_tile'),
            icon: Icons.business_outlined,
            title: 'Tus organizaciones',
            caption: 'Cambia o renombra la organización activa',
            // push (no go): apila sobre Settings para que el back físico
            // vuelva al shell sin sacar al operador de la app. Igual en
            // todas las filas.
            onTap: () => context.push('/memberships'),
          ),
          const Divider(height: AppTokens.sp5, color: AppTokens.divider),
          // Visible para todos: cualquiera puede ser invitado a otra org, y la
          // pantalla de aceptar sólo era alcanzable desde /select-org (usuarios
          // sin org). Como registrarse autocrea una org personal, sin esta
          // entrada un usuario con org no tenía forma de aceptar una invitación.
          AppSectionLink(
            rowKey: const Key('settings.accept_invite_tile'),
            icon: Icons.mark_email_read_outlined,
            title: 'Unirse a una organización',
            caption: 'Únete a otra organización con un código o enlace',
            onTap: () => context.push('/accept-invite'),
          ),
          if (isAdminOrAbove(identity.role)) ...<Widget>[
            const Divider(height: AppTokens.sp5, color: AppTokens.divider),
            AppSectionLink(
              rowKey: const Key('settings.members_tile'),
              icon: Icons.people_outline,
              title: 'Miembros',
              caption: 'Roles, invitaciones y acceso a bots',
              onTap: () => context.push('/members'),
            ),
            const Divider(height: AppTokens.sp5, color: AppTokens.divider),
            AppSectionLink(
              rowKey: const Key('settings.org_ai_config_tile'),
              icon: Icons.smart_toy_outlined,
              title: 'Configuración de IA',
              caption: 'Proveedor por modelo y valores por defecto',
              onTap: () => context.push('/org/ai-config'),
            ),
            const Divider(height: AppTokens.sp5, color: AppTokens.divider),
            AppSectionLink(
              rowKey: const Key('settings.org_customization_tile'),
              icon: Icons.workspace_premium_outlined,
              title: 'Personalización',
              caption: 'Nombre y logo de los documentos de tu organización',
              onTap: () => context.push('/org/customization'),
            ),
            const Divider(height: AppTokens.sp5, color: AppTokens.divider),
            AppSectionLink(
              rowKey: const Key('settings.account_tile'),
              icon: Icons.credit_card_outlined,
              title: 'Cuenta y plan',
              caption: 'Tu plan, consumo y estado de la IA',
              onTap: () => context.push('/cuenta'),
            ),
          ],
          const Divider(height: AppTokens.sp5, color: AppTokens.divider),
          AppSectionLink(
            rowKey: const Key('settings.media_tile'),
            icon: Icons.perm_media_outlined,
            // Mismo término que el destino "Medios" del menú de adjuntar del
            // chat: ambos abren el MISMO catálogo de la organización.
            title: 'Medios',
            caption: 'Imágenes, videos y audios para tus flujos',
            onTap: () => context.push('/media'),
          ),
          const Divider(height: AppTokens.sp5, color: AppTokens.divider),
          AppSectionLink(
            rowKey: const Key('settings.notifications_tile'),
            icon: Icons.notifications_outlined,
            title: 'Notificaciones',
            caption: 'Bandeja y preferencias de avisos',
            onTap: () => context.push('/notifications'),
          ),
          const Divider(height: AppTokens.sp5, color: AppTokens.divider),
          // Preferencia del DISPOSITIVO (no de la cuenta ni de la org):
          // visible para cualquier rol, sin gate.
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
