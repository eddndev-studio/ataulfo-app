import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/role_privilege.dart';
import '../../../../core/design/tokens.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/message.dart';
import '../bloc/messages_bloc.dart';

/// Badge discreto de IA en la burbuja del bot (La Traza F5): la chispa ✦ marca
/// el OUTBOUND que nació de una corrida de IA (`aiRunId` del wire F0), sin
/// invadir el layout — vive en la fila de metadatos, junto a la hora. Para
/// ADMIN+ el tap abre el drill de ESA corrida (?run=); para roles menores es
/// solo informativo (la vista del razonamiento es ADMIN+ en el backend y un
/// tap roto sería peor que un badge inerte).
class AiRunBadge extends StatelessWidget {
  const AiRunBadge({super.key, required this.message});

  final Message message;

  static const String _label = 'Respuesta del asistente de IA';

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final canDrill =
        auth is AuthAuthenticated && isAdminOrAbove(auth.identity.role);
    return Semantics(
      button: canDrill,
      label: _label,
      child: Tooltip(
        message: _label,
        // La semántica la aporta el Semantics de arriba; sin esto el Tooltip
        // duplica el label en el nodo fusionado.
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canDrill ? () => _openDrill(context) : null,
          child: const ExcludeSemantics(
            child: Icon(Icons.auto_awesome, size: 12, color: AppTokens.text2),
          ),
        ),
      ),
    );
  }

  void _openDrill(BuildContext context) {
    final bloc = context.read<MessagesBloc>();
    context.push(
      '/bots/${bloc.botId}'
      '/sessions/${Uri.encodeComponent(bloc.chatLid)}'
      '/ai-log?run=${Uri.encodeComponent(message.aiRunId)}',
    );
  }
}
