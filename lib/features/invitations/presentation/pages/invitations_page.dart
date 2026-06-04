import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../domain/entities/invitation.dart';
import '../../domain/failures/invitations_failure.dart';
import '../bloc/invitation_mutation_cubit.dart';
import '../bloc/invitations_bloc.dart';
import '../widgets/invitation_tile.dart';
import '../widgets/invite_sheet.dart';

/// Historial de invitaciones de la org activa con emisión y cancelación. Página
/// content-only: la ruta `/invitations` aporta Scaffold + AppBar.
///
/// El botón "Invitar" vive en la chrome persistente (siempre visible, también
/// con el historial vacío) para que una org recién creada no quede sin salida.
/// Las mutaciones viven en el `InvitationMutationCubit` del scope (la hoja sólo
/// devuelve la intención; esta página despacha): ante éxito recarga el historial
/// y avisa; ante 404/410 también recarga porque la lista local quedó stale.
class InvitationsPage extends StatelessWidget {
  const InvitationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<InvitationMutationCubit, InvitationMutationState>(
      listener: _onMutationState,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.sp4,
              AppTokens.sp4,
              AppTokens.sp4,
              0,
            ),
            child: AppButton.filled(
              key: const Key('invitations.invite'),
              label: 'Invitar',
              onPressed: () => _openInviteSheet(context),
            ),
          ),
          const Expanded(child: _Body()),
        ],
      ),
    );
  }

  void _onMutationState(BuildContext context, InvitationMutationState state) {
    final messenger = ScaffoldMessenger.of(context);
    switch (state) {
      case InvitationMutationSuccess(action: final action, email: final email):
        context.read<InvitationsBloc>().add(const InvitationsLoadRequested());
        final text = action == InvitationMutationAction.created
            ? 'Invitación enviada por correo a $email'
            : 'Invitación cancelada';
        messenger.showSnackBar(SnackBar(content: Text(text)));
      case InvitationMutationFailure(failure: final failure):
        // 404/410 significan que la lista local quedó stale: recargar.
        if (failure is InvitationsNotFoundFailure ||
            failure is InvitationsGoneFailure) {
          context.read<InvitationsBloc>().add(const InvitationsLoadRequested());
        }
        messenger.showSnackBar(
          SnackBar(content: Text(_mutationMessage(failure))),
        );
      case InvitationMutationIdle() || InvitationMutationInProgress():
        break;
    }
  }
}

Future<void> _openInviteSheet(BuildContext context) async {
  final cubit = context.read<InvitationMutationCubit>();
  final result = await InviteSheet.open(context);
  if (result == null) return;
  unawaited(cubit.create(result.email, result.role));
}

Future<void> _confirmCancel(BuildContext context, Invitation invitation) async {
  final cubit = context.read<InvitationMutationCubit>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Cancelar invitación?'),
      content: Text(
        'Se anulará la invitación a "${invitation.email}". El enlace que recibió '
        'dejará de funcionar. Esta acción no se puede deshacer.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Volver'),
        ),
        TextButton(
          key: const Key('invitations.cancel_confirm'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text(
            'Cancelar invitación',
            style: TextStyle(color: AppTokens.danger),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  unawaited(cubit.cancel(invitation.id));
}

/// Copy de fallo por variante. Exhaustivo sobre el sellado.
String _mutationMessage(InvitationsFailure f) => switch (f) {
  InvitationsDuplicateFailure() =>
    'Ya hay una invitación pendiente para ese correo; '
        'cancélala para reinvitar.',
  InvitationsValidationFailure() => 'Revisa el correo y vuelve a intentarlo.',
  InvitationsGoneFailure() => 'Esa invitación ya no se puede cancelar.',
  InvitationsNotFoundFailure() => 'Esa invitación ya no existe.',
  InvitationsForbiddenFailure() =>
    'No tienes permiso para gestionar invitaciones.',
  InvitationsNetworkFailure() || InvitationsTimeoutFailure() =>
    'Sin conexión. Revisa tu red e inténtalo de nuevo.',
  InvitationsServerFailure() =>
    'No pudimos confirmar la operación; revisa el historial.',
  UnknownInvitationsFailure() => 'Algo salió mal. Inténtalo de nuevo.',
};

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InvitationsBloc, InvitationsState>(
      builder: (context, state) => switch (state) {
        InvitationsInitial() || InvitationsLoading() => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
          ),
        ),
        InvitationsLoaded(items: final items) => _LoadedView(items: items),
        InvitationsFailed() => const _FailedView(),
      },
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.items});

  final List<Invitation> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      final textTheme = Theme.of(context).textTheme;
      return Center(
        key: const Key('invitations.empty'),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.sp6),
          child: Text(
            'Todavía no hay invitaciones',
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge,
          ),
        ),
      );
    }
    final now = DateTime.now();
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
        final inv = items[i];
        // Sólo las PENDING (caducadas incluidas, que aún bloquean reinvitar)
        // ofrecen cancelar; las terminales no.
        final canCancel = inv.status == 'PENDING';
        return InvitationTile(
          invitation: inv,
          now: now,
          onCancel: canCancel ? () => _confirmCancel(context, inv) : null,
        );
      },
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('invitations.error'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'No pudimos cargar las invitaciones',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () => context.read<InvitationsBloc>().add(
                const InvitationsLoadRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
