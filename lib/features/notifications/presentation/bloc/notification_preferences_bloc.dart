import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/notification_preference.dart';
import '../../domain/failures/notifications_failure.dart';
import '../../domain/repositories/notifications_repository.dart';

class NotificationPreferencesBloc
    extends Bloc<NotificationPreferencesEvent, NotificationPreferencesState> {
  NotificationPreferencesBloc(this.repo)
    : super(const NotificationPreferencesInitial()) {
    on<NotificationPreferencesLoadRequested>(_onLoad);
    on<NotificationPreferenceToggled>(_onToggle);
  }

  final NotificationsRepository repo;

  Future<void> _onLoad(
    NotificationPreferencesLoadRequested event,
    Emitter<NotificationPreferencesState> emit,
  ) async {
    emit(const NotificationPreferencesLoading());
    try {
      final preferences = await repo.listPreferences();
      emit(NotificationPreferencesLoaded(preferences: preferences));
    } on NotificationsFailure catch (f) {
      emit(NotificationPreferencesFailed(f));
    }
  }

  Future<void> _onToggle(
    NotificationPreferenceToggled event,
    Emitter<NotificationPreferencesState> emit,
  ) async {
    final current = state;
    if (current is! NotificationPreferencesLoaded) return;

    final updated = current.preferences
        .map(
          (pref) => pref.eventType == event.eventType
              ? pref.copyWith(enabled: event.enabled)
              : pref,
        )
        .toList(growable: false);

    emit(NotificationPreferencesLoaded(preferences: updated, saving: true));
    try {
      final saved = await repo.savePreferences(updated);
      emit(NotificationPreferencesLoaded(preferences: saved));
    } on NotificationsFailure {
      // Revertir al snapshot Y señalizarlo: la página avisa con un SnackBar
      // en vez de dejar que el switch "se devuelva solo" sin explicación.
      emit(NotificationPreferencesSaveFailed(preferences: current.preferences));
    }
  }
}

sealed class NotificationPreferencesEvent {
  const NotificationPreferencesEvent();
}

class NotificationPreferencesLoadRequested
    extends NotificationPreferencesEvent {
  const NotificationPreferencesLoadRequested();

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferencesLoadRequested;
  @override
  int get hashCode => (NotificationPreferencesLoadRequested).hashCode;
}

class NotificationPreferenceToggled extends NotificationPreferencesEvent {
  const NotificationPreferenceToggled(this.eventType, this.enabled);

  final NotificationEventType eventType;
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferenceToggled &&
      other.eventType == eventType &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(eventType, enabled);
}

sealed class NotificationPreferencesState {
  const NotificationPreferencesState();
}

class NotificationPreferencesInitial extends NotificationPreferencesState {
  const NotificationPreferencesInitial();

  @override
  bool operator ==(Object other) => other is NotificationPreferencesInitial;
  @override
  int get hashCode => (NotificationPreferencesInitial).hashCode;
}

class NotificationPreferencesLoading extends NotificationPreferencesState {
  const NotificationPreferencesLoading();

  @override
  bool operator ==(Object other) => other is NotificationPreferencesLoading;
  @override
  int get hashCode => (NotificationPreferencesLoading).hashCode;
}

class NotificationPreferencesLoaded extends NotificationPreferencesState {
  const NotificationPreferencesLoaded({
    required this.preferences,
    this.saving = false,
  });

  final List<NotificationPreference> preferences;
  final bool saving;

  @override
  bool operator ==(Object other) {
    if (other is! NotificationPreferencesLoaded) return false;
    if (other.saving != saving) return false;
    if (other.preferences.length != preferences.length) return false;
    for (var i = 0; i < preferences.length; i++) {
      if (other.preferences[i] != preferences[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(preferences), saving);
}

/// El guardado de un toggle falló: conserva las preferencias ORIGINALES para
/// que la lista siga renderizada (switch revertido) mientras la página
/// anuncia el fallo. Distinto de [NotificationPreferencesFailed], que es el
/// fallo terminal de la CARGA (sin lista que preservar).
class NotificationPreferencesSaveFailed extends NotificationPreferencesState {
  const NotificationPreferencesSaveFailed({required this.preferences});

  final List<NotificationPreference> preferences;

  @override
  bool operator ==(Object other) {
    if (other is! NotificationPreferencesSaveFailed) return false;
    if (other.preferences.length != preferences.length) return false;
    for (var i = 0; i < preferences.length; i++) {
      if (other.preferences[i] != preferences[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(preferences);
}

class NotificationPreferencesFailed extends NotificationPreferencesState {
  const NotificationPreferencesFailed(this.failure);

  final NotificationsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferencesFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
