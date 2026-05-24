import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/bot.dart';
import '../../domain/failures/bots_failure.dart';
import '../bloc/bot_detail_bloc.dart';

/// Detalle de un Bot (S04). Consume el `BotDetailBloc` del scope; el
/// cableado del provider y del ID lo hace el router en `/bots/:id`. Es
/// content-only: el Scaffold y el AppBar los aporta la ruta, igual que
/// en el listado para mantener consistencia con el shell.
class BotDetailPage extends StatelessWidget {
  const BotDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BotDetailBloc, BotDetailState>(
      builder: (context, state) => switch (state) {
        BotDetailLoading() => const _LoadingView(),
        BotDetailLoaded(bot: final bot) => _LoadedView(bot: bot),
        BotDetailFailed(failure: final f) => _FailedView(failure: f),
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.bot});

  final Bot bot;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(radius: 32, child: Text(_initial(bot.name))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      bot.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(_channelLabel(bot.channel)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Chip(label: Text('v${bot.version}')),
              if (bot.paused)
                const Chip(
                  avatar: Icon(Icons.pause_circle, size: 18),
                  label: Text('En pausa'),
                ),
              if (bot.aiDisabled)
                const Chip(
                  avatar: Icon(Icons.psychology_alt_outlined, size: 18),
                  label: Text('IA deshabilitada'),
                ),
            ],
          ),
          if (bot.identifier != null) ...<Widget>[
            const SizedBox(height: 24),
            const Text('Identificador'),
            const SizedBox(height: 4),
            SelectableText(
              bot.identifier!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  static String _initial(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  // Duplicado intencional con BotsListPage._BotTile._channelLabel: regla
  // de 3 — al tercer consumidor extraer a un helper compartido en
  // `core/bots/` o similar (hoy no aplica, son dos lugares).
  static String _channelLabel(BotChannel c) => switch (c) {
    BotChannel.waUnofficial => 'WhatsApp',
    BotChannel.waba => 'WhatsApp Business',
  };
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final BotsFailure failure;

  @override
  Widget build(BuildContext context) {
    final isNotFound = failure is BotsNotFoundFailure;
    return Center(
      key: isNotFound
          ? const Key('bot_detail.error.not_found')
          : const Key('bot_detail.error.generic'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              isNotFound
                  ? 'Este bot ya no existe en tu organización'
                  : 'No pudimos cargar el detalle del bot',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.read<BotDetailBloc>().add(
                const BotDetailLoadRequested(),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
