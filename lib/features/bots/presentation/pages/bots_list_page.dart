import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_avatar.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/bot.dart';
import '../bloc/bots_bloc.dart';

/// Listado de Bots (S04). Consume el BotsBloc del scope; el cableado del
/// provider lo hace el shell. Es content-only: el Scaffold y el AppBar los
/// aporta el ShellPage, que también orquesta el título dinámico por tab.
class BotsListPage extends StatelessWidget {
  const BotsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BotsBloc, BotsState>(
      builder: (context, state) => switch (state) {
        BotsInitial() || BotsLoading() => const _LoadingView(),
        BotsLoaded(items: final items) => _LoadedView(items: items),
        BotsFailed() => const _FailedView(),
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
    ),
  );
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.sp4,
                vertical: AppTokens.sp4,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTokens.cardGap),
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
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, c) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(
              key: const Key('bots.empty'),
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.sp6),
                child: Text(
                  'Todavía no tienes bots aquí',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge,
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
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('bots.error'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'No pudimos cargar tus bots',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () =>
                  context.read<BotsBloc>().add(const BotsLoadRequested()),
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
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      // push (no go): el detalle se apila sobre el listado para que el
      // back físico y la flecha del AppBar vuelvan al shell con la tab
      // Bots activa. Ver narrativa del fix en templates_list_page.
      onTap: () => context.push('/bots/${bot.id}'),
      child: Row(
        children: <Widget>[
          AppAvatar(name: bot.name),
          const SizedBox(width: AppTokens.sp4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(bot.name, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  _channelLabel(bot.channel),
                  style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.sp3),
          _StatusPill(paused: bot.paused),
        ],
      ),
    );
  }

  static String _channelLabel(BotChannel c) => switch (c) {
    BotChannel.waUnofficial => 'WhatsApp',
    BotChannel.waba => 'WhatsApp Business',
  };
}

/// Pill de estado del bot. paused → neutral con dot gris;
/// activo → primary con dot verde. La pill verbaliza el estado al
/// operador (mejor que el icono pause_circle previo, que no decía nada
/// sobre los bots no pausados).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context) {
    if (paused) {
      return const AppPill.neutral(label: 'Pausado', dot: AppPillDot.paused);
    }
    return const AppPill.primary(label: 'Activo', dot: AppPillDot.active);
  }
}
