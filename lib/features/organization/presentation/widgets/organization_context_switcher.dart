import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_entity_icon.dart';
import '../../../../core/i18n/role_labels.dart';
import '../../../auth/domain/failures/auth_failure.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/switch_org_cubit.dart';
import '../../../memberships/domain/entities/membership.dart';
import '../../../memberships/presentation/bloc/memberships_bloc.dart';
import 'organization_switcher_sheet.dart';

enum OrganizationContextPresentation { mobileBar, rail, header, drawer }

/// Abre la única superficie de cambio de organización.
///
/// El listener pertenece al launcher, no a la hoja: si el operador descarta el
/// modal mientras el backend termina un switch, la sesión igual procesa el
/// resultado y nunca queda con tokens nuevos pero contexto visual viejo.
Future<void> showOrganizationSwitcher(BuildContext context) async {
  final memberships = context.read<MembershipsBloc>();
  final switcher = context.read<SwitchOrgCubit>();
  final auth = context.read<AuthBloc>();
  NavigatorState? activeSheetNavigator;
  Completer<void>? inFlightSwitch = switcher.state is SwitchOrgSwitching
      ? Completer<void>()
      : null;
  final subscription = switcher.stream.listen((state) {
    switch (state) {
      case SwitchOrgSwitching():
        inFlightSwitch = Completer<void>();
      case SwitchOrgSwitched() || SwitchOrgFailed():
        final pending = inFlightSwitch;
        if (pending != null && !pending.isCompleted) pending.complete();
      case SwitchOrgIdle():
        break;
    }
    if (!context.mounted) return;
    _onSwitchState(context, activeSheetNavigator, state);
  });

  try {
    await showAppBottomSheet<void>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (sheetContext) {
        activeSheetNavigator = Navigator.of(sheetContext);
        return PopScope<Object?>(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) activeSheetNavigator = null;
          },
          child: MultiBlocProvider(
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
      },
    );
  } finally {
    activeSheetNavigator = null;
    final pending = inFlightSwitch;
    if (switcher.state is SwitchOrgSwitching &&
        pending != null &&
        !pending.isCompleted) {
      await pending.future;
    }
    await subscription.cancel();
  }
}

void _onSwitchState(
  BuildContext hostContext,
  NavigatorState? sheetNavigator,
  SwitchOrgState state,
) {
  if (!hostContext.mounted) return;
  switch (state) {
    case SwitchOrgSwitched():
      if (sheetNavigator != null && sheetNavigator.mounted) {
        sheetNavigator.pop();
      }
      hostContext.read<AuthBloc>().add(const AuthCheckRequested());
      ScaffoldMessenger.of(
        hostContext,
      ).showSnackBar(const SnackBar(content: Text('Organización cambiada')));
      hostContext.go('/home');
    case SwitchOrgFailed(failure: final failure):
      if (failure is NotMemberFailure) {
        hostContext.read<MembershipsBloc>().add(
          const MembershipsLoadRequested(),
        );
      }
      final message = failure is NetworkFailure
          ? 'Sin conexión. Revisa tu red e inténtalo de nuevo.'
          : 'No pudimos cambiar de organización. Inténtalo de nuevo.';
      ScaffoldMessenger.of(
        hostContext,
      ).showSnackBar(SnackBar(content: Text(message)));
    case SwitchOrgIdle() || SwitchOrgSwitching():
      break;
  }
}

/// Proyecciones compactas del contexto activo. La franja móvil histórica se
/// conserva por compatibilidad, pero el shell usa únicamente el drawer.
class OrganizationContextSwitcher extends StatelessWidget {
  const OrganizationContextSwitcher({
    super.key,
    this.compact = false,
    this.presentation,
    this.onTap,
  });

  final bool compact;
  final OrganizationContextPresentation? presentation;
  final VoidCallback? onTap;

  Membership? _activeMembership(MembershipsState state, String orgId) {
    if (state case MembershipsLoaded(:final items)) {
      for (final item in items) {
        if (item.orgId == orgId) return item;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MembershipsBloc, MembershipsState>(
      builder: (context, memberships) {
        final auth = context.read<AuthBloc>().state;
        final identity = auth is AuthAuthenticated ? auth.identity : null;
        final active = identity == null
            ? null
            : _activeMembership(memberships, identity.orgId);
        final name = active?.orgName ?? 'Organización';
        final role = roleLabel(active?.role ?? identity?.role ?? '');
        final tap = onTap ?? () => showOrganizationSwitcher(context);
        final mode =
            presentation ??
            (compact
                ? OrganizationContextPresentation.rail
                : OrganizationContextPresentation.mobileBar);
        return switch (mode) {
          OrganizationContextPresentation.mobileBar =>
            _MobileOrganizationButton(
              name: name,
              role: role,
              loading: memberships is MembershipsLoading,
              onTap: tap,
            ),
          OrganizationContextPresentation.rail => _RailOrganizationButton(
            name: name,
            role: role,
            loading: memberships is MembershipsLoading,
            onTap: tap,
          ),
          OrganizationContextPresentation.header => _HeaderOrganizationButton(
            name: name,
            role: role,
            loading: memberships is MembershipsLoading,
            onTap: tap,
          ),
          OrganizationContextPresentation.drawer => _DrawerOrganizationButton(
            name: name,
            role: role,
            loading: memberships is MembershipsLoading,
            onTap: tap,
          ),
        };
      },
    );
  }
}

class _HeaderOrganizationButton extends StatelessWidget {
  const _HeaderOrganizationButton({
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
    return IconButton(
      key: const Key('organization.context.header'),
      tooltip: '$name · $role',
      onPressed: onTap,
      icon: loading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.business_outlined),
    );
  }
}

class _DrawerOrganizationButton extends StatelessWidget {
  const _DrawerOrganizationButton({
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
      key: const Key('organization.context.drawer'),
      color: AppTokens.surface2,
      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.sp4),
          child: Row(
            children: <Widget>[
              const AppEntityIcon(icon: Icons.business_outlined, size: 40),
              const SizedBox(width: AppTokens.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      name,
                      key: const Key('organization.context.name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppTokens.sp1),
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
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.unfold_more, color: AppTokens.text2),
            ],
          ),
        ),
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
