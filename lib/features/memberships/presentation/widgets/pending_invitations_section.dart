import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/i18n/role_labels.dart';
import '../../../auth/domain/entities/pending_invitation.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/pending_invitations_cubit.dart';
import '../bloc/memberships_bloc.dart';

/// Sección "Invitaciones pendientes" que se pinta ARRIBA de la lista de
/// organizaciones. Fricción baja: si no hay pendientes (o falló la carga) se
/// oculta sin dejar rastro. Vive en el árbol de `/memberships`, así que lee el
/// `PendingInvitationsCubit` (de auth, como el resto de blocs de auth que la
/// página ya consume) y el `MembershipsBloc` para recargar tras unirse.
///
/// La propia sección acota su alto y hace scroll interno: con varias
/// invitaciones no desborda la Column de la página (la lista de organizaciones
/// conserva su espacio debajo).
class PendingInvitationsSection extends StatelessWidget {
  const PendingInvitationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PendingInvitationsCubit, PendingInvitationsState>(
      builder: (context, state) {
        if (state is! PendingInvitationsReady || state.items.isEmpty) {
          return const SizedBox.shrink();
        }
        final textTheme = Theme.of(context).textTheme;
        // Tope de alto para que la sección no se coma la pantalla ni desborde:
        // hasta ~40% de la altura, con scroll interno si hay muchas.
        final maxHeight = MediaQuery.sizeOf(context).height * 0.4;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.sp4,
            AppTokens.sp4,
            AppTokens.sp4,
            0,
          ),
          child: Column(
            key: const Key('memberships.pending_section'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Invitaciones pendientes',
                style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
              ),
              const SizedBox(height: AppTokens.sp2),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: state.items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppTokens.cardGap),
                  itemBuilder: (context, i) {
                    final inv = state.items[i];
                    return _PendingTile(
                      invitation: inv,
                      joining: state.joiningId == inv.id,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.invitation, required this.joining});

  final PendingInvitation invitation;
  final bool joining;

  Future<void> _join(BuildContext context) async {
    final cubit = context.read<PendingInvitationsCubit>();
    final membershipsBloc = context.read<MembershipsBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await cubit.join(invitation.id);
    if (!context.mounted) return;
    switch (result) {
      case PendingJoinOk(:final orgName):
        // La org nueva aparece al recargar memberships; el operador la activa
        // tocándola (flujo de switch-org existente).
        membershipsBloc.add(const MembershipsLoadRequested());
        messenger.showSnackBar(
          SnackBar(content: Text('Ya eres parte de $orgName')),
        );
      case PendingJoinAlreadyMember():
        // Ya eras miembro: recarga por si la lista de orgs estaba desfasada.
        membershipsBloc.add(const MembershipsLoadRequested());
        messenger.showSnackBar(
          const SnackBar(content: Text('Ya eres parte de esta organización')),
        );
      case PendingJoinNeedsVerification():
        _showNeedsVerification(context, messenger);
      case PendingJoinGone():
        messenger.showSnackBar(
          const SnackBar(content: Text('La invitación ya no está disponible')),
        );
      case PendingJoinFailed():
        messenger.showSnackBar(
          const SnackBar(content: Text('No pudimos unirte, reintenta')),
        );
    }
  }

  /// 403 al unirse (en la práctica no ocurre: la lista sólo aparece con el
  /// correo ya verificado, pero se cubre por contrato). El router y el correo de
  /// la sesión se capturan aquí —tras la guarda de `mounted`— y el enlace de la
  /// acción usa el router capturado, no el context, que en el diferido podría
  /// estar defunct.
  void _showNeedsVerification(
    BuildContext context,
    ScaffoldMessengerState messenger,
  ) {
    final router = GoRouter.of(context);
    final auth = context.read<AuthBloc>().state;
    final email = auth is AuthAuthenticated ? auth.identity.email : '';
    final loc = email.isEmpty
        ? '/verify-email'
        : '/verify-email?email=${Uri.encodeQueryComponent(email)}';
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Verifica tu correo primero'),
        action: SnackBarAction(
          label: 'Verificar',
          onPressed: () => router.push(loc),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      key: Key('memberships.pending.${invitation.id}'),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  invitation.orgName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.sp1),
                AppPill.neutral(label: roleLabel(invitation.role)),
                if (invitation.role == 'WORKER') ...<Widget>[
                  const SizedBox(height: AppTokens.sp2),
                  Text(
                    _assignedChannels(invitation.botIds.length),
                    key: const Key('memberships.pending.channels'),
                    style: textTheme.labelSmall?.copyWith(
                      color: invitation.botIds.isEmpty
                          ? AppTokens.warning
                          : AppTokens.text2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppTokens.sp3),
          AppButton.tonal(
            key: Key('memberships.pending.join.${invitation.id}'),
            label: 'Unirse',
            loading: joining,
            onPressed: joining ? null : () => _join(context),
          ),
        ],
      ),
    );
  }
}

String _assignedChannels(int count) => switch (count) {
  0 => 'Sin Canales asignados',
  1 => '1 Canal asignado',
  _ => '$count Canales asignados',
};
