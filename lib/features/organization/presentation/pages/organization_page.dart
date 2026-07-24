import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_header_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_section_link.dart';
import '../../../../core/i18n/role_labels.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../billing/presentation/bloc/entitlement_bloc.dart';
import '../../../billing/presentation/cuenta_format.dart';
import '../../../invitations/presentation/bloc/invitations_bloc.dart';
import '../../../members/presentation/bloc/members_bloc.dart';
import '../../../memberships/domain/entities/membership.dart';
import '../../../memberships/presentation/bloc/memberships_bloc.dart';
import '../widgets/organization_context_switcher.dart';

/// Hub de la organización activa.
///
/// Reúne únicamente capacidades cuyo dueño es la organización: identidad,
/// equipo/acceso, configuración global de IA y plan. Los catálogos operativos
/// permanecen en sus superficies de trabajo y las preferencias personales en
/// Ajustes.
class OrganizationPage extends StatelessWidget {
  const OrganizationPage({
    super.key,
    required this.canManage,
    required this.hasBilling,
  });

  final bool canManage;
  final bool hasBilling;

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
    final auth = context.watch<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return const SizedBox.shrink();
    return BlocBuilder<MembershipsBloc, MembershipsState>(
      builder: (context, memberships) {
        final active = _activeMembership(memberships, auth.identity.orgId);
        final name = active?.orgName ?? 'Organización activa';
        final role = active?.role ?? auth.identity.role;
        return SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppHeaderCard(
                key: const Key('organization.summary'),
                greeting: 'Organización',
                title: name,
                watermark: Icons.business_outlined,
                leading: IconButton(
                  key: const Key('organization.back'),
                  tooltip: 'Volver',
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                actions: <Widget>[
                  IconButton(
                    key: const Key('organization.header.switch'),
                    tooltip: 'Cambiar organización',
                    onPressed: () => showOrganizationSwitcher(context),
                    icon: const Icon(Icons.swap_horiz),
                  ),
                ],
                content: _OrganizationHeaderContent(
                  role: role,
                  canManage: canManage,
                  hasBilling: hasBilling,
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppTokens.maxContentWidth,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppTokens.sp5,
                      AppTokens.sp5,
                      AppTokens.sp5,
                      AppTokens.sp7 + context.safeBottomInset,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (memberships is MembershipsLoading)
                          const LinearProgressIndicator(
                            key: Key('organization.summary.loading'),
                            minHeight: 2,
                          ),
                        if (memberships is MembershipsFailed)
                          _InlineLoadError(
                            onRetry: () => context.read<MembershipsBloc>().add(
                              const MembershipsLoadRequested(),
                            ),
                          ),
                        AppButton.tonal(
                          key: const Key('organization.change'),
                          label: 'Cambiar organización',
                          icon: Icons.swap_horiz,
                          fullWidth: true,
                          onPressed: () => showOrganizationSwitcher(context),
                        ),
                        const SizedBox(height: AppTokens.sp7),
                        Text(
                          canManage ? 'Administración' : 'Tu acceso',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppTokens.sp3),
                        if (canManage)
                          const _ManagementSections()
                        else
                          const _ReadOnlyNotice(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrganizationHeaderContent extends StatelessWidget {
  const _OrganizationHeaderContent({
    required this.role,
    required this.canManage,
    required this.hasBilling,
  });

  final String role;
  final bool canManage;
  final bool hasBilling;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppPill.glass(
          key: const Key('organization.summary.role'),
          label: roleLabel(role),
        ),
        if (canManage) ...<Widget>[
          const SizedBox(height: AppTokens.sp5),
          Divider(
            height: 1,
            color: AppTokens.onPrimary.withValues(alpha: 0.18),
          ),
          const SizedBox(height: AppTokens.sp4),
          _OverviewMetrics(hasBilling: hasBilling),
        ],
      ],
    );
  }
}

class _OverviewMetrics extends StatelessWidget {
  const _OverviewMetrics({required this.hasBilling});

  final bool hasBilling;

  String _memberValue(MembersState state) => switch (state) {
    MembersLoaded(:final items) => '${items.length}',
    MembersFailed() => '—',
    MembersInitial() || MembersLoading() => '…',
  };

  String _invitationValue(InvitationsState state) => switch (state) {
    InvitationsLoaded(:final items) =>
      '${items.where((item) => item.status == 'PENDING').length}',
    InvitationsFailed() => '—',
    InvitationsInitial() || InvitationsLoading() => '…',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: BlocBuilder<MembersBloc, MembersState>(
            builder: (context, state) =>
                _Metric(label: 'Miembros', value: _memberValue(state)),
          ),
        ),
        _MetricDivider(),
        Expanded(
          child: BlocBuilder<InvitationsBloc, InvitationsState>(
            builder: (context, state) =>
                _Metric(label: 'Invitaciones', value: _invitationValue(state)),
          ),
        ),
        _MetricDivider(),
        Expanded(
          child: hasBilling
              ? BlocBuilder<EntitlementBloc, EntitlementState>(
                  builder: (context, state) => _Metric(
                    label: 'Plan',
                    value: switch (state) {
                      EntitlementLoaded(:final entitlement) => planLabel(
                        entitlement.planCode,
                      ),
                      EntitlementFailed() => '—',
                      EntitlementInitial() || EntitlementLoading() => '…',
                    },
                  ),
                )
              : const _Metric(label: 'Plan', value: '—'),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTokens.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTokens.onPrimary.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: AppTokens.sp3),
      color: AppTokens.onPrimary.withValues(alpha: 0.18),
    );
  }
}

class _ManagementSections extends StatelessWidget {
  const _ManagementSections();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('organization.management'),
      child: Column(
        children: <Widget>[
          AppSectionLink(
            rowKey: const Key('organization.general'),
            icon: Icons.business_outlined,
            title: 'General',
            caption: 'Nombre y logo de la organización',
            onTap: () => context.push('/org/customization'),
          ),
          const Divider(height: AppTokens.sp5, color: AppTokens.divider),
          AppSectionLink(
            rowKey: const Key('organization.team'),
            icon: Icons.group_outlined,
            title: 'Equipo y acceso',
            caption: 'Miembros, roles, invitaciones y Canales asignados',
            onTap: () => context.push('/organization/team'),
          ),
          const Divider(height: AppTokens.sp5, color: AppTokens.divider),
          AppSectionLink(
            rowKey: const Key('organization.ai'),
            icon: Icons.smart_toy_outlined,
            title: 'Inteligencia artificial',
            caption: 'Proveedores y valores predeterminados',
            onTap: () => context.push('/org/ai-config'),
          ),
          const Divider(height: AppTokens.sp5, color: AppTokens.divider),
          AppSectionLink(
            rowKey: const Key('organization.plan'),
            icon: Icons.credit_card_outlined,
            title: 'Plan y uso',
            caption: 'Consumo, límites y facturación',
            onTap: () => context.push('/cuenta'),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return AppCard.outline(
      key: const Key('organization.read_only'),
      padding: const EdgeInsets.all(AppTokens.sp5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.lock_outline, color: AppTokens.text2),
          const SizedBox(width: AppTokens.sp3),
          Expanded(
            child: Text(
              'Puedes trabajar dentro de esta organización. Un propietario o '
              'administrador gestiona sus datos, equipo, IA y plan.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineLoadError extends StatelessWidget {
  const _InlineLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(
          child: Text('No pudimos actualizar el nombre de la organización.'),
        ),
        AppButton.text(label: 'Reintentar', onPressed: onRetry),
      ],
    );
  }
}
