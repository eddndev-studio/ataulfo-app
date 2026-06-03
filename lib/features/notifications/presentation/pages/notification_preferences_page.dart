import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_switch.dart';
import '../../domain/entities/notification_preference.dart';
import '../bloc/notification_preferences_bloc.dart';

class NotificationPreferencesPage extends StatelessWidget {
  const NotificationPreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<
      NotificationPreferencesBloc,
      NotificationPreferencesState
    >(
      builder: (context, state) {
        return switch (state) {
          NotificationPreferencesInitial() ||
          NotificationPreferencesLoading() => const _PreferencesLoading(),
          NotificationPreferencesLoaded(:final preferences, :final saving) =>
            _PreferencesList(preferences: preferences, saving: saving),
          NotificationPreferencesFailed() => const _PreferencesError(),
        };
      },
    );
  }
}

class _PreferencesLoading extends StatelessWidget {
  const _PreferencesLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('notification_preferences.loading'),
      child: CircularProgressIndicator(),
    );
  }
}

class _PreferencesList extends StatelessWidget {
  const _PreferencesList({required this.preferences, required this.saving});

  final List<NotificationPreference> preferences;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    if (preferences.isEmpty) {
      return const Center(
        key: Key('notification_preferences.empty'),
        child: Text(
          'Sin preferencias configuradas',
          style: TextStyle(color: AppTokens.text2),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppTokens.sp6),
      itemBuilder: (context, index) {
        final pref = preferences[index];
        return AppCard(
          key: Key('notification_preferences.item.${pref.eventType.wire}'),
          child: Row(
            children: <Widget>[
              Icon(_iconFor(pref.eventType), color: AppTokens.primary),
              const SizedBox(width: AppTokens.sp4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _labelFor(pref.eventType),
                      style: const TextStyle(
                        color: AppTokens.text1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppTokens.sp2),
                    Text(
                      _descriptionFor(pref),
                      style: const TextStyle(color: AppTokens.text2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.sp4),
              AppSwitch(
                value: pref.enabled,
                onChanged: saving
                    ? null
                    : (enabled) =>
                          context.read<NotificationPreferencesBloc>().add(
                            NotificationPreferenceToggled(
                              pref.eventType,
                              enabled,
                            ),
                          ),
              ),
            ],
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: AppTokens.cardGap),
      itemCount: preferences.length,
    );
  }

  static IconData _iconFor(NotificationEventType type) {
    return switch (type) {
      NotificationEventType.messageInboundNew => Icons.chat_bubble_outline,
      NotificationEventType.botDisconnected => Icons.link_off_outlined,
      NotificationEventType.flowFailed => Icons.error_outline,
    };
  }

  static String _labelFor(NotificationEventType type) {
    return switch (type) {
      NotificationEventType.messageInboundNew => 'Mensajes nuevos',
      NotificationEventType.botDisconnected => 'Bot desconectado',
      NotificationEventType.flowFailed => 'Flujos fallidos',
    };
  }

  static String _descriptionFor(NotificationPreference pref) {
    final priority = switch (pref.priority) {
      NotificationPriority.low => 'baja',
      NotificationPriority.normal => 'normal',
      NotificationPriority.high => 'alta',
    };
    return 'Prioridad $priority';
  }
}

class _PreferencesError extends StatelessWidget {
  const _PreferencesError();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('notification_preferences.error'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'No se pudieron cargar las preferencias',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp4),
            AppButton.tonal(
              label: 'Reintentar',
              icon: Icons.refresh,
              onPressed: () => context.read<NotificationPreferencesBloc>().add(
                const NotificationPreferencesLoadRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
