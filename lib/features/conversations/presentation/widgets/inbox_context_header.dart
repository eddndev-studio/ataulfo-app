import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';

/// Chrome fijo y compacto de la Bandeja. Conserva una sola altura y cambia de
/// contenido —no de geometría— al entrar en selección múltiple.
class InboxContextHeader extends StatelessWidget {
  const InboxContextHeader({
    super.key,
    required this.selectionActive,
    required this.selectedCount,
    required this.isMutating,
    required this.canStartSelection,
    required this.canSelectVisible,
    required this.canClearHistory,
    required this.showingArchived,
    required this.hasActiveFilters,
    required this.onStartSelection,
    required this.onCancelSelection,
    required this.onSelectVisible,
    required this.onOpenLabels,
    required this.onMarkRead,
    required this.onClearHistory,
    required this.onToggleArchived,
    required this.onRefresh,
    required this.onClearFilters,
    this.onManageLabels,
    this.onOpenSettings,
    this.leading,
    this.actions = const <Widget>[],
  });

  final bool selectionActive;
  final int selectedCount;
  final bool isMutating;
  final bool canStartSelection;
  final bool canSelectVisible;
  final bool canClearHistory;
  final bool showingArchived;
  final bool hasActiveFilters;
  final VoidCallback onStartSelection;
  final VoidCallback onCancelSelection;
  final VoidCallback onSelectVisible;
  final VoidCallback onOpenLabels;
  final VoidCallback onMarkRead;
  final VoidCallback onClearHistory;
  final VoidCallback onToggleArchived;
  final VoidCallback onRefresh;
  final VoidCallback onClearFilters;
  final VoidCallback? onManageLabels;
  final VoidCallback? onOpenSettings;
  final Widget? leading;
  final List<Widget> actions;

