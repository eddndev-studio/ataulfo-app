import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/ai/tool_groups_sheet.dart';
import '../../../../core/design/tokens.dart';
import '../../../templates/domain/entities/template.dart';
import '../../../templates/domain/repositories/templates_repository.dart';
import '../../domain/entities/bot.dart';
import '../bloc/bot_detail_bloc.dart';

/// Fila "Permisos de herramientas" del detalle de un Bot: el bot puede RESTRINGIR
/// más allá de su plantilla qué grupos de capacidad usa el agente IA. El permiso
/// efectivo es la unión plantilla ∪ bot — el bot sólo suma restricciones.
///
/// Para mostrar los grupos que la plantilla ya apaga (bloqueados, no editables
/// aquí) hace falta `template.ai.disabledToolGroups`, tras un endpoint ADMIN+
/// (`GET /templates/:id`). Por eso este widget se monta SÓLO en el render ADMIN+
/// del detalle (igual que BotAiToggle), y degrada con cuidado: mientras la
/// plantilla carga la fila es inerte; si el fetch falla, sigue operable sin la
/// información de bloqueo (el override del bot es real y editable).
class BotToolPermissions extends StatefulWidget {
  const BotToolPermissions({
    super.key,
    required this.bot,
    required this.isMutating,
  });

  final Bot bot;
  final bool isMutating;

  @override
  State<BotToolPermissions> createState() => _BotToolPermissionsState();
}

class _BotToolPermissionsState extends State<BotToolPermissions> {
  late final Future<Template> _template;

  @override
  void initState() {
    super.initState();
    _template = context.read<TemplatesRepository>().byId(widget.bot.templateId);
  }

  Future<void> _edit(List<String> lockedGroups) async {
    final bloc = context.read<BotDetailBloc>();
    final picked = await showAppBottomSheet<List<String>>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => ToolGroupsSheet(
        initialDisabledGroups: widget.bot.disabledToolGroups,
        lockedDisabledGroups: lockedGroups,
      ),
    );
    if (picked == null) return;
    bloc.add(BotDetailUpdateRequested(disabledToolGroups: picked));
  }

  @override
  Widget build(BuildContext context) {
    final ownCount = widget.bot.disabledToolGroups.length;
    return FutureBuilder<Template>(
      future: _template,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _Row(
            caption: 'Comprobando los permisos de la plantilla…',
            onTap: null,
          );
        }
        // Sin la plantilla no sabemos qué grupos bloquea; el override del bot
        // sigue siendo real y editable (locked vacío).
        final lockedGroups = snap.hasError
            ? const <String>[]
            : snap.data!.ai.disabledToolGroups;
        return _Row(
          caption: _caption(ownCount, lockedGroups.length, snap.hasError),
          onTap: widget.isMutating ? null : () => _edit(lockedGroups),
        );
      },
    );
  }

  static String _caption(int own, int locked, bool unknownTemplate) {
    final base = own == 0
        ? 'Sin restricciones extra de este bot'
        : '$own ${own == 1 ? 'grupo restringido' : 'grupos restringidos'} por este bot';
    if (unknownTemplate) {
      return '$base · no se pudo leer la plantilla';
    }
    if (locked > 0) {
      return '$base · la plantilla ya restringe $locked';
    }
    return base;
  }
}

/// Fila tappable consistente con la tarjeta de controles del detalle: ícono +
/// label + caption + chevron. onTap nulo ⇒ inerte (gris).
class _Row extends StatelessWidget {
  const _Row({required this.caption, required this.onTap});

  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final enabled = onTap != null;
    return InkWell(
      key: const Key('bot_detail.tool_permissions'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp2),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.build_circle_outlined,
              color: enabled ? AppTokens.text1 : AppTokens.text2,
              size: 24,
            ),
            const SizedBox(width: AppTokens.sp3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Permisos de herramientas',
                    style: textTheme.bodyLarge?.copyWith(
                      color: enabled ? AppTokens.text1 : AppTokens.text2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTokens.text2,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTokens.text2, size: 22),
          ],
        ),
      ),
    );
  }
}
