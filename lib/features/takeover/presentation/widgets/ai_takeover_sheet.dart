import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../bots/domain/repositories/bots_repository.dart';
import '../../../labels/domain/repositories/chat_labels_repository.dart';
import '../../../templates/domain/repositories/templates_repository.dart';
import '../../data/repo_silence_labels_resolver.dart';
import '../cubit/ai_takeover_cubit.dart';

/// Hoja de "control del bot en este chat": muestra si el bot está pausado aquí
/// (tiene una etiqueta de silencio aplicada) y permite pausarlo/reanudarlo. Se
/// abre desde el app bar del hilo (solo ADMIN+). Compone, desde el scope, el
/// repo de etiquetas por chat y el resolver de etiquetas de silencio del bot.
class AiTakeoverSheet extends StatelessWidget {
  const AiTakeoverSheet({super.key});

  static Future<void> open(
    BuildContext context, {
    required String botId,
    required String chatLid,
  }) {
    final chatLabels = context.read<ChatLabelsRepository>();
    final resolver = RepoSilenceLabelsResolver(
      bots: context.read<BotsRepository>(),
      templates: context.read<TemplatesRepository>(),
    );
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTokens.surface1,
      builder: (_) => BlocProvider<AiTakeoverCubit>(
        create: (_) =>
            AiTakeoverCubit(
              resolver: resolver,
              chatLabels: chatLabels,
              botId: botId,
              chatLid: chatLid,
            )..load(),
        child: const AiTakeoverSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: BlocConsumer<AiTakeoverCubit, AiTakeoverState>(
        listenWhen: (prev, curr) =>
            curr is AiTakeoverReady && curr.actionFailed,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo cambiar el estado del bot.'),
            ),
          );
        },
        builder: (context, state) => Padding(
          key: const Key('takeover.sheet'),
          padding: const EdgeInsets.all(AppTokens.sp5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Control del bot en este chat', style: textTheme.titleMedium),
              const SizedBox(height: AppTokens.sp4),
              switch (state) {
                AiTakeoverLoading() => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppTokens.sp4),
                    child: CircularProgressIndicator(),
                  ),
                ),
                AiTakeoverError() => Text(
                  'No se pudo cargar el estado del bot.',
                  key: const Key('takeover.error'),
                  style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
                ),
                AiTakeoverReady(:final configured, :final paused, :final busy) =>
                  _ready(context, textTheme, configured, paused, busy),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _ready(
    BuildContext context,
    TextTheme textTheme,
    bool configured,
    bool paused,
    bool busy,
  ) {
    if (!configured) {
      return Text(
        'Este bot no tiene una etiqueta de silencio configurada. Define una en '
        'la plantilla para poder pausarlo en un chat.',
        key: const Key('takeover.not_configured'),
        style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              paused ? Icons.pause_circle_outline : Icons.smart_toy_outlined,
              color: paused ? AppTokens.text2 : AppTokens.primary,
            ),
            const SizedBox(width: AppTokens.sp2),
            Expanded(
              child: Text(
                paused
                    ? 'El bot está pausado en este chat.'
                    : 'El bot está respondiendo en este chat.',
                key: const Key('takeover.state'),
                style: textTheme.bodyLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.sp4),
        AppButton.filled(
          key: const Key('takeover.toggle'),
          label: paused ? 'Reanudar bot' : 'Pausar bot aquí',
          onPressed: busy
              ? null
              : () => context.read<AiTakeoverCubit>().toggle(),
          fullWidth: true,
        ),
      ],
    );
  }
}
