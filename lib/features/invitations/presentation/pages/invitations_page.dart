import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_entity_icon.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../domain/entities/invitation.dart';
import '../../domain/failures/invitations_failure.dart';
import '../bloc/invitation_mutation_cubit.dart';
import '../bloc/invitations_bloc.dart';
import '../widgets/invitation_share_sheet.dart';
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
      case InvitationMutationSuccess(action: InvitationMutationAction.created):
        context.read<InvitationsBloc>().add(const InvitationsLoadRequested());
        // La hoja de compartir ES el feedback: muestra el código para pasarlo
        // por WhatsApp y es honesta sobre si el correo salió (sin el viejo
        // aviso "enviada por correo" que mentía cuando el envío fallaba).
        unawaited(
          InvitationShareSheet.open(
            context,
            email: state.email ?? '',
            token: state.token,
            emailSent: state.emailSent,
          ),
        );
      case InvitationMutationSuccess():
        context.read<InvitationsBloc>().add(const InvitationsLoadRequested());
        messenger.showSnackBar(
          const SnackBar(content: Text('Invitación cancelada')),
        );
      case InvitationMutationFailure(failure: final failure):
        // Recargamos cuando el fallo deja la lista local desfasada: 404/410 (la
        // invitación cambió de estado en el servidor) y 5xx (un create puede
        // haber guardado la fila aunque el correo fallara — sin endpoint de
        // reenvío, mostrar el historial fresco es la única salida honesta).
        if (failure is InvitationsNotFoundFailure ||
            failure is InvitationsGoneFailure ||
            failure is InvitationsServerFailure) {
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
  final confirmed = await showAppConfirmDialog(
    context,
    title: '¿Cancelar invitación?',
    message:
        'Se anulará la invitación a "${invitation.email}". El enlace que recibió '
        'dejará de funcionar. Esta acción no se puede deshacer.',
    confirmLabel: 'Cancelar invitación',
    cancelLabel: 'Volver',
    confirmKey: const Key('invitations.cancel_confirm'),
  );
  if (!confirmed) return;
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
        InvitationsInitial() ||
        InvitationsLoading() => const AppLoadingIndicator(),
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
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.sp5),
          child: AppCard.glass(
            key: const Key('invitations.empty'),
            padding: const EdgeInsets.all(AppTokens.cardPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const AppEntityIcon(
                  icon: Icons.mail_outline,
                  size: 56,
                  highlighted: true,
                ),
                const SizedBox(height: AppTokens.sp4),
                Text(
                  'Todavía no hay invitaciones',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.sp2),
                Text(
                  'Toca "Invitar" para sumar a alguien: le damos un código '
                  'para compartir por WhatsApp o por correo.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
                ),
              ],
            ),
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
