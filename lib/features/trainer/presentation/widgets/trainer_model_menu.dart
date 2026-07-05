import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../bloc/trainer_chat_bloc.dart';

/// Menú de modelo del entrenador. Solo aparece cuando el server expone la
/// allowlist (estado Loaded con modelos); elegir "Por defecto" regresa al
/// modelo de la plataforma (el turno viaja sin `model`). La elección vive en
/// el estado del bloc — por sesión de pantalla, no se persiste.
class TrainerModelMenu extends StatelessWidget {
  const TrainerModelMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrainerChatBloc, TrainerChatState>(
      builder: (context, state) {
        if (state is! TrainerChatLoaded || state.models.isEmpty) {
          return const SizedBox.shrink();
        }
        final selected = state.selectedModelId;
        return PopupMenuButton<String>(
          key: const Key('trainer.model.button'),
          tooltip: 'Modelo del entrenador',
          icon: Icon(
            Icons.psychology_outlined,
            color: selected.isEmpty ? null : AppTokens.primary,
          ),
          onSelected: (id) =>
              context.read<TrainerChatBloc>().add(TrainerChatModelSelected(id)),
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            CheckedPopupMenuItem<String>(
              key: const Key('trainer.model.option.default'),
              value: '',
              checked: selected.isEmpty,
              child: const Text('Por defecto'),
            ),
            for (final m in state.models)
              CheckedPopupMenuItem<String>(
                key: Key('trainer.model.option.${m.id}'),
                value: m.id,
                checked: selected == m.id,
                child: Text(
                  m.id == state.defaultModelId
                      ? '${m.label} (por defecto)'
                      : m.label,
                ),
              ),
          ],
        );
      },
    );
  }
}
