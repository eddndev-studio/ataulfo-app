import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_empty_state.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../bots/domain/entities/bot.dart';
import '../../../bots/presentation/bloc/bots_bloc.dart';
import '../../../bots/presentation/widgets/bot_create_sheet.dart';
import '../../../bots/presentation/widgets/bot_tile.dart';
import '../../domain/entities/template.dart';
import '../bloc/template_detail_bloc.dart';

class AssistantChannelsPage extends StatelessWidget {
  const AssistantChannelsPage({super.key, required this.assistantId});

  final String assistantId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TemplateDetailBloc, TemplateDetailState>(
      builder: (context, templateState) {
        final template = switch (templateState) {
          TemplateDetailLoaded(template: final value) => value,
          TemplateDetailMutating(template: final value) => value,
          TemplateDetailMutationFailed(template: final value) => value,
          _ => null,
        };
        return Scaffold(
          appBar: AppBar(title: const Text('Canales')),
          floatingActionButton: template == null
              ? null
              : FloatingActionButton.extended(
                  key: const Key('assistant_channels.add'),
                  onPressed: () => _create(context, template),
                  icon: const Icon(Icons.add),
                  label: const Text('Conectar canal'),
                ),
          body: template == null
              ? switch (templateState) {
                  TemplateDetailFailed() => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTokens.sp5),
                      child: AppErrorState(
                        message: 'No pudimos cargar este Asistente.',
                        onRetry: () => context.read<TemplateDetailBloc>().add(
                          const TemplateDetailLoadRequested(),
                        ),
                      ),
                    ),
                  ),
                  _ => const AppLoadingIndicator(label: 'Cargando Asistente…'),
                }
              : _Channels(assistantId: assistantId, template: template),
        );
      },
    );
  }

  Future<void> _create(BuildContext context, Template template) async {
    final bot = await BotCreateSheet.open(context, template: template);
    if (bot == null || !context.mounted) return;
    context.read<BotsBloc>().add(const BotsRefreshRequested());
    unawaited(context.push('/bots/${bot.id}'));
  }
}

class _Channels extends StatelessWidget {
  const _Channels({required this.assistantId, required this.template});

  final String assistantId;
  final Template template;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BotsBloc, BotsState>(
      builder: (context, state) => switch (state) {
        BotsInitial() ||
        BotsLoading() => const AppLoadingIndicator(label: 'Cargando canales…'),
        BotsFailed() => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.sp5),
            child: AppErrorState(
              message: 'No pudimos cargar los canales.',
              onRetry: () =>
                  context.read<BotsBloc>().add(const BotsLoadRequested()),
            ),
          ),
        ),
        BotsLoaded(items: final items) => _LoadedChannels(
          assistantName: template.name,
          channels: items
              .where((bot) => bot.templateId == assistantId)
              .toList(),
          onRefresh: () async {
            final bloc = context.read<BotsBloc>();
            bloc.add(const BotsRefreshRequested());
            await bloc.stream.firstWhere(
              (next) =>
                  (next is BotsLoaded && !next.isRefreshing) ||
                  next is BotsFailed,
            );
          },
        ),
      },
    );
  }
}

class _LoadedChannels extends StatelessWidget {
  const _LoadedChannels({
    required this.assistantName,
    required this.channels,
    required this.onRefresh,
  });

  final String assistantName;
  final List<Bot> channels;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp5,
          AppTokens.sp4,
          AppTokens.sp5,
          AppTokens.fabClearance + context.safeBottomInset,
        ),
        children: <Widget>[
          Text(assistantName, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppTokens.sp1),
          Text(
            'Cada canal es una conexión donde este Asistente conversa. El comportamiento y los recursos se comparten.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp5),
          if (channels.isEmpty)
            const AppEmptyState(
              icon: Icons.cable_outlined,
              title: 'Aún no hay canales conectados',
              description:
                  'Puedes preparar y probar el Asistente antes de conectarlo '
                  'a WhatsApp.',
            )
          else
            AppCard(
              child: Column(
                children: <Widget>[
                  for (
                    var index = 0;
                    index < channels.length;
                    index++
                  ) ...<Widget>[
                    if (index > 0)
                      const Divider(
                        height: AppTokens.sp4,
                        color: AppTokens.divider,
                      ),
                    BotTile(
                      key: Key('assistant_channels.row.${channels[index].id}'),
                      bot: channels[index],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
