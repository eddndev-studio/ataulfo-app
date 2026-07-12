import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_thread_list_sheet.dart';
import '../../../messages/presentation/widgets/audio_failures_listener.dart';
import '../../domain/failures/trainer_failure.dart';
import '../bloc/trainer_chat_bloc.dart';
import '../widgets/trainer_chat_view.dart';
import '../widgets/trainer_failure_copy.dart';
import '../widgets/trainer_model_menu.dart';

// El copy de fallos vive en widgets/trainer_failure_copy.dart; se reexporta
// aquí para los consumidores históricos (workspace/preview) sin romper rutas.
export '../widgets/trainer_failure_copy.dart' show trainerFailureCopy;

/// Chat con el agente entrenador de la plantilla. El turno es síncrono:
/// mientras viaja se muestra la traza viva y el composer queda bloqueado. El
/// hilo persistido se agrupa por turnos, con las tarjetas ricas (diffs,
/// inspect_flow, historial, errores) como cuerpos de los nodos de su traza.
class TrainerChatPage extends StatelessWidget {
  const TrainerChatPage({required this.templateId, super.key});

  final String templateId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrenador'),
        actions: <Widget>[
          const TrainerModelMenu(),
          IconButton(
            key: const Key('trainer.workspace'),
            tooltip: 'Workspace del negocio',
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: () =>
                context.push('/templates/$templateId/trainer/workspace'),
          ),
          IconButton(
            key: const Key('trainer.preview'),
            tooltip: 'Probar bot',
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () =>
                context.push('/templates/$templateId/trainer/preview'),
          ),
          IconButton(
            key: const Key('trainer.threads'),
            tooltip: 'Conversaciones',
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => _showThreads(context),
          ),
          IconButton(
            key: const Key('trainer.new_conversation'),
            tooltip: 'Nueva conversación',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => context.read<TrainerChatBloc>().add(
              const TrainerChatNewConversationRequested(),
            ),
          ),
        ],
      ),
      // El aviso de audio irreproducible cubre todo el hilo: cualquier burbuja
      // de audio sin fuente (adjunto de otro dispositivo) lo dispara.
      body: AudioFailuresListener(
        child: BlocBuilder<TrainerChatBloc, TrainerChatState>(
          builder: (context, state) => switch (state) {
            TrainerChatLoading() => const AppLoadingIndicator(),
            TrainerChatFailed(:final failure) => _FailedView(failure: failure),
            TrainerChatLoaded() => TrainerChatView(state: state),
          },
        ),
      ),
    );
  }

  /// Abre el selector de hilos compartido. Sin menú por hilo: el entrenador no
  /// expone renombrar/eliminar conversaciones. Tocar un hilo lo activa y cierra
  /// el cajón.
  void _showThreads(BuildContext context) {
    final bloc = context.read<TrainerChatBloc>();
    final state = bloc.state;
    if (state is! TrainerChatLoaded) return;
    showAppBottomSheet<void>(
      context,
      builder: (sheetCtx) => AppThreadListSheet(
        keyPrefix: 'trainer.threads',
        title: 'Conversaciones',
        activeId: state.conversation.id,
        items: <AppThreadListItem>[
          for (final c in state.conversations)
            AppThreadListItem(id: c.id, title: c.title),
        ],
        onSelect: (id) {
          Navigator.of(sheetCtx).pop();
          bloc.add(TrainerChatConversationSelected(id));
        },
      ),
    );
  }
}

/// Fallo de la carga inicial: copy por tipo sobre el estado de error del kit.
class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final TrainerFailure failure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: AppErrorState(
          message: trainerFailureCopy(failure),
          onRetry: () =>
              context.read<TrainerChatBloc>().add(const TrainerChatStarted()),
        ),
      ),
    );
  }
}
