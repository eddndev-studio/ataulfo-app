import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/auth/role_privilege.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_action_row.dart';

/// Navegación secundaria del producto.
///
/// Las operaciones diarias permanecen en la barra inferior/rail; este cajón
/// concentra contexto de organización, bibliotecas y preferencias sin ocupar
/// altura permanente en todas las pantallas.
class ShellNavigationDrawer extends StatelessWidget {
  const ShellNavigationDrawer({
    super.key,
    required this.role,
    required this.organizationContext,
    required this.onOpenOrganization,
    required this.onOpenLibrary,
    required this.onOpenLabels,
    required this.onOpenSettings,
    required this.onOpenNotifications,
    required this.onOpenAppearance,
  });

  final String role;
  final Widget organizationContext;
  final VoidCallback onOpenOrganization;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenLabels;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenAppearance;

  @override
  Widget build(BuildContext context) {
    final width = math.min(360.0, MediaQuery.sizeOf(context).width * 0.88);
    return Drawer(
      key: const Key('shell.drawer'),
      width: width,
      backgroundColor: AppTokens.surface1,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.sp4,
            AppTokens.sp4,
            AppTokens.sp4,
            AppTokens.sp6,
          ),
          children: <Widget>[
            Row(
              children: <Widget>[
                SvgPicture.asset(
                  'assets/brand/mango.svg',
                  key: const Key('shell.drawer.brand.mango'),
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: AppTokens.sp2),
                Expanded(
                  child: Text(
                    'Ataúlfo',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const Key('shell.drawer.close'),
                  tooltip: 'Cerrar menú',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.sp4),
            organizationContext,
            const SizedBox(height: AppTokens.sp6),
            const _SectionLabel('Gestión'),
            _DrawerLink(
              rowKey: const Key('shell.drawer.organization'),
              icon: Icons.business_outlined,
              title: 'Organización',
              subtitle: 'Identidad, equipo, IA y plan',
              onTap: onOpenOrganization,
            ),
            if (isSupervisorOrAbove(role))
              _DrawerLink(
                rowKey: const Key('shell.drawer.library'),
                icon: Icons.folder_copy_outlined,
                title: 'Biblioteca y contenido',
                subtitle: 'Archivos, productos y workspaces',
                onTap: onOpenLibrary,
              ),
            if (isAdminOrAbove(role))
              _DrawerLink(
                rowKey: const Key('shell.drawer.labels'),
                icon: Icons.label_outline,
                title: 'Etiquetas',
                subtitle: 'Clasificación de conversaciones',
                onTap: onOpenLabels,
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppTokens.sp4),
              child: Divider(height: 1, color: AppTokens.divider),
            ),
            const _SectionLabel('Cuenta y app'),
            _DrawerLink(
              rowKey: const Key('shell.drawer.settings'),
              icon: Icons.settings_outlined,
              title: 'Ajustes',
              onTap: onOpenSettings,
            ),
            _DrawerLink(
              rowKey: const Key('shell.drawer.notifications'),
              icon: Icons.notifications_outlined,
              title: 'Notificaciones',
              onTap: onOpenNotifications,
            ),
            _DrawerLink(
              rowKey: const Key('shell.drawer.appearance'),
              icon: Icons.palette_outlined,
              title: 'Apariencia',
              onTap: onOpenAppearance,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.sp4,
        0,
        AppTokens.sp4,
        AppTokens.sp2,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTokens.text2,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _DrawerLink extends StatelessWidget {
  const _DrawerLink({
    required this.rowKey,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final Key rowKey;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppActionRow(
      key: rowKey,
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: const Icon(Icons.chevron_right, color: AppTokens.textDisabled),
      onTap: onTap,
    );
  }
}
