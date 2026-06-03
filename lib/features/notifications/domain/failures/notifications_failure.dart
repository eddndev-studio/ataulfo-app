sealed class NotificationsFailure implements Exception {
  const NotificationsFailure();
}

class NotificationsNetworkFailure extends NotificationsFailure {
  const NotificationsNetworkFailure();
  @override
  bool operator ==(Object other) => other is NotificationsNetworkFailure;
  @override
  int get hashCode => (NotificationsNetworkFailure).hashCode;
}

class NotificationsTimeoutFailure extends NotificationsFailure {
  const NotificationsTimeoutFailure();
  @override
  bool operator ==(Object other) => other is NotificationsTimeoutFailure;
  @override
  int get hashCode => (NotificationsTimeoutFailure).hashCode;
}

class NotificationsForbiddenFailure extends NotificationsFailure {
  const NotificationsForbiddenFailure();
  @override
  bool operator ==(Object other) => other is NotificationsForbiddenFailure;
  @override
  int get hashCode => (NotificationsForbiddenFailure).hashCode;
}

class NotificationsInvalidFailure extends NotificationsFailure {
  const NotificationsInvalidFailure();
  @override
  bool operator ==(Object other) => other is NotificationsInvalidFailure;
  @override
  int get hashCode => (NotificationsInvalidFailure).hashCode;
}

class NotificationsServerFailure extends NotificationsFailure {
  const NotificationsServerFailure();
  @override
  bool operator ==(Object other) => other is NotificationsServerFailure;
  @override
  int get hashCode => (NotificationsServerFailure).hashCode;
}

class UnknownNotificationsFailure extends NotificationsFailure {
  const UnknownNotificationsFailure();
  @override
  bool operator ==(Object other) => other is UnknownNotificationsFailure;
  @override
  int get hashCode => (UnknownNotificationsFailure).hashCode;
}
