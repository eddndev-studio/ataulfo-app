import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_entity_icon.dart';
import '../../../../core/i18n/role_labels.dart';
import '../../../auth/domain/failures/auth_failure.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/switch_org_cubit.dart';
import '../../../memberships/domain/entities/membership.dart';
import '../../../memberships/presentation/bloc/memberships_bloc.dart';
import 'organization_switcher_sheet.dart';

/// Selector persistente del contexto de organización.
///
/// En móvil ocupa una franja compacta antes del contenido de la tab; en rail
/// se reduce a un control vertical. Ambos abren la misma hoja, por lo que el
/// nombre visible, el cambio de contexto y los accesos de gestión tienen una
/// sola implementación.
class OrganizationContextSwitcher extends StatelessWidget {
  const OrganizationContextSwitcher({super.key, this.compact = false});

  final bool compact;

  Membership? _activeMembership(MembershipsState state, String orgId) {
    if (state case MembershipsLoaded(:final items)) {
      for (final item in items) {
        if (item.orgId == orgId) return item;
      }
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    final memberships = context.read<MembershipsBloc>();
    final switcher = context.read<SwitchOrgCubit>();
    final auth = context.read<AuthBloc>();
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      // Un switch persiste tokens antes de refrescar AuthBloc. Mantener la hoja
      // montada hasta éxito/fallo evita que un swipe la cierre a mitad y deje
      // la sesión visual en el contexto anterior.
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<MembershipsBloc>.value(value: memberships),
          BlocProvider<SwitchOrgCubit>.value(value: switcher),
          BlocProvider<AuthBloc>.value(value: auth),
        ],
        child: OrganizationSwitcherSheet(
          onNavigate: (path) {
            Navigator.of(sheetContext).pop();
            context.push(path);
          },
        ),
      ),
    );
  }

  void _onSwitchState(BuildContext context, SwitchOrgState state) {
    switch (state) {
      case SwitchOrgSwitched():
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
        context.read<AuthBloc>().add(const AuthCheckRequested());
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Organización cambiada')));
        context.go('/home');
      case SwitchOrgFailed(failure: final failure):
        if (failure is NotMemberFailure) {
          context.read<MembershipsBloc>().add(const MembershipsLoadRequested());
        }
        final message = failure is NetworkFailure
            ? 'Sin conexión. Revisa tu red e inténtalo de nuevo.'
            : 'No pudimos cambiar de organización. Inténtalo de nuevo.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      case SwitchOrgIdle() || SwitchOrgSwitching():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SwitchOrgCubit, SwitchOrgState>(
      listener: _onSwitchState,
      child: BlocBuilder<MembershipsBloc, MembershipsState>(
        builder: (context, memberships) {
          final auth = context.read<AuthBloc>().state;
          final identity = auth is AuthAuthenticated ? auth.identity : null;
          final active = identity == null
              ? null
              : _activeMembership(memberships, identity.orgId);
          final name = active?.orgName ?? 'Organización';
          final role = roleLabel(active?.role ?? identity?.role ?? '');
          return compact
              ? _RailOrganizationButton(
                  name: name,
                  role: role,
                  loading: memberships is MembershipsLoading,
                  onTap: () => _open(context),
                )
              : _MobileOrganizationButton(
                  name: name,
                  role: role,
                  loading: memberships is MembershipsLoading,
                  onTap: () => _open(context),
                );
        },
      ),
    );
  }
}

class _MobileOrganizationButton extends StatelessWidget {
  const _MobileOrganizationButton({
    required this.name,
    required this.role,
    required this.loading,
    required this.onTap,
  });

  final String name;
  final String role;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('organization.context.mobile'),
      color: AppTokens.surface1,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTokens.divider)),
            ),
            child: Row(
              children: <Widget>[
                const AppEntityIcon(icon: Icons.business_outlined, size: 36),
                const SizedBox(width: AppTokens.sp3),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        key: const Key('organization.context.name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppTokens.text2),
                      ),
                    ],
                  ),
                ),
                if (loading)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.unfold_more, color: AppTokens.text2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailOrganizationButton extends StatelessWidget {
  const _RailOrganizationButton({
    required this.name,
    required this.role,
    required this.loading,
    required this.onTap,
  });

  final String name;
  final String role;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + AppTokens.sp2,
        bottom: AppTokens.sp3,
      ),
      child: Tooltip(
        message: '$name · $role',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('organization.context.rail'),
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            onTap: onTap,
            child: SizedBox(
              width: 72,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.sp2,
                  vertical: AppTokens.sp2,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (loading)
                      const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.business_outlined),
                    const SizedBox(height: AppTokens.sp1),
                    Text(
                      name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
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
