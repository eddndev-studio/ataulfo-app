import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../bots/domain/entities/bot.dart';
import '../../../bots/presentation/bloc/bots_bloc.dart';
import '../../../bots/presentation/widgets/bot_create_sheet.dart';
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
                  TemplateDetailFailed() => _TemplateFailed(
                    onRetry: () => context.read<TemplateDetailBloc>().add(
                      const TemplateDetailLoadRequested(),
                    ),
                  ),
                  _ => const Center(child: CircularProgressIndicator()),
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
        BotsInitial() || BotsLoading() => const _ChannelsSkeleton(),
        BotsFailed() => _ChannelsFailed(
          onRetry: () =>
              context.read<BotsBloc>().add(const BotsLoadRequested()),
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
            AppCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTokens.sp5),
                child: Column(
                  children: <Widget>[
                    const Icon(
                      Icons.cable_outlined,
                      size: 40,
                      color: AppTokens.text2,
                    ),
                    const SizedBox(height: AppTokens.sp3),
                    Text(
                      'Aún no hay canales conectados',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTokens.sp1),
                    Text(
                      'Puedes preparar y probar el Asistente antes de conectarlo a WhatsApp.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppTokens.text2),
                    ),
                  ],
                ),
              ),
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
                    _ChannelRow(channel: channels[index]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.channel});

  final Bot channel;

  @override
  Widget build(BuildContext context) {
    final state = channel.paused ? 'Pausado' : 'Activo';
    final provider = switch (channel.channel) {
      BotChannel.waUnofficial => 'WhatsApp',
      BotChannel.waba => 'WhatsApp Business',
    };
    return InkWell(
      key: Key('assistant_channels.row.${channel.id}'),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      onTap: () => context.push('/bots/${channel.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp2),
        child: Row(
          children: <Widget>[
            const Icon(Icons.cable_outlined, color: AppTokens.text2),
            const SizedBox(width: AppTokens.sp3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    channel.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$provider · $state',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTokens.text2),
                  ),
                ],
              ),
            ),
            Icon(
              channel.paused
                  ? Icons.pause_circle_outline
                  : Icons.check_circle_outline,
              color: channel.paused ? AppTokens.warning : AppTokens.success,
            ),
            const SizedBox(width: AppTokens.sp1),
            const Icon(Icons.chevron_right, color: AppTokens.text2),
          ],
        ),
      ),
    );
  }
}

class _ChannelsSkeleton extends StatelessWidget {
  const _ChannelsSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppTokens.sp5),
    children: <Widget>[
      for (final height in <double>[72, 72, 72]) ...<Widget>[
        Container(
          height: height,
          decoration: BoxDecoration(
            color: AppTokens.surface1,
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          ),
        ),
        const SizedBox(height: AppTokens.sp3),
      ],
    ],
  );
}

class _ChannelsFailed extends StatelessWidget {
  const _ChannelsFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: AppButton.tonal(label: 'Reintentar', onPressed: onRetry),
  );
}

class _TemplateFailed extends StatelessWidget {
  const _TemplateFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppTokens.sp5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('No pudimos cargar este Asistente.'),
          const SizedBox(height: AppTokens.sp3),
          AppButton.tonal(label: 'Reintentar', onPressed: onRetry),
        ],
      ),
    ),
  );
}
