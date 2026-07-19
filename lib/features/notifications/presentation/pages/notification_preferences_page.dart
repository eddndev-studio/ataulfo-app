import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_toggle_row.dart';
import '../../domain/entities/notification_preference.dart';
import '../bloc/notification_preferences_bloc.dart';

class NotificationPreferencesPage extends StatelessWidget {
  const NotificationPreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<
      NotificationPreferencesBloc,
      NotificationPreferencesState
    >(
      listener: (context, state) {
        if (state is NotificationPreferencesSaveFailed) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'No pudimos guardar tu preferencia. Intenta de nuevo.',
                ),
              ),
            );
        }
      },
      builder: (context, state) {
        return switch (state) {
          NotificationPreferencesInitial() ||
          NotificationPreferencesLoading() => const _PreferencesLoading(),
          NotificationPreferencesLoaded(:final preferences, :final saving) =>
            _PreferencesList(preferences: preferences, saving: saving),
          // Tras un fallo de guardado la lista sigue viva con las prefs
          // originales (el switch ya se ve revertido); el SnackBar avisa.
          NotificationPreferencesSaveFailed(:final preferences) =>
            _PreferencesList(preferences: preferences, saving: false),
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
    return const AppLoadingIndicator(
      key: Key('notification_preferences.loading'),
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
      return Center(
        key: const Key('notification_preferences.empty'),
        child: Text(
          'Sin preferencias configuradas',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
        ),
      );
    }

    // Anatomía canónica de ajustes: UNA card para la sección, con una fila de
    // toggle por preferencia separada por hairlines. Sin glifo leading: en una
    // fila de toggle el ícono no aporta acción ni identidad.
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6 + context.safeBottomInset,
      ),
      children: <Widget>[
        AppCard(
          key: const Key('notification_preferences.card'),
          child: Column(
            children: <Widget>[
              for (var i = 0; i < preferences.length; i++) ...<Widget>[
                if (i > 0)
                  const Divider(
                    height: AppTokens.sp5,
                    color: AppTokens.divider,
                  ),
                _PreferenceRow(preference: preferences[i], saving: saving),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Toggle de una preferencia sobre [AppToggleRow] del kit; la mutación se
/// despacha al bloc y `saving` inhabilita el switch mientras hay un PUT en
/// vuelo.
class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({required this.preference, required this.saving});

  final NotificationPreference preference;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final wire = preference.eventType.wire;
    return AppToggleRow(
      key: Key('notification_preferences.item.$wire'),
      switchKey: Key('notification_preferences.switch.$wire'),
      label: _labelFor(preference.eventType),
      caption: _descriptionFor(preference),
      value: preference.enabled,
      onChanged: saving
          ? null
          : (enabled) => context.read<NotificationPreferencesBloc>().add(
              NotificationPreferenceToggled(preference.eventType, enabled),
            ),
    );
  }

  static String _labelFor(NotificationEventType type) {
    return switch (type) {
      NotificationEventType.messageInboundNew => 'Mensajes nuevos',
      NotificationEventType.botDisconnected => 'Canal desconectado',
      NotificationEventType.flowFailed => 'Flujos fallidos',
      NotificationEventType.agentAlert => 'Alertas del Asistente',
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
            Text(
              'No se pudieron cargar las preferencias',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
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
