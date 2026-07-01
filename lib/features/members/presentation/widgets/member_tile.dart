import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/i18n/role_labels.dart';
import '../../../../core/design/widgets/app_avatar.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/member.dart';

/// Fila de un miembro de la organización: avatar + correo + pill de rol y un
/// badge de verificación de correo.
///
/// El badge distingue a quien ya confirmó su correo ("Verificado") de un alta
/// pendiente ("Sin confirmar", en tono de alerta para que salte a la vista).
///
/// Tappable sólo cuando recibe [onTap]: la lista lo cablea para abrir la hoja
/// de gestión (cambiar rol / quitar); sin él el tile es de solo lectura.
class MemberTile extends StatelessWidget {
  const MemberTile({
    super.key,
    required this.member,
    this.onTap,
    this.isSelf = false,
  });

  final Member member;
  final VoidCallback? onTap;

  /// Este miembro es el operador de la sesión: se marca con una pill "Tú"
  /// para orientarse de un vistazo en el listado.
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          AppAvatar(name: member.email, colorKey: member.email),
          const SizedBox(width: AppTokens.sp4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(member.email, style: textTheme.titleMedium),
                const SizedBox(height: AppTokens.sp2),
                Wrap(
                  spacing: AppTokens.sp2,
                  runSpacing: AppTokens.sp2,
                  children: <Widget>[
                    if (isSelf)
                      const AppPill.primary(
                        key: Key('members.self_badge'),
                        label: 'Tú',
                      ),
                    AppPill.neutral(label: roleLabel(member.role)),
                    if (member.emailVerified)
                      const AppPill.outline(
                        key: Key('members.verified_badge'),
                        label: 'Verificado',
                      )
                    else
                      // Pendiente de verificación es normal, no un error: pill
                      // de contorno (sin el rojo alarmante de antes).
                      const AppPill.outline(
                        key: Key('members.unverified_badge'),
                        label: 'Sin confirmar',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
