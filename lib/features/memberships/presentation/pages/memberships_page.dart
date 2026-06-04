import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/membership.dart';
import '../bloc/memberships_bloc.dart';
import '../widgets/org_membership_tile.dart';

/// Listado de orgs del operador (S02 GET /auth/memberships). Página
/// content-only: la ruta `/memberships` aporta Scaffold + AppBar.
///
/// El badge "Activa" se resuelve contra `AuthBloc.identity.orgId` para no
/// acoplarse al wire de los claims del JWT (que aquí no se ven) y para
/// que el indicador siga el mismo source-of-truth que el redirect del
/// router.
class MembershipsPage extends StatelessWidget {
  const MembershipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MembershipsBloc, MembershipsState>(
      builder: (context, state) => switch (state) {
        MembershipsInitial() || MembershipsLoading() => const _LoadingView(),
        MembershipsLoaded(items: final items) => _LoadedView(items: items),
        MembershipsFailed() => const _FailedView(),
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
    ),
  );
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.items});

  final List<Membership> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyView();
    // Resolución del orgId activo via AuthBloc: si no hay sesión la página
    // no se monta (redirect del router), así que el cast a Authenticated es
    // seguro en este árbol. Defensa: si por carrera momentánea no hay
    // identity, devolvemos string vacío y ningún tile matchea como activo.
    final auth = context.watch<AuthBloc>().state;
    final activeOrgId = auth is AuthAuthenticated ? auth.identity.orgId : '';

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp4,
        AppTokens.sp4,
        AppTokens.sp4,
        AppTokens.sp4 + context.safeBottomInset,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppTokens.cardGap),
      // Lista de solo lectura: sin `onTap`, los tiles no son tappables. El
      // switch in-app vive en la selección de organización, no aquí.
      itemBuilder: (_, i) => OrgMembershipTile(
        membership: items[i],
        isActive: items[i].orgId == activeOrgId,
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('memberships.empty'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Text(
          'Todavía no perteneces a ninguna organización',
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('memberships.error'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'No pudimos cargar tus organizaciones',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () => context.read<MembershipsBloc>().add(
                const MembershipsLoadRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
