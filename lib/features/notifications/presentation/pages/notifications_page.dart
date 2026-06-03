import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../domain/entities/notification_inbox_item.dart';
import '../../domain/entities/notification_preference.dart';
import '../bloc/notifications_bloc.dart';

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
    return ListView.separated(
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
        return _NotificationItem(item: item);
      },
      separatorBuilder: (_, _) => const SizedBox(height: AppTokens.cardGap),
      itemCount: items.length + 1,
    );
  }
}

class _NotificationItem extends StatelessWidget {
  const _NotificationItem({required this.item});

  final NotificationInboxItem item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: Key('notifications.item.${item.id}'),
      onTap: () => context.read<NotificationsBloc>().add(
        NotificationMarkReadRequested(item.id),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(_iconFor(item.eventType), color: _colorFor(item.priority)),
          const SizedBox(width: AppTokens.sp4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppTokens.text1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppTokens.sp2),
                Text(item.body, style: const TextStyle(color: AppTokens.text2)),
                if (item.count > 1) ...<Widget>[
                  const SizedBox(height: AppTokens.sp3),
                  Text(
                    '${item.count} eventos',
                    style: const TextStyle(color: AppTokens.textDisabled),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTokens.text2),
        ],
      ),
    );
  }

  static IconData _iconFor(NotificationEventType type) {
    return switch (type) {
      NotificationEventType.messageInboundNew => Icons.chat_bubble_outline,
      NotificationEventType.botDisconnected => Icons.link_off_outlined,
      NotificationEventType.flowFailed => Icons.error_outline,
    };
  }

  static Color _colorFor(NotificationPriority priority) {
    return switch (priority) {
      NotificationPriority.low => AppTokens.success,
      NotificationPriority.normal => AppTokens.primary,
      NotificationPriority.high => AppTokens.danger,
    };
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
