import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_avatar.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/invitation.dart';

/// Fila del historial de una invitación: correo + rol + estado, con un badge
/// "Expirada" cuando una PENDING ya caducó (derivado con [now], que el wire no
/// trae). Muestra la acción de cancelar sólo cuando recibe [onCancel] — la
/// página la pasa en las PENDING (caducadas incluidas, que aún bloquean
/// reinvitar) y la omite en las terminales (ACCEPTED/CANCELED).
class InvitationTile extends StatelessWidget {
  const InvitationTile({
    super.key,
    required this.invitation,
    required this.now,
    this.onCancel,
  });

  final Invitation invitation;
  final DateTime now;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final expired = invitation.isExpired(now);
    return AppCard(
      child: Row(
        children: <Widget>[
          AppAvatar(name: invitation.email),
          const SizedBox(width: AppTokens.sp4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(invitation.email, style: textTheme.titleMedium),
                const SizedBox(height: AppTokens.sp2),
                Wrap(
                  spacing: AppTokens.sp2,
                  runSpacing: AppTokens.sp2,
                  children: <Widget>[
                    AppPill.neutral(label: invitation.role),
                    AppPill.outline(label: invitation.status),
                    if (expired)
                      const AppPill.danger(
                        key: Key('invitation_tile.expired'),
                        label: 'Expirada',
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (onCancel != null)
            IconButton(
              key: const Key('invitation_tile.cancel'),
              tooltip: 'Cancelar invitación',
              icon: const Icon(Icons.close, color: AppTokens.danger),
              onPressed: onCancel,
            ),
        ],
      ),
    );
  }
}
