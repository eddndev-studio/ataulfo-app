import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/notification_inbox_item.dart';
import '../../domain/failures/notifications_failure.dart';
import '../../domain/repositories/notifications_repository.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  NotificationsBloc(this.repo) : super(const NotificationsInitial()) {
    on<NotificationsLoadRequested>(_onLoad);
    on<NotificationMarkReadRequested>(_onMarkRead);
    on<NotificationsMarkAllReadRequested>(_onMarkAllRead);
  }

  final NotificationsRepository repo;

  Future<void> _onLoad(
    NotificationsLoadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(const NotificationsLoading());
    try {
      final items = await repo.listInbox(unreadOnly: true);
      emit(NotificationsLoaded(items: items));
    } on NotificationsFailure catch (f) {
      emit(NotificationsFailed(f));
    }
  }

  Future<void> _onMarkRead(
    NotificationMarkReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    final current = state;
    if (current is! NotificationsLoaded) return;
    final next = current.items
        .where((item) => item.id != event.id)
        .toList(growable: false);
    emit(NotificationsLoaded(items: next));
    try {
      await repo.markRead(event.id);
    } on NotificationsFailure {
      emit(current);
    }
  }

  Future<void> _onMarkAllRead(
    NotificationsMarkAllReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    final current = state;
    if (current is! NotificationsLoaded) return;
    emit(const NotificationsLoaded(items: <NotificationInboxItem>[]));
    try {
      await repo.markAllRead();
    } on NotificationsFailure {
      emit(current);
    }
  }
}

sealed class NotificationsEvent {
  const NotificationsEvent();
}

class NotificationsLoadRequested extends NotificationsEvent {
  const NotificationsLoadRequested();

  @override
  bool operator ==(Object other) => other is NotificationsLoadRequested;
  @override
  int get hashCode => (NotificationsLoadRequested).hashCode;
}

class NotificationMarkReadRequested extends NotificationsEvent {
  const NotificationMarkReadRequested(this.id);

  final String id;

  @override
  bool operator ==(Object other) =>
      other is NotificationMarkReadRequested && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class NotificationsMarkAllReadRequested extends NotificationsEvent {
  const NotificationsMarkAllReadRequested();

  @override
  bool operator ==(Object other) => other is NotificationsMarkAllReadRequested;
  @override
  int get hashCode => (NotificationsMarkAllReadRequested).hashCode;
}

sealed class NotificationsState {
  const NotificationsState();
}

class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
  @override
  bool operator ==(Object other) => other is NotificationsInitial;
  @override
  int get hashCode => (NotificationsInitial).hashCode;
}

class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
  @override
  bool operator ==(Object other) => other is NotificationsLoading;
  @override
  int get hashCode => (NotificationsLoading).hashCode;
}

class NotificationsLoaded extends NotificationsState {
  const NotificationsLoaded({required this.items});

  final List<NotificationInboxItem> items;

  @override
  bool operator ==(Object other) {
    if (other is! NotificationsLoaded) return false;
    if (other.items.length != items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (other.items[i] != items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(items);
}

class NotificationsFailed extends NotificationsState {
  const NotificationsFailed(this.failure);

  final NotificationsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is NotificationsFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
