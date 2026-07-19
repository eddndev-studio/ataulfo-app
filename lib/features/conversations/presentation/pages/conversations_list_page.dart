import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_empty_state.dart';
import '../../../../core/design/widgets/app_header_card.dart';
import '../../../../core/design/widgets/app_notice_banner.dart';
import '../../../../core/util/user_greeting.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../bots/domain/entities/bot.dart';
import '../../../bots/presentation/bloc/bots_bloc.dart';
import '../../../labels/domain/entities/label.dart';
import '../../../labels/presentation/bloc/labels_admin_bloc.dart';
import '../../domain/entities/conversation.dart';
import '../bloc/conversations_bloc.dart';
import '../widgets/inbox_conversation_row.dart';
import '../widgets/inbox_filters.dart';
import '../widgets/inbox_state_views.dart';

class ConversationsListPage extends StatefulWidget {
  const ConversationsListPage({super.key, this.onOpenSettings});

  final VoidCallback? onOpenSettings;

  @override
  State<ConversationsListPage> createState() => _ConversationsListPageState();
}

class _ConversationsListPageState extends State<ConversationsListPage> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  late List<Bot> _visibleBots;
  late List<Label> _visibleLabels;
  String? _selectedConversationKey;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<ConversationsBloc>().state.query.search,
    );
    _scrollController = ScrollController()..addListener(_onScroll);
    _visibleBots = _botsOf(context.read<BotsBloc>().state);
    _visibleLabels = _labelsOf(context.read<LabelsAdminBloc>().state);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reconcileFacets();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 280) {
      context.read<ConversationsBloc>().add(
        const ConversationsLoadMoreRequested(),
      );
    }
  }

  void _reconcileFacets() {
    final inbox = context.read<ConversationsBloc>();
    if (context.read<BotsBloc>().state case BotsLoaded(:final items)) {
      if (!identical(_visibleBots, items)) {
        setState(() => _visibleBots = items);
      }
      inbox.add(
        ConversationsValidChannelsChanged(items.map((bot) => bot.id).toSet()),
      );
    }
    switch (context.read<LabelsAdminBloc>().state) {
      case LabelsAdminLoaded(:final labels) ||
          LabelsAdminMutating(:final labels) ||
          LabelsAdminMutationFailed(:final labels):
        if (!identical(_visibleLabels, labels)) {
          setState(() => _visibleLabels = labels);
        }
        inbox.add(
          ConversationsValidLabelsChanged(
            labels.map((label) => label.id).toSet(),
          ),
        );
      case LabelsAdminLoading() || LabelsAdminFailed():
        break;
    }
  }

  Future<void> _refresh() async {
    final inbox = context.read<ConversationsBloc>();
    context.read<BotsBloc>().add(const BotsRefreshRequested());
    context.read<LabelsAdminBloc>().add(const LabelsAdminRefreshRequested());
    inbox.add(const ConversationsRefreshRequested());
    await inbox.stream.firstWhere(
      (state) =>
          !state.isRefreshing &&
          state.phase != ConversationsPhase.loading &&
          !state.isLoadingMore,
      orElse: () => inbox.state,
    );
  }

  Future<void> _openConversation(Conversation conversation) async {
    setState(() => _selectedConversationKey = conversation.stableKey);
    await context.push<void>(
      '/bots/${Uri.encodeComponent(conversation.botId)}/sessions/'
      '${Uri.encodeComponent(conversation.chatLid)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: <BlocListener<dynamic, dynamic>>[
        BlocListener<BotsBloc, BotsState>(
          listener: (_, state) {
            if (state is BotsLoaded) _reconcileFacets();
          },
        ),
        BlocListener<LabelsAdminBloc, LabelsAdminState>(
          listener: (_, state) {
            if (state is LabelsAdminLoaded) _reconcileFacets();
          },
        ),
        BlocListener<ConversationsBloc, ConversationsState>(
          listenWhen: (before, after) =>
              before.query.search != after.query.search,
          listener: (_, state) {
            if (_searchController.text != state.query.search) {
              _searchController.text = state.query.search;
            }
          },
        ),
      ],
      child: BlocBuilder<ConversationsBloc, ConversationsState>(
        builder: (context, state) => switch (state.phase) {
          ConversationsPhase.initial || ConversationsPhase.loading =>
            InboxLoadingView(header: _header(context)),
          ConversationsPhase.failure => InboxFailureView(
            header: _header(context),
            failure: state.failure,
          ),
          ConversationsPhase.ready => RefreshIndicator(
            onRefresh: _refresh,
            child: _ReadyInbox(
              header: _header(context),
              state: state,
              bots: _visibleBots,
              labels: _visibleLabels,
              searchController: _searchController,
              scrollController: _scrollController,
              selectedConversationKey: _selectedConversationKey,
              onOpenConversation: _openConversation,
              onClearFilters: () {
                _searchController.clear();
                context.read<ConversationsBloc>().add(
                  const ConversationsFiltersCleared(),
                );
              },
            ),
          ),
        },
      ),
    );
  }

  Widget _header(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final email = switch (auth) {
      AuthAuthenticated(:final identity) => identity.email,
      AuthAuthenticatedNoOrg(:final identity) => identity.email,
      _ => '',
    };
    final user = userGreeting(email);
    return AppHeaderCard(
      greeting: user.greeting,
      title: 'Bandeja',
      avatarInitial: user.initial,
      onAvatarTap: widget.onOpenSettings ?? () {},
      watermark: Icons.inbox_outlined,
    );
  }
}

