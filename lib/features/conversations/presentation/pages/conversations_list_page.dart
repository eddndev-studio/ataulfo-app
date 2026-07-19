import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/role_privilege.dart';
import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/widgets/app_header_card.dart';
import '../../../../core/util/user_greeting.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../bots/domain/entities/bot.dart';
import '../../../bots/presentation/bloc/bots_bloc.dart';
import '../../../labels/domain/entities/label.dart';
import '../../../labels/domain/repositories/chat_labels_repository.dart';
import '../../../labels/presentation/bloc/labels_admin_bloc.dart';
import '../../../messages/domain/repositories/messages_repository.dart';
import '../../application/inbox_bulk_actions.dart';
import '../../domain/entities/conversation.dart';
import '../bloc/conversations_bloc.dart';
import '../bloc/inbox_selection_cubit.dart';
import '../widgets/inbox_label_action_sheet.dart';
import '../widgets/inbox_ready_view.dart';
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
  late final InboxSelectionCubit _selection;
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
    _selection = InboxSelectionCubit(
      actions: InboxBulkActions(
        messages: context.read<MessagesRepository>(),
        chatLabels: context.read<ChatLabelsRepository>(),
      ),
    );
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
    _selection.close();
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

  void _toggleSelection(Conversation conversation) {
    if (_selection.toggle(conversation)) return;
    if (!_selection.state.isMutating &&
        _selection.state.count == InboxSelectionCubit.maxSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Puedes seleccionar hasta 50 conversaciones'),
        ),
      );
    }
  }

  Future<void> _editLabels() async {
    final action = await InboxLabelActionSheet.open(
      context,
      labels: _visibleLabels,
    );
    if (!mounted || action == null) return;
    await switch (action.mutation) {
      InboxLabelMutation.add => _selection.addLabel(action.labelId),
      InboxLabelMutation.remove => _selection.removeLabel(action.labelId),
    };
  }

  Future<void> _confirmClearHistory() async {
    final count = _selection.state.count;
    if (count == 0) return;
    final singular = count == 1;
    final noun = singular ? 'conversación' : 'conversaciones';
    final confirmed = await showAppConfirmDialog(
      context,
      title: '¿Vaciar el historial de $count $noun?',
      message:
          'Se eliminarán permanentemente los mensajes de $count $noun. '
          'Se conservarán el contacto, la sesión y sus etiquetas. Esta acción '
          'no se puede deshacer.',
      confirmLabel: 'Vaciar historial',
      confirmKey: const Key('inbox.clear_history.confirm'),
      cancelKey: const Key('inbox.clear_history.cancel'),
    );
    if (confirmed && mounted) await _selection.clearHistory();
  }

  void _onBulkResult(InboxBulkResult result) {
    context.read<ConversationsBloc>().add(
      const ConversationsRefreshRequested(),
    );
    final suffix = result.failedCount == 0
        ? ''
        : ' · ${result.failedCount} con error permanecen seleccionadas';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${result.succeededCount} de ${result.attemptedCount} '
          'conversaciones actualizadas$suffix',
        ),
      ),
    );
  }

  bool _canClearHistory() {
    final auth = context.read<AuthBloc>().state;
    return auth is AuthAuthenticated && isAdminOrAbove(auth.identity.role);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<InboxSelectionCubit>.value(
      value: _selection,
      child: MultiBlocListener(
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
            listenWhen: (before, after) => before.query != after.query,
            listener: (_, state) {
              if (_searchController.text != state.query.search) {
                _searchController.text = state.query.search;
              }
              _selection.clear();
            },
          ),
          BlocListener<ConversationsBloc, ConversationsState>(
            listenWhen: (before, after) => before.items != after.items,
            listener: (_, state) => _selection.reconcileVisible(state.items),
          ),
          BlocListener<InboxSelectionCubit, InboxSelectionState>(
            listenWhen: (before, after) =>
                before.lastResult != after.lastResult &&
                after.lastResult != null,
            listener: (_, state) => _onBulkResult(state.lastResult!),
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
            ConversationsPhase.ready =>
              BlocBuilder<InboxSelectionCubit, InboxSelectionState>(
                builder: (context, selection) => RefreshIndicator(
                  onRefresh: _refresh,
                  child: InboxReadyView(
                    header: _header(context),
                    state: state,
                    selection: selection,
                    bots: _visibleBots,
                    labels: _visibleLabels,
                    searchController: _searchController,
                    scrollController: _scrollController,
                    selectedConversationKey: _selectedConversationKey,
                    canClearHistory: _canClearHistory(),
                    onOpenConversation: _openConversation,
                    onToggleSelection: _toggleSelection,
                    onClearSelection: _selection.clear,
                    onOpenLabels: _editLabels,
                    onMarkRead: _selection.markRead,
                    onClearHistory: _confirmClearHistory,
                    onQueryChanged: _selection.clear,
                    onClearFilters: () {
                      _selection.clear();
                      _searchController.clear();
                      context.read<ConversationsBloc>().add(
                        const ConversationsFiltersCleared(),
                      );
                    },
                  ),
                ),
              ),
          },
        ),
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
