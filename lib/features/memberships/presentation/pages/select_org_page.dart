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

/// Selección de organización para el usuario sin org activa. Página
/// content-only: la ruta `/select-org` aporta Scaffold + AppBar.
///
/// Orquesta dos blocs page-scoped: `MembershipsBloc` (lista de orgs) y
/// `SwitchOrgCubit` (el switch). El cubit no conoce ni al `AuthBloc` ni a la
/// navegación; esta página cierra el lazo:
/// - en `Switched` releemos `/auth/me` (`AuthCheckRequested`); la sesión flipa
///   a `Authenticated` y el redirect del router saca de `/select-org` a `/home`.
/// - en `Failed`/`NotMember` recargamos la lista (la membership pudo revocarse)
///   y avisamos; el resto de fallos es un reintento genérico.
///
/// "Cerrar sesión" queda siempre a mano para no encerrar al operador.
class SelectOrgPage extends StatelessWidget {
  const SelectOrgPage({super.key});

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
        // /auth/me flipa la sesión y el redirect navega fuera de la selección.
        context.read<AuthBloc>().add(const AuthCheckRequested());
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
  Widget build(BuildContext context) => Center(
    // Un /auth/memberships colgado no debe dejar al operador sin salida; el
    // affordance de cerrar sesión acompaña al spinner durante la carga.
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
        ),
        const SizedBox(height: AppTokens.sp4),
        AppButton.text(
          label: 'Cerrar sesión',
          onPressed: () => context.read<AuthBloc>().add(const AuthLoggedOut()),
        ),
      ],
    ),
  );
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.items});

  final List<Membership> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyView();
    // El orgId activo se resuelve contra el AuthBloc por consistencia con el
    // resto del feature; en /select-org la sesión es NoOrg, así que es vacío y
    // ningún tile aparece como activo (todos quedan tappables).
    final auth = context.watch<AuthBloc>().state;
    final activeOrgId = auth is AuthAuthenticated ? auth.identity.orgId : '';

    // Un switch en curso deshabilita los taps: sin esto un segundo tap mientras
    // el primero está en vuelo dispararía otro switch-org. Cubre también el
    // estado de éxito (`Switched`): la página flipa la sesión vía
    // `AuthCheckRequested`, cuyo round-trip a `/auth/me` deja esta lista montada
    // un instante; mantener los taps muertos hasta que el redirect la desmonte
    // evita una carrera con el switch ya consumado.
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
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppTokens.cardGap),
      itemBuilder: (context, i) {
        if (i == items.length) return const _SignOutFooter();
        final m = items[i];
        return OrgMembershipTile(
          membership: m,
          isActive: m.orgId == activeOrgId,
          onTap: switching
              ? null
              : () => context.read<SwitchOrgCubit>().switchTo(m.orgId),
        );
      },
    );
  }
}

/// Affordance de salida: la selección no encierra al operador. Vive al pie de
/// la lista para que también esté presente cuando hay orgs que elegir.
class _SignOutFooter extends StatelessWidget {
  const _SignOutFooter();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppTokens.sp2),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Crear una org está disponible aunque ya haya orgs que elegir: un
        // operador puede abrir una segunda organización desde aquí.
        AppButton.tonal(
          label: 'Crear organización',
          onPressed: () => context.push('/create-org'),
        ),
        const SizedBox(height: AppTokens.sp2),
        AppButton.text(
          label: 'Cerrar sesión',
          onPressed: () => context.read<AuthBloc>().add(const AuthLoggedOut()),
        ),
      ],
    ),
  );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('select_org.empty'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Todavía no perteneces a ninguna organización',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp4),
            // El invitado logueado sin membership cae aquí; crear una org o
            // aceptar una invitación son sus vías hacia adelante, así que ambos
            // affordances viven en el estado vacío (no sólo en la lista).
            AppButton.tonal(
              label: 'Crear organización',
              onPressed: () => context.push('/create-org'),
            ),
            const SizedBox(height: AppTokens.sp2),
            AppButton.text(
              label: 'Aceptar una invitación',
              onPressed: () => context.push('/accept-invite'),
            ),
            const SizedBox(height: AppTokens.sp2),
            AppButton.tonal(
              label: 'Cerrar sesión',
              onPressed: () =>
                  context.read<AuthBloc>().add(const AuthLoggedOut()),
            ),
          ],
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
      key: const Key('select_org.error'),
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
            const SizedBox(height: AppTokens.sp2),
            AppButton.text(
              label: 'Cerrar sesión',
              onPressed: () =>
                  context.read<AuthBloc>().add(const AuthLoggedOut()),
            ),
          ],
        ),
      ),
    );
  }
}
