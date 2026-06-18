import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
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
    return const Center(
      key: Key('notifications.loading'),
      child: CircularProgressIndicator(),
    );
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
        padding: const EdgeInsets.all(AppTokens.sp6),
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
    return const Center(
      key: Key('notifications.empty'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Sin notificaciones pendientes',
            style: TextStyle(color: AppTokens.text2),
          ),
          SizedBox(height: AppTokens.sp4),
          _PreferencesButton(),
        ],
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
      key: const Key('notifications.error'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'No se pudieron cargar las notificaciones',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp4),
            AppButton.tonal(
              label: 'Reintentar',
              icon: Icons.refresh,
              onPressed: () => context.read<NotificationsBloc>().add(
                const NotificationsLoadRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
