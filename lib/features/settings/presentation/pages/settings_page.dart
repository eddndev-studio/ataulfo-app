import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/role_privilege.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/i18n/role_labels.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

/// Pantalla de Settings mínima del shell: muestra el perfil real del
/// operador (email + rol vía pill primary) y dos acciones (tile a
/// /memberships, logout). Otras opciones (tema, idioma, perfil editable)
/// aterrizan en su propio slice.
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que volver a iniciar sesión para acceder.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('settings.logout_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok == true) {
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
        return Padding(
          padding: const EdgeInsets.all(AppTokens.sp6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(identity.email),
              const SizedBox(height: AppTokens.sp4),
              Row(
                children: <Widget>[
                  const Text('Rol'),
                  const SizedBox(width: AppTokens.sp3),
                  AppPill.primary(label: roleLabel(identity.role)),
                ],
              ),
              const SizedBox(height: AppTokens.sp6),
              AppCard(
                key: const Key('settings.memberships_tile'),
                // push (no go): apila /memberships sobre Settings para
                // que el back físico de Android vuelva al shell sin sacar
                // al operador de la app. Mismo guard que tiles y FABs
                // del resto del repo.
                onTap: () => context.push('/memberships'),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.business_outlined, color: AppTokens.text2),
                    SizedBox(width: AppTokens.sp4),
                    Expanded(child: Text('Tus organizaciones')),
                    Icon(Icons.chevron_right, color: AppTokens.text2),
                  ],
                ),
              ),
              // Gestión de miembros: gateada a ADMIN+ porque el backend 403ea
              // a roles por debajo (RequireRole). El gate es cosmético —
              // oculta un control que de todos modos fallaría—; la autoridad
              // real sigue siendo el 403 del servidor.
              if (isAdminOrAbove(identity.role)) ...<Widget>[
                const SizedBox(height: AppTokens.cardGap),
                AppCard(
                  key: const Key('settings.members_tile'),
                  // push (no go): apila /members sobre Settings para que el
                  // back físico vuelva al shell, igual que el resto de tiles.
                  onTap: () => context.push('/members'),
                  child: const Row(
                    children: <Widget>[
                      Icon(Icons.people_outline, color: AppTokens.text2),
                      SizedBox(width: AppTokens.sp4),
                      Expanded(child: Text('Miembros')),
                      Icon(Icons.chevron_right, color: AppTokens.text2),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppTokens.cardGap),
              AppCard(
                key: const Key('settings.media_tile'),
                // push (no go): apila /media sobre Settings para que el back
                // físico vuelva al shell, igual que el tile de organizaciones.
                onTap: () => context.push('/media'),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.perm_media_outlined, color: AppTokens.text2),
                    SizedBox(width: AppTokens.sp4),
                    Expanded(child: Text('Galería de multimedia')),
                    Icon(Icons.chevron_right, color: AppTokens.text2),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.cardGap),
              AppCard(
                key: const Key('settings.notifications_tile'),
                onTap: () => context.push('/notifications'),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.notifications_outlined, color: AppTokens.text2),
                    SizedBox(width: AppTokens.sp4),
                    Expanded(child: Text('Notificaciones')),
                    Icon(Icons.chevron_right, color: AppTokens.text2),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.sp7),
              AppButton.danger(
                label: 'Cerrar sesión',
                fullWidth: true,
                onPressed: () => _confirmLogout(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
