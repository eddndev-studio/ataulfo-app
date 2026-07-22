import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_entity_icon.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/i18n/role_labels.dart';
import '../../domain/entities/membership.dart';

/// Fila de una organización del operador: glifo de entidad + nombre + pill de
/// rol, con un badge "Activa" cuando es la org de la sesión vigente. Una
/// organización no es una persona: lleva [AppEntityIcon], nunca el avatar
/// circular con inicial (reservado a miembros/contactos).
///
/// Es tappable sólo cuando recibe [onTap] Y NO es la org activa: la lista de
/// `/memberships` la monta sin `onTap` (solo lectura), mientras la selección
/// de org la monta con `onTap` para disparar el switch. La org activa nunca
/// es tappable — cambiar a la org en la que ya estás no tiene efecto y un tap
/// ahí sólo arriesga un doble-switch.
class OrgMembershipTile extends StatelessWidget {
  const OrgMembershipTile({
    super.key,
    required this.membership,
    required this.isActive,
    this.onTap,
  });

  final Membership membership;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: isActive ? null : onTap,
      child: Row(
        children: <Widget>[
          const AppEntityIcon(icon: Icons.apartment_outlined),
          const SizedBox(width: AppTokens.sp4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(membership.orgName, style: textTheme.titleMedium),
                const SizedBox(height: AppTokens.sp2),
                Wrap(
                  spacing: AppTokens.sp2,
                  runSpacing: AppTokens.sp2,
                  children: <Widget>[
                    AppPill.neutral(label: roleLabel(membership.role)),
                    if (isActive)
                      const AppPill.primary(
                        key: Key('memberships.active_badge'),
                        label: 'Activa',
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
