import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/i18n/role_labels.dart';
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

  /// Línea de metadatos: cuándo se envió y (si sigue PENDING) cuándo vence.
  /// El wire no trae texto relativo; se deriva de createdAt/expiresAt con [now].
  String _metaLine() {
    final sent = 'Enviada ${_ago(now.difference(invitation.createdAt))}';
    if (invitation.status != 'PENDING') return sent;
    final left = invitation.expiresAt.difference(now);
    final expiry = left.isNegative
        ? 'venció ${_ago(-left)}'
        : 'vence ${_inFuture(left)}';
    return '$sent · $expiry';
  }

  /// "hoy" / "hace 1 día" / "hace N días" para una duración ya transcurrida.
  static String _ago(Duration d) {
    final days = d.inDays;
    if (days <= 0) return 'hoy';
    return days == 1 ? 'hace 1 día' : 'hace $days días';
  }

  /// "hoy" / "en 1 día" / "en N días" para una duración futura.
  static String _inFuture(Duration d) {
    final days = d.inDays;
    if (days <= 0) return 'hoy';
    return days == 1 ? 'en 1 día' : 'en $days días';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final expired = invitation.isExpired(now);
    return AppCard(
      child: Row(
        children: <Widget>[
          AppAvatar(name: invitation.email, colorKey: invitation.email),
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
                    AppPill.neutral(label: roleLabel(invitation.role)),
                    AppPill.outline(
                      label: invitationStatusLabel(invitation.status),
                    ),
                    if (expired)
                      const AppPill.danger(
                        key: Key('invitation_tile.expired'),
                        label: 'Expirada',
                      ),
                  ],
                ),
                const SizedBox(height: AppTokens.sp2),
                Text(
                  _metaLine(),
                  style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
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
