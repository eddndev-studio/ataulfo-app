import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../auth/domain/failures/auth_failure.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/switch_org_cubit.dart';
import '../../domain/entities/membership.dart';
import '../bloc/memberships_bloc.dart';
import '../widgets/org_membership_tile.dart';

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
      child: BlocBuilder<MembershipsBloc, MembershipsState>(
        builder: (context, state) => switch (state) {
          MembershipsInitial() || MembershipsLoading() => const _LoadingView(),
          MembershipsLoaded(items: final items) => _LoadedView(items: items),
          MembershipsFailed() => const _FailedView(),
        },
      ),
    );
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

    // Un switch en curso deshabilita los taps: sin esto un segundo tap mientras
    // el primero está en vuelo dispararía otro switch-org. Cubre también el
    // estado de éxito (`Switched`): la página flipa la sesión y navega, pero
    // hasta que el árbol se desmonte un segundo tap rápido correría carrera con
    // el switch ya consumado.
    final switchState = context.watch<SwitchOrgCubit>().state;
    final switching =
        switchState is SwitchOrgSwitching || switchState is SwitchOrgSwitched;

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
      itemBuilder: (context, i) {
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
