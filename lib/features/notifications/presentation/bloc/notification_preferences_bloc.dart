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
      emit(current);
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

class NotificationPreferencesFailed extends NotificationPreferencesState {
  const NotificationPreferencesFailed(this.failure);

  final NotificationsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferencesFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