class _ReadyInbox extends StatelessWidget {
  const _ReadyInbox({
    required this.header,
    required this.state,
    required this.bots,
    required this.labels,
    required this.searchController,
    required this.scrollController,
    required this.selectedConversationKey,
    required this.onOpenConversation,
    required this.onClearFilters,
  });

  final Widget header;
  final ConversationsState state;
  final List<Bot> bots;
  final List<Label> labels;
  final TextEditingController searchController;
  final ScrollController scrollController;
  final String? selectedConversationKey;
  final ValueChanged<Conversation> onOpenConversation;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ConversationsBloc>();
    final items = state.items;
    return CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverToBoxAdapter(child: header),
        if (state.isRefreshing)
          const SliverToBoxAdapter(
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppTokens.primary,
              backgroundColor: Colors.transparent,
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.sp4,
            AppTokens.sp5,
            AppTokens.sp4,
            AppTokens.sp4,
          ),
          sliver: SliverToBoxAdapter(
            child: InboxFilters(
              query: state.query,
              bots: bots,
              labels: labels,
              searchController: searchController,
              onSearchChanged: (value) =>
                  bloc.add(ConversationsSearchChanged(value)),
              onStatusChanged: (value) =>
                  bloc.add(ConversationsStatusChanged(value)),
              onChannelChanged: (value) =>
                  bloc.add(ConversationsChannelChanged(value)),
              onLabelToggled: (value) =>
                  bloc.add(ConversationsLabelToggled(value)),
            ),
          ),
        ),
        if (state.isOffline || state.failure != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.sp4,
              0,
              AppTokens.sp4,
              AppTokens.sp4,
            ),
            sliver: SliverToBoxAdapter(
              child: state.isOffline
                  ? const AppNoticeBanner.warning(
                      key: Key('inbox.offline'),
                      icon: Icons.cloud_off_outlined,
                      message:
                          'Estás sin conexión. Mostramos la última información guardada.',
                    )
                  : const AppNoticeBanner.danger(
                      key: Key('inbox.refresh_error'),
                      message:
                          'No pudimos actualizar la Bandeja. Desliza para reintentar.',
                    ),
            ),
          ),
        if (items.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.sp4,
              AppTokens.sp5,
              AppTokens.sp4,
              AppTokens.sp7,
            ),
            sliver: SliverToBoxAdapter(
              child: AppEmptyState(
                key: Key(
                  state.query.hasActiveFilters
                      ? 'inbox.empty.filtered'
                      : 'inbox.empty.initial',
                ),
                icon: state.query.hasActiveFilters
                    ? Icons.filter_alt_off_outlined
                    : Icons.forum_outlined,
                title: state.query.hasActiveFilters
                    ? 'No hay conversaciones con estos filtros'
                    : 'Aún no hay conversaciones en tu organización',
                description: state.query.hasActiveFilters
                    ? 'Prueba otra búsqueda, Canal, estado o combinación de etiquetas.'
                    : 'Cuando alguien escriba a un Canal conectado, aparecerá aquí.',
                ctaLabel: state.query.hasActiveFilters
                    ? 'Limpiar filtros'
                    : null,
                onCta: state.query.hasActiveFilters ? onClearFilters : null,
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index.isOdd) return const InboxConversationDivider();
              final conversation = items[index ~/ 2];
              return InboxConversationRow(
                conversation: conversation,
                selected: selectedConversationKey == conversation.stableKey,
                onTap: () => onOpenConversation(conversation),
              );
            }, childCount: items.length * 2 - 1),
          ),
        if (state.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppTokens.sp5),
              child: Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTokens.primary,
                  ),
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: AppTokens.sp5 + context.safeBottomInset),
        ),
      ],
    );
  }
}

List<Bot> _botsOf(BotsState state) => switch (state) {
  BotsLoaded(:final items) => items,
  _ => const <Bot>[],
};

List<Label> _labelsOf(LabelsAdminState state) => switch (state) {
  LabelsAdminLoaded(:final labels) ||
  LabelsAdminMutating(:final labels) ||
  LabelsAdminMutationFailed(:final labels) => labels,
  _ => const <Label>[],
};
