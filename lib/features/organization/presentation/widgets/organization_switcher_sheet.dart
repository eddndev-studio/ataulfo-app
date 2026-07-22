import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_section_link.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/switch_org_cubit.dart';
import '../../../memberships/domain/entities/membership.dart';
import '../../../memberships/presentation/bloc/memberships_bloc.dart';
import '../../../memberships/presentation/widgets/org_membership_tile.dart';

/// Hoja compartida por las variantes móvil y rail del selector global.
class OrganizationSwitcherSheet extends StatelessWidget {
  const OrganizationSwitcherSheet({required this.onNavigate, super.key});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final activeOrgId = auth is AuthAuthenticated ? auth.identity.orgId : '';
    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.sp5,
              0,
              AppTokens.sp5,
              AppTokens.sp3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Cambiar organización',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    BlocBuilder<SwitchOrgCubit, SwitchOrgState>(
                      builder: (context, state) => IconButton(
                        key: const Key('organization.switch.close'),
                        tooltip: 'Cerrar',
                        icon: const Icon(Icons.close),
                        onPressed: state is SwitchOrgSwitching
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.sp1),
                Text(
                  'Los datos y acciones siguientes usarán la organización que elijas.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTokens.text2),
                ),
              ],
            ),
          ),
          BlocBuilder<SwitchOrgCubit, SwitchOrgState>(
            builder: (context, state) => AnimatedSwitcher(
              duration: AppTokens.durationFast,
              child: state is SwitchOrgSwitching
                  ? const LinearProgressIndicator(
                      key: Key('organization.switch.progress'),
                      minHeight: 2,
                    )
                  : const SizedBox(
                      key: ValueKey<String>('organization.switch.idle'),
                      height: 2,
                    ),
            ),
          ),
          Expanded(
            child: BlocBuilder<MembershipsBloc, MembershipsState>(
              builder: (context, state) => ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.sp4,
                  AppTokens.sp3,
                  AppTokens.sp4,
                  AppTokens.sp4,
                ),
                children: <Widget>[
                  switch (state) {
                    MembershipsInitial() ||
                    MembershipsLoading() => const SizedBox(
                      height: 140,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    MembershipsFailed() => _MembershipsError(
                      onRetry: () => context.read<MembershipsBloc>().add(
                        const MembershipsLoadRequested(),
                      ),
                    ),
                    MembershipsLoaded(:final items) => _MembershipsList(
                      items: items,
                      activeOrgId: activeOrgId,
                    ),
                  },
                  const SizedBox(height: AppTokens.sp4),
                  const Divider(height: 1, color: AppTokens.divider),
                  const SizedBox(height: AppTokens.sp4),
                  _SwitcherActions(onNavigate: onNavigate),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipsList extends StatelessWidget {
  const _MembershipsList({required this.items, required this.activeOrgId});

  final List<Membership> items;
  final String activeOrgId;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No encontramos organizaciones.'));
    }
    final switching =
        context.watch<SwitchOrgCubit>().state is SwitchOrgSwitching;
    return Column(
      children: <Widget>[
        for (var index = 0; index < items.length; index++) ...<Widget>[
          Builder(
            builder: (context) {
              final item = items[index];
              final active = item.orgId == activeOrgId;
              return OrgMembershipTile(
                key: Key('organization.switch.org.${item.orgId}'),
                membership: item,
                isActive: active,
                onTap: switching
                    ? null
                    : () => context.read<SwitchOrgCubit>().switchTo(item.orgId),
              );
            },
          ),
          if (index != items.length - 1) const SizedBox(height: AppTokens.sp2),
        ],
      ],
    );
  }
}

class _SwitcherActions extends StatelessWidget {
  const _SwitcherActions({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: <Widget>[
          AppSectionLink(
            rowKey: const Key('organization.switch.manage'),
            icon: Icons.tune_outlined,
            title: 'Administrar organización',
            caption: 'General, equipo, IA, plan y uso',
            onTap: () => onNavigate('/organization'),
          ),
          const Divider(height: 1, color: AppTokens.divider),
          AppSectionLink(
            rowKey: const Key('organization.switch.all'),
            icon: Icons.domain_outlined,
            title: 'Todas tus organizaciones',
            caption: 'Consulta todas tus membresías',
            onTap: () => onNavigate('/memberships'),
          ),
          const Divider(height: 1, color: AppTokens.divider),
          AppSectionLink(
            rowKey: const Key('organization.switch.join'),
            icon: Icons.mark_email_read_outlined,
            title: 'Unirme con código',
            onTap: () => onNavigate('/accept-invite'),
          ),
          const Divider(height: 1, color: AppTokens.divider),
          AppSectionLink(
            rowKey: const Key('organization.switch.create'),
            icon: Icons.add_business_outlined,
            title: 'Crear organización',
            onTap: () => onNavigate('/create-org'),
          ),
        ],
      ),
    );
  }
}

class _MembershipsError extends StatelessWidget {
  const _MembershipsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'No pudimos cargar tus organizaciones.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(label: 'Reintentar', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
