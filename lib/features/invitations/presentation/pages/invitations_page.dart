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
import '../../../bots/domain/entities/bot.dart';
import '../../../bots/presentation/bloc/bots_bloc.dart';
import '../../domain/entities/invitation.dart';
import '../../domain/failures/invitations_failure.dart';
import '../bloc/invitation_mutation_cubit.dart';
import '../bloc/invitations_bloc.dart';
import '../invitation_failure_copy.dart';
import '../widgets/invitation_tile.dart';
import '../widgets/invite_sheet.dart';

/// Historial de invitaciones de la org activa con emisión y cancelación. Página
/// content-only: la ruta `/invitations` aporta Scaffold + AppBar.
///
/// El botón "Invitar" vive en la chrome persistente (siempre visible, también
/// con el historial vacío) para que una org recién creada no quede sin salida.
/// La creación vive dentro de [InviteSheet] para mantener un único modal; el
/// `InvitationMutationCubit` del scope queda dedicado a cancelar. Ante éxito
/// o ante un fallo que pueda dejar la lista stale, la página recarga.
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
            child: BlocBuilder<BotsBloc, BotsState>(
              builder: (context, state) => AppButton.filled(
                key: const Key('invitations.invite'),
                label: switch (state) {
                  BotsLoaded() => 'Invitar',
                  BotsFailed() => 'Reintentar Canales',
                  _ => 'Cargando Canales…',
                },
                onPressed: switch (state) {
                  BotsLoaded(items: final bots) => () => _openInviteSheet(
                    context,
                    bots,
                  ),
                  BotsFailed() => () {
                    context.read<BotsBloc>().add(const BotsLoadRequested());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Necesitamos cargar los Canales antes de invitar.',
                        ),
                      ),
                    );
                  },
                  _ => null,
                },
              ),
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
        // Defensa para consumidores antiguos del cubit de página. El flujo
        // actual crea dentro de InviteSheet y recarga al cerrar ese mismo modal.
        context.read<InvitationsBloc>().add(const InvitationsLoadRequested());
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
          SnackBar(content: Text(invitationFailureMessage(failure))),
        );
      case InvitationMutationIdle() || InvitationMutationInProgress():
        break;
    }
  }
}

Future<void> _openInviteSheet(BuildContext context, List<Bot> bots) async {
  final shouldRefresh = await InviteSheet.open(context, bots: bots);
  if (!context.mounted || !shouldRefresh) return;
  context.read<InvitationsBloc>().add(const InvitationsLoadRequested());
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
