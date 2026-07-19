import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_empty_state.dart';
import '../../../../core/design/widgets/app_notice_banner.dart';
import '../../../bots/domain/entities/bot.dart';
import '../../../labels/domain/entities/label.dart';
import '../../domain/entities/conversation.dart';
import '../bloc/conversations_bloc.dart';
import '../bloc/inbox_selection_cubit.dart';
import 'inbox_bulk_action_bar.dart';
import 'inbox_conversation_row.dart';
import 'inbox_filters.dart';

class InboxReadyView extends StatelessWidget {
  const InboxReadyView({
    super.key,
    required this.header,
    required this.state,
    required this.selection,
    required this.bots,
    required this.labels,
    required this.searchController,
    required this.scrollController,
    required this.selectedConversationKey,
    required this.canClearHistory,
    required this.onOpenConversation,
    required this.onToggleSelection,
    required this.onClearSelection,
    required this.onOpenLabels,
    required this.onMarkRead,
    required this.onClearHistory,
    required this.onQueryChanged,
    required this.onClearFilters,
  });

  final Widget header;
  final ConversationsState state;
  final InboxSelectionState selection;
  final List<Bot> bots;
  final List<Label> labels;
  final TextEditingController searchController;
  final ScrollController scrollController;
  final String? selectedConversationKey;
  final bool canClearHistory;
  final ValueChanged<Conversation> onOpenConversation;
  final ValueChanged<Conversation> onToggleSelection;
  final VoidCallback onClearSelection;
  final VoidCallback onOpenLabels;
  final VoidCallback onMarkRead;
  final VoidCallback onClearHistory;
  final VoidCallback onQueryChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ConversationsBloc>();
    final items = state.items;
    final selectionMode = selection.count > 0;
    final desktop = MediaQuery.sizeOf(context).width >= 720;
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
            child: selectionMode
                ? InboxBulkActionBar(
                    count: selection.count,
                    isMutating: selection.isMutating,
                    canClearHistory: canClearHistory,
                    onCancel: onClearSelection,
                    onLabels: onOpenLabels,
                    onMarkRead: onMarkRead,
                    onClearHistory: onClearHistory,
                  )
                : InboxFilters(
                    query: state.query,
                    bots: bots,
                    labels: labels,
                    searchController: searchController,
                    onSearchChanged: (value) {
                      onQueryChanged();
                      bloc.add(ConversationsSearchChanged(value));
                    },
                    onStatusChanged: (value) {
                      onQueryChanged();
                      bloc.add(ConversationsStatusChanged(value));
                    },
                    onChannelChanged: (value) {
                      onQueryChanged();
                      bloc.add(ConversationsChannelChanged(value));
                    },
                    onLabelToggled: (value) {
                      onQueryChanged();
                      bloc.add(ConversationsLabelToggled(value));
                    },
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
              final checked = selection.contains(conversation);
              return InboxConversationRow(
                conversation: conversation,
                selected: selectedConversationKey == conversation.stableKey,
                multiSelected: checked,
                showSelectionControl: desktop || selectionMode,
                onSelectionChanged: (_) => onToggleSelection(conversation),
                onLongPress: () => onToggleSelection(conversation),
                onTap: () => selectionMode
                    ? onToggleSelection(conversation)
                    : onOpenConversation(conversation),
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
