import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/bot.dart';
import '../bloc/bots_bloc.dart';

/// Listado de Bots (S04). Consume el BotsBloc del scope; el cableado del
/// provider lo hace el shell. La página es presentación pura — todas las
/// transiciones de estado pasan por el bloc.
class BotsListPage extends StatelessWidget {
  const BotsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bots')),
      body: BlocBuilder<BotsBloc, BotsState>(
        builder: (context, state) => switch (state) {
          BotsInitial() || BotsLoading() => const _LoadingView(),
          BotsLoaded(items: final items) => _LoadedView(items: items),
          BotsFailed() => const _FailedView(),
        },
      ),
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
  const _LoadedView({required this.items});

  final List<Bot> items;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final bloc = context.read<BotsBloc>();
        bloc.add(const BotsRefreshRequested());
        // Esperamos a que el bloc deje el estado refreshing (o caiga a
        // Failed). Sin este await el RefreshIndicator quita el spinner
        // antes de tiempo y la animación parpadea.
        await bloc.stream.firstWhere(
          (s) => (s is BotsLoaded && !s.isRefreshing) || s is BotsFailed,
        );
      },
      child: items.isEmpty
          ? const _EmptyView()
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => _BotTile(bot: items[i]),
            ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    // ListView de un solo hijo expandido = el RefreshIndicator sigue
    // funcionando porque el viewport es scrollable aunque la lista esté
    // vacía. Sin esto, AlwaysScrollableScrollPhysics no alcanza para que
    // el operador pueda jalar a refrescar sobre el empty state.
    return LayoutBuilder(
      builder: (context, c) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: const Center(
              key: Key('bots.empty'),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no tienes bots aquí',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView();

  @override
  Widget build(BuildContext context) {
    // Mensaje único + retry: la diferencia entre red/forbidden/server/unknown
    // se nombrará cuando producto pida copy fino. Por hoy: el operador ve
    // que falló y puede reintentar.
    return Center(
      key: const Key('bots.error'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'No pudimos cargar tus bots',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  context.read<BotsBloc>().add(const BotsLoadRequested()),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotTile extends StatelessWidget {
  const _BotTile({required this.bot});

  final Bot bot;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(_initial(bot.name))),
      title: Text(bot.name),
      subtitle: Text(_channelLabel(bot.channel)),
      trailing: bot.paused
          ? const Icon(Icons.pause_circle, semanticLabel: 'En pausa')
          : null,
    );
  }

  static String _initial(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  static String _channelLabel(BotChannel c) => switch (c) {
    BotChannel.waUnofficial => 'WhatsApp',
    BotChannel.waba => 'WhatsApp Business',
  };
}
