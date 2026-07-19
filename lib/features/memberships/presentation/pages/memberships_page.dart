import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/role_privilege.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../auth/domain/failures/auth_failure.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/rename_org_cubit.dart';
import '../../../auth/presentation/bloc/switch_org_cubit.dart';
import '../../domain/entities/membership.dart';
import '../bloc/memberships_bloc.dart';
import '../widgets/org_membership_tile.dart';
import '../widgets/pending_invitations_section.dart';
import '../widgets/rename_org_sheet.dart';

/// Listado de orgs del operador con cambio de organización in-app (S02 GET
/// /auth/memberships + switch-org). Página content-only: la ruta `/memberships`
/// aporta Scaffold + AppBar.
///
/// El badge "Activa" se resuelve contra `AuthBloc.identity.orgId` para no
/// acoplarse al wire de los claims del JWT (que aquí no se ven) y para que el
/// indicador siga el mismo source-of-truth que el redirect del router.
///
/// Tocar una org NO activa dispara el `SwitchOrgCubit`. El cubit no conoce ni al
/// `AuthBloc` ni a la navegación; esta página cierra el lazo:
/// - en `Switched` releemos `/auth/me` (`AuthCheckRequested`) para flipar la
///   sesión y navegamos a `/home`. Aquí navegamos a mano (a diferencia de
///   `/select-org`, que el redirect saca solo): un operador con org activa no es
///   auto-redirigido fuera de `/memberships`, y queremos que vea de inmediato el
///   contexto de la org nueva. El shell se re-keyea por orgId, así que sus datos
///   ya no son stale.
/// - en `Failed`/`NotMember` recargamos la lista (la membership pudo revocarse)
///   y avisamos; el resto de fallos es un reintento genérico.
class MembershipsPage extends StatelessWidget {
  const MembershipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SwitchOrgCubit, SwitchOrgState>(
      listener: _onSwitchState,
      child: BlocListener<RenameOrgCubit, RenameOrgState>(
        listener: _onRenameState,
        // Las invitaciones pendientes van ARRIBA de la lista y como hermanas
        // del switch de estado (no dentro de la vista cargada): así siguen
        // visibles aunque la lista esté vacía o falle — el caso de un usuario
        // recién creado con una invitación esperando es exactamente ese.
        child: Column(
          children: <Widget>[
            const PendingInvitationsSection(),
            Expanded(
              child: BlocBuilder<MembershipsBloc, MembershipsState>(
                builder: (context, state) => switch (state) {
                  MembershipsInitial() ||
                  MembershipsLoading() => const _LoadingView(),
                  MembershipsLoaded(items: final items) => _LoadedView(
                    items: items,
                  ),
                  MembershipsFailed() => const _FailedView(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onRenameState(BuildContext context, RenameOrgState state) {
    switch (state) {
      case RenameOrgRenamed():
        // El nombre no viaja en el JWT: recargamos memberships para verlo fresco.
        context.read<MembershipsBloc>().add(const MembershipsLoadRequested());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organización renombrada')),
        );
      case RenameOrgFailed(failure: final f):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              f is NetworkFailure
                  ? 'Sin conexión. Revisa tu red e inténtalo de nuevo.'
                  : 'No pudimos renombrar la organización. Inténtalo de nuevo.',
            ),
          ),
        );
      case RenameOrgIdle() || RenameOrgRenaming():
        break;
    }
  }

  void _onSwitchState(BuildContext context, SwitchOrgState state) {
    switch (state) {
      case SwitchOrgSwitched():
        // El nuevo par de tokens ya está persistido (lo hizo el repo); releer
        // /auth/me flipa la sesión y navegamos al shell, ya re-keyeado a la org
        // nueva, para que el operador vea su contexto recién cambiado.
        context.read<AuthBloc>().add(const AuthCheckRequested());
        context.go('/home');
      case SwitchOrgFailed(failure: final f):
        final messenger = ScaffoldMessenger.of(context);
        if (f is NotMemberFailure) {
          // La membership se revocó (o era ajena): la lista está desfasada,
          // así que la recargamos antes de avisar.
          context.read<MembershipsBloc>().add(const MembershipsLoadRequested());
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Ya no eres miembro de esa organización'),
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('No pudimos cambiar de organización, reintenta'),
            ),
          );
        }
      case SwitchOrgIdle() || SwitchOrgSwitching():
        break;
    }
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const AppLoadingIndicator();
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
    final activeRole = auth is AuthAuthenticated ? auth.identity.role : '';

    // Un switch en curso deshabilita los taps: sin esto un segundo tap mientras
    // el primero está en vuelo dispararía otro switch-org. Cubre también el
    // estado de éxito (`Switched`): la página flipa la sesión y navega, pero
    // hasta que el árbol se desmonte un segundo tap rápido correría carrera con
    // el switch ya consumado.
    final switchState = context.watch<SwitchOrgCubit>().state;
    final switching =
        switchState is SwitchOrgSwitching || switchState is SwitchOrgSwitched;

    // Nombre legible de la org activa, para precargar la hoja de renombrado.
    final activeMatches = items.where((m) => m.orgId == activeOrgId);
    final activeName = activeMatches.isEmpty
        ? null
        : activeMatches.first.orgName;

    return Column(
      children: <Widget>[
        // Cambio de organización en vuelo: barra fina arriba de la lista —
        // los taps ya están deshabilitados, pero sin esta señal el tile
        // tocado parece ignorado.
        if (switching)
          const LinearProgressIndicator(
            key: Key('memberships.switching'),
            color: AppTokens.primary,
            backgroundColor: Colors.transparent,
          ),
        Expanded(
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppTokens.sp4,
              AppTokens.sp4,
              AppTokens.sp4,
              AppTokens.sp4 + context.safeBottomInset,
            ),
            // +1 por el pie de acciones (crear / renombrar).
            itemCount: items.length + 1,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppTokens.cardGap),
            itemBuilder: (context, i) {
              if (i == items.length) {
                return _OrgActionsFooter(
                  // Renombrar es admin-gated (cosmético; el backend 403ea por debajo
                  // de ADMIN). Sin nombre activo (carrera) no se ofrece.
                  renameName: isAdminOrAbove(activeRole) ? activeName : null,
                );
              }
              final m = items[i];
              return OrgMembershipTile(
                membership: m,
                isActive: m.orgId == activeOrgId,
                // La org activa nunca es tappable (el tile lo anula con isActive); un
                // switch en curso mata el resto de taps.
                onTap: switching
                    ? null
                    : () => context.read<SwitchOrgCubit>().switchTo(m.orgId),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Pie de acciones de organización: crear una nueva (siempre) y renombrar la
/// activa (sólo si [renameName] != null, es decir ADMIN+ con un nombre activo).
class _OrgActionsFooter extends StatelessWidget {
  const _OrgActionsFooter({required this.renameName});

  final String? renameName;

  Future<void> _openRename(BuildContext context, String currentName) async {
    final cubit = context.read<RenameOrgCubit>();
    final newName = await RenameOrgSheet.open(
      context,
      currentName: currentName,
    );
    if (newName == null) return;
    unawaited(cubit.rename(newName));
  }

  @override
  Widget build(BuildContext context) {
    final name = renameName;
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.sp2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppButton.tonal(
            key: const Key('memberships.create'),
            label: 'Crear organización',
            fullWidth: true,
            onPressed: () => context.push('/create-org'),
          ),
          if (name != null) ...<Widget>[
            const SizedBox(height: AppTokens.sp2),
            AppButton.text(
              key: const Key('memberships.rename'),
              label: 'Renombrar organización',
              fullWidth: true,
              onPressed: () => _openRename(context, name),
            ),
          ],
        ],
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