  static const double _toolbarHeight = 56;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('inbox.header'),
      color: AppTokens.surface1,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: _toolbarHeight + 2,
          child: Column(
            children: <Widget>[
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppTokens.durationBase,
                  switchInCurve: AppTokens.ease,
                  switchOutCurve: AppTokens.ease,
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      for (final child in previousChildren)
                        IgnorePointer(child: ExcludeSemantics(child: child)),
                      ?currentChild,
                    ],
                  ),
                  child: selectionActive
                      ? _SelectionHeader(
                          key: const ValueKey<String>('selection'),
                          count: selectedCount,
                          isMutating: isMutating,
                          canSelectVisible: canSelectVisible,
                          canClearHistory: canClearHistory,
                          onCancel: onCancelSelection,
                          onSelectVisible: onSelectVisible,
                          onLabels: onOpenLabels,
                          onMarkRead: onMarkRead,
                          onClearHistory: onClearHistory,
                        )
                      : _NormalHeader(
                          key: const ValueKey<String>('normal'),
                          canStartSelection: canStartSelection,
                          showingArchived: showingArchived,
                          hasActiveFilters: hasActiveFilters,
                          onStartSelection: onStartSelection,
                          onToggleArchived: onToggleArchived,
                          onRefresh: onRefresh,
                          onClearFilters: onClearFilters,
                          onManageLabels: onManageLabels,
                          onOpenSettings: onOpenSettings,
                          leading: leading,
                          actions: actions,
                        ),
                ),
              ),
              SizedBox(
                height: 2,
                child: AnimatedSwitcher(
                  duration: AppTokens.durationFast,
                  child: isMutating
                      ? const LinearProgressIndicator(
                          key: Key('inbox.selection.progress'),
                          minHeight: 2,
                          color: AppTokens.primary,
                          backgroundColor: AppTokens.surface1,
                        )
                      : const ColoredBox(
                          key: ValueKey<String>('inbox.header.divider'),
                          color: AppTokens.divider,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _InboxMenuAction {
  startSelection,
  toggleArchived,
  refresh,
  clearFilters,
  manageLabels,
  settings,
}

class _NormalHeader extends StatelessWidget {
  const _NormalHeader({
    super.key,
    required this.canStartSelection,
    required this.showingArchived,
    required this.hasActiveFilters,
    required this.onStartSelection,
    required this.onToggleArchived,
    required this.onRefresh,
    required this.onClearFilters,
    required this.onManageLabels,
    required this.onOpenSettings,
    required this.leading,
    required this.actions,
  });

  final bool canStartSelection;
  final bool showingArchived;
  final bool hasActiveFilters;
  final VoidCallback onStartSelection;
  final VoidCallback onToggleArchived;
  final VoidCallback onRefresh;
  final VoidCallback onClearFilters;
  final VoidCallback? onManageLabels;
  final VoidCallback? onOpenSettings;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: const Key('inbox.header.normal'),
      child: Row(
        children: <Widget>[
          ?leading,
          if (leading == null)
            const SizedBox(width: AppTokens.sp4)
          else
            const SizedBox(width: AppTokens.sp1),
          Expanded(
            child: Text(
              'Bandeja',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ...actions,
          PopupMenuButton<_InboxMenuAction>(
            key: const Key('inbox.header.more'),
            tooltip: 'Más acciones',
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              switch (action) {
                case _InboxMenuAction.startSelection:
                  onStartSelection();
                case _InboxMenuAction.toggleArchived:
                  onToggleArchived();
                case _InboxMenuAction.refresh:
                  onRefresh();
                case _InboxMenuAction.clearFilters:
                  onClearFilters();
                case _InboxMenuAction.manageLabels:
                  onManageLabels?.call();
                case _InboxMenuAction.settings:
                  onOpenSettings?.call();
              }
            },
            itemBuilder: (_) => <PopupMenuEntry<_InboxMenuAction>>[
              PopupMenuItem<_InboxMenuAction>(
                key: const Key('inbox.header.menu.select'),
                value: _InboxMenuAction.startSelection,
                enabled: canStartSelection,
                child: const _MenuRow(
                  icon: Icons.checklist_outlined,
                  label: 'Seleccionar conversaciones',
                ),
              ),
              PopupMenuItem<_InboxMenuAction>(
                key: const Key('inbox.header.menu.archived'),
                value: _InboxMenuAction.toggleArchived,
                child: _MenuRow(
                  icon: showingArchived
                      ? Icons.inbox_outlined
                      : Icons.archive_outlined,
                  label: showingArchived ? 'Volver a todas' : 'Ver archivadas',
                ),
              ),
              const PopupMenuItem<_InboxMenuAction>(
                key: Key('inbox.header.menu.refresh'),
                value: _InboxMenuAction.refresh,
                child: _MenuRow(
                  icon: Icons.refresh,
                  label: 'Actualizar bandeja',
                ),
              ),
              if (hasActiveFilters)
                const PopupMenuItem<_InboxMenuAction>(
                  key: Key('inbox.header.menu.clear_filters'),
                  value: _InboxMenuAction.clearFilters,
                  child: _MenuRow(
                    icon: Icons.filter_alt_off_outlined,
                    label: 'Limpiar filtros',
                  ),
                ),
              if (onManageLabels != null) ...<PopupMenuEntry<_InboxMenuAction>>[
                const PopupMenuDivider(),
                const PopupMenuItem<_InboxMenuAction>(
                  key: Key('inbox.header.menu.manage_labels'),
                  value: _InboxMenuAction.manageLabels,
                  child: _MenuRow(
                    icon: Icons.label_outline,
                    label: 'Gestionar etiquetas',
                  ),
                ),
              ],
              if (onOpenSettings != null) ...<PopupMenuEntry<_InboxMenuAction>>[
                if (onManageLabels == null) const PopupMenuDivider(),
                const PopupMenuItem<_InboxMenuAction>(
                  key: Key('inbox.header.menu.settings'),
                  value: _InboxMenuAction.settings,
                  child: _MenuRow(
                    icon: Icons.settings_outlined,
                    label: 'Ajustes',
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: AppTokens.sp1),
        ],
      ),
    );
  }
}

enum _SelectionMenuAction { markRead, selectVisible }

class _SelectionHeader extends StatelessWidget {
  const _SelectionHeader({
    super.key,
    required this.count,
    required this.isMutating,
    required this.canSelectVisible,
    required this.canClearHistory,
    required this.onCancel,
    required this.onSelectVisible,
    required this.onLabels,
    required this.onMarkRead,
    required this.onClearHistory,
  });

  final int count;
  final bool isMutating;
  final bool canSelectVisible;
  final bool canClearHistory;
  final VoidCallback onCancel;
  final VoidCallback onSelectVisible;
  final VoidCallback onLabels;
  final VoidCallback onMarkRead;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) {
    final canMutate = count > 0 && !isMutating;
    final countLabel = count == 1
        ? '1 conversación seleccionada'
        : '$count conversaciones seleccionadas';
    return Semantics(
      key: const Key('inbox.selection.bar'),
      container: true,
      liveRegion: true,
      label: countLabel,
      child: SizedBox.expand(
        child: Row(
          children: <Widget>[
            IconButton(
              key: const Key('inbox.selection.cancel'),
              tooltip: 'Cancelar selección',
              onPressed: isMutating ? null : onCancel,
              icon: const Icon(Icons.close),
            ),
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  '$count',
                  key: const Key('inbox.selection.count'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              key: const Key('inbox.selection.labels'),
              tooltip: 'Editar etiquetas',
              onPressed: canMutate ? onLabels : null,
              icon: const Icon(Icons.label_outline),
            ),
            if (canClearHistory)
              IconButton(
                key: const Key('inbox.selection.clear_history'),
                tooltip: 'Vaciar historial',
                color: AppTokens.danger,
                onPressed: canMutate ? onClearHistory : null,
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            PopupMenuButton<_SelectionMenuAction>(
              key: const Key('inbox.selection.more'),
              tooltip: 'Más acciones de selección',
              enabled: !isMutating && (count > 0 || canSelectVisible),
              icon: const Icon(Icons.more_vert),
              onSelected: (action) {
                switch (action) {
                  case _SelectionMenuAction.markRead:
                    onMarkRead();
                  case _SelectionMenuAction.selectVisible:
                    onSelectVisible();
                }
              },
              itemBuilder: (_) => <PopupMenuEntry<_SelectionMenuAction>>[
                PopupMenuItem<_SelectionMenuAction>(
                  key: const Key('inbox.selection.mark_read'),
                  value: _SelectionMenuAction.markRead,
                  enabled: count > 0,
                  child: const _MenuRow(
                    icon: Icons.done_all,
                    label: 'Marcar atendidas',
                  ),
                ),
                PopupMenuItem<_SelectionMenuAction>(
                  key: const Key('inbox.selection.select_visible'),
                  value: _SelectionMenuAction.selectVisible,
                  enabled: canSelectVisible,
                  child: const _MenuRow(
                    icon: Icons.select_all,
                    label: 'Seleccionar visibles',
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppTokens.sp1),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(icon, size: 20),
      const SizedBox(width: AppTokens.sp3),
      Expanded(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}
