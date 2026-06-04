import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/member.dart';
import '../../domain/failures/members_failure.dart';
import '../bloc/member_mutation_cubit.dart';
import '../bloc/members_bloc.dart';
import '../widgets/member_edit_sheet.dart';
import '../widgets/member_tile.dart';

/// Listado de miembros de la org activa (`GET /workspace/members`) con gestión
/// RBAC: tocar un miembro abre la hoja para cambiar su rol o quitarlo. Página
/// content-only: la ruta `/members` aporta Scaffold + AppBar.
///
/// De acceso cosmético admin-gated; la autoridad real es el 403 del backend.
/// Las mutaciones viven en el `MemberMutationCubit` del scope (la hoja sólo
/// devuelve la intención; esta página la despacha y cierra el lazo): ante éxito
/// recarga la lista y avisa, ante fallo traduce la causa a un aviso.
class MembersPage extends StatelessWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<MemberMutationCubit, MemberMutationState>(
      listener: _onMutationState,
      child: BlocBuilder<MembersBloc, MembersState>(
        builder: (context, state) => switch (state) {
          MembersInitial() || MembersLoading() => const _LoadingView(),
          MembersLoaded(items: final items) => _LoadedView(items: items),
          MembersFailed() => const _FailedView(),
        },
      ),
    );
  }

  void _onMutationState(BuildContext context, MemberMutationState state) {
    final messenger = ScaffoldMessenger.of(context);
    switch (state) {
      case MemberMutationSuccess(action: final action):
        // El cambio ya está en el backend: recargamos para reflejarlo.
        context.read<MembersBloc>().add(const MembersLoadRequested());
        final text = switch (action) {
          MemberMutationAction.removed => 'Miembro eliminado',
          MemberMutationAction.ownershipTransferred => 'Propiedad transferida',
          MemberMutationAction.roleChanged => 'Rol actualizado',
        };
        messenger.showSnackBar(SnackBar(content: Text(text)));
      case MemberMutationFailure(failure: final failure):
        messenger.showSnackBar(
          SnackBar(content: Text(_mutationMessage(failure))),
        );
      case MemberMutationIdle() || MemberMutationInProgress():
        break;
    }
  }
}

/// Copy de fallo por variante. Exhaustivo sobre el sellado: una variante nueva
/// rompe el build en vez de caer en un genérico silencioso.
String _mutationMessage(MembersFailure f) => switch (f) {
  MembersSelfRoleUpgradeFailure() => 'No puedes ascender tu propio rol',
  MembersSoleOwnerFailure() =>
    'La organización necesita al menos un propietario',
  MembersNotFoundFailure() => 'Ese miembro ya no existe',
  MembersForbiddenFailure() => 'No tienes permiso para esta acción',
  MembersNetworkFailure() || MembersTimeoutFailure() =>
    'Sin conexión. Revisa tu red e inténtalo de nuevo.',
  MembersNoActiveOrgFailure() ||
  MembersServerFailure() ||
  UnknownMembersFailure() => 'Algo salió mal. Inténtalo de nuevo.',
};

Future<void> _openSheet(BuildContext context, Member member) async {
  final auth = context.read<AuthBloc>().state;
  final identity = auth is AuthAuthenticated ? auth.identity : null;
  final isSelf = identity != null && identity.userId == member.userId;
  // Transferir propiedad exige OWNER REAL (no basta ADMIN; el backend 403ea).
  final callerIsOwner = identity != null && identity.role == 'OWNER';
  // Capturamos el cubit antes del await: tras cerrar la hoja no usamos el
  // context de la página para nada que cruce el gap async.
  final cubit = context.read<MemberMutationCubit>();
  final result = await MemberEditSheet.open(
    context,
    member: member,
    isSelf: isSelf,
    callerIsOwner: callerIsOwner,
  );
  // Fire-and-forget a propósito: el resultado de la mutación se observa por el
  // BlocListener de la página (recarga + aviso), no por este await.
  switch (result) {
    case MemberSheetRoleChange(role: final role):
      unawaited(cubit.changeRole(member.id, role));
    case MemberSheetRemove():
      unawaited(cubit.remove(member.id));
    case MemberSheetTransfer():
      unawaited(cubit.transfer(member.id));
    case MemberSheetAssignBots():
      // El picker de bots es una pantalla aparte (carga + multi-select + save).
      if (context.mounted) {
        unawaited(context.push('/members/${member.id}/bots'));
      }
    case null:
      break;
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

  final List<Member> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyView();
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
        return MemberTile(member: m, onTap: () => _openSheet(context, m));
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
      key: const Key('members.empty'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Text(
          'Esta organización no tiene miembros',
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
      key: const Key('members.error'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'No pudimos cargar los miembros',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () =>
                  context.read<MembersBloc>().add(const MembersLoadRequested()),
            ),
          ],
        ),
      ),
    );
  }
}
