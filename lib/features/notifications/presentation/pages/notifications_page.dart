import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_empty_state.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../domain/entities/notification_inbox_item.dart';
import '../bloc/notifications_bloc.dart';
import '../widgets/notification_inbox_tile.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsBloc, NotificationsState>(
      builder: (context, state) {
        return switch (state) {
          NotificationsInitial() ||
          NotificationsLoading() => const _NotificationsLoading(),
          NotificationsLoaded(:final items) =>
            items.isEmpty
                ? const _NotificationsEmpty()
                : _NotificationsList(items: items),
          NotificationsFailed() => const _NotificationsError(),
        };
      },
    );
  }
}

class _NotificationsLoading extends StatelessWidget {
  const _NotificationsLoading();

  @override
  Widget build(BuildContext context) {
    return const AppLoadingIndicator(key: Key('notifications.loading'));
  }
}

class _NotificationsList extends StatelessWidget {
  const _NotificationsList({required this.items});

  final List<NotificationInboxItem> items;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        // Reusa la carga; el Loading intermedio es el costo honesto de no
        // tener un refresh incremental en el bloc.
        context.read<NotificationsBloc>().add(
          const NotificationsLoadRequested(),
        );
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp6,
          AppTokens.sp6,
          AppTokens.sp6,
          AppTokens.sp6 + context.safeBottomInset,
        ),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Wrap(
              alignment: WrapAlignment.end,
              spacing: AppTokens.sp3,
              runSpacing: AppTokens.sp3,
              children: <Widget>[
                const _PreferencesButton(),
                AppButton.tonal(
                  label: 'Marcar todo leído',
                  icon: Icons.done_all_outlined,
                  onPressed: () => context.read<NotificationsBloc>().add(
                    const NotificationsMarkAllReadRequested(),
                  ),
                ),
              ],
            );
          }
          final item = items[index - 1];
          // Key estable por id: el estado de expansión del tile sigue al ítem,
          // no a su posición, cuando la lista se recompone (p. ej. al marcar
          // otro como leído).
          return NotificationInboxTile(key: ValueKey(item.id), item: item);
        },
        separatorBuilder: (_, _) => const SizedBox(height: AppTokens.cardGap),
        itemCount: items.length + 1,
      ),
    );
  }
}

class _NotificationsEmpty extends StatelessWidget {
  const _NotificationsEmpty();

  @override
  Widget build(BuildContext context) {
    // El vacío también se refresca: el gesto necesita un scrollable vivo
    // aunque no haya lista (AppEmptyState no aporta scroll). Preferencias no
    // es un CTA del vacío (vive fuera de la card, como acción secundaria).
    return RefreshIndicator(
      onRefresh: () async {
        context.read<NotificationsBloc>().add(
          const NotificationsLoadRequested(),
        );
      },
      child: LayoutBuilder(
        builder: (context, c) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppTokens.sp5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AppEmptyState(
                        key: Key('notifications.empty'),
                        icon: Icons.notifications_none,
                        title: 'Sin notificaciones pendientes',
                      ),
                      SizedBox(height: AppTokens.sp4),
                      _PreferencesButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferencesButton extends StatelessWidget {
  const _PreferencesButton();

  @override
  Widget build(BuildContext context) {
    return AppButton.tonal(
      label: 'Preferencias',
      icon: Icons.tune,
      onPressed: () => context.push('/notification-preferences'),
    );
  }
}

class _NotificationsError extends StatelessWidget {
  const _NotificationsError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp5),
        child: AppErrorState(
          key: const Key('notifications.error'),
          message: 'No se pudieron cargar las notificaciones',
          onRetry: () => context.read<NotificationsBloc>().add(
            const NotificationsLoadRequested(),
          ),
        ),
      ),
    );
  }
}
