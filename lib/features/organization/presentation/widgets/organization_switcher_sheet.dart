import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_entity_icon.dart';
import '../../../../core/design/widgets/app_section_link.dart';
import '../../../../core/i18n/role_labels.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/switch_org_cubit.dart';
import '../../../memberships/domain/entities/membership.dart';
import '../../../memberships/presentation/bloc/memberships_bloc.dart';

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
            key: const Key('organization.switch.header'),
            padding: const EdgeInsets.fromLTRB(
              AppTokens.sp5,
              AppTokens.sp3,
              AppTokens.sp5,
              AppTokens.sp4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Cambiar organización',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppTokens.sp2),
                Text(
                  'Los datos y acciones siguientes usarán la organización que elijas.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
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
                  AppTokens.sp4,
                  AppTokens.sp4,
                  0,
                ),
                children: <Widget>[
                  const _SheetSectionLabel('Tus organizaciones'),
                  const SizedBox(height: AppTokens.sp2),
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
                  const SizedBox(height: AppTokens.sp6),
                  const _SheetSectionLabel('Más opciones'),
                  const SizedBox(height: AppTokens.sp2),
                  _SwitcherActions(onNavigate: onNavigate),
                  SizedBox(height: AppTokens.sp5 + context.sheetBottomInset),
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
    return Material(
      key: const Key('organization.switch.list'),
      color: AppTokens.surface2,
      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (var index = 0; index < items.length; index++) ...<Widget>[
            _OrganizationChoice(
              membership: items[index],
              active: items[index].orgId == activeOrgId,
              onTap: switching || items[index].orgId == activeOrgId
                  ? null
                  : () => context.read<SwitchOrgCubit>().switchTo(
                      items[index].orgId,
                    ),
            ),
            if (index != items.length - 1)
              const Divider(
                height: 1,
                indent: AppTokens.sp4,
                endIndent: AppTokens.sp4,
                color: AppTokens.divider,
              ),
          ],
        ],
      ),
    );
  }
}

class _OrganizationChoice extends StatelessWidget {
  const _OrganizationChoice({
    required this.membership,
    required this.active,
    required this.onTap,
  });

  final Membership membership;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      selected: active,
      button: onTap != null,
      child: InkWell(
        key: Key('organization.switch.org.${membership.orgId}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.sp4,
            vertical: AppTokens.sp3,
          ),
          child: Row(
            children: <Widget>[
              AppEntityIcon(
                icon: Icons.apartment_outlined,
                size: 44,
                highlighted: active,
              ),
              const SizedBox(width: AppTokens.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      membership.orgName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTokens.sp1),
                    Text(
                      roleLabel(membership.role),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppTokens.text2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.sp3),
              AnimatedSwitcher(
                duration: AppTokens.durationFast,
                switchInCurve: AppTokens.easeSpring,
                switchOutCurve: AppTokens.ease,
                child: active
                    ? Container(
                        key: Key(
                          'organization.switch.active.${membership.orgId}',
                        ),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTokens.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusPill,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: AppTokens.primary,
                        ),
                      )
                    : const Icon(
                        Icons.chevron_right,
                        key: ValueKey<String>('organization.switch.available'),
                        color: AppTokens.text2,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppTokens.text2,
        letterSpacing: 0.8,
      ),
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
