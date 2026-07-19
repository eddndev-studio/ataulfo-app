part of 'conversations_bloc.dart';

/// Reconciles the server page with Drift without leaking transport concerns
/// into the BLoC event handlers.
///
/// A fresh REST row wins until Drift echoes the same value. From that point on,
/// local optimistic mutations win again. The connected-channel catalogue is an
/// additional live boundary for both cached and remote rows.
class _ConversationsProjection {
  final Map<String, Conversation> _cacheByKey = <String, Conversation>{};
  final Map<String, Conversation> _remoteByKey = <String, Conversation>{};
  final List<String> _remoteKeys = <String>[];
  final Set<String> _pendingCacheSyncKeys = <String>{};

  Set<String>? _validBotIds;
  Set<String>? _validLabelIds;
  var _hasAuthority = false;

  bool get hasAuthority => _hasAuthority;

  void replaceRemote(List<Conversation> items) {
    _hasAuthority = true;
    _remoteKeys
      ..clear()
      ..addAll(_deduplicatedKeys(items));
    _remoteByKey
      ..clear()
      ..addEntries(items.map((item) => MapEntry(item.stableKey, item)));
    _pendingCacheSyncKeys
      ..clear()
      ..addAll(
        items
            .where((item) => _cacheByKey[item.stableKey] != item)
            .map((item) => item.stableKey),
      );
  }

  void appendRemote(List<Conversation> items) {
    _hasAuthority = true;
    for (final item in items) {
      _remoteByKey[item.stableKey] = item;
      if (_cacheByKey[item.stableKey] == item) {
        _pendingCacheSyncKeys.remove(item.stableKey);
      } else {
        _pendingCacheSyncKeys.add(item.stableKey);
      }
      if (!_remoteKeys.contains(item.stableKey)) {
        _remoteKeys.add(item.stableKey);
      }
    }
  }

  void replaceCache(List<Conversation> items) {
    _cacheByKey
      ..clear()
      ..addEntries(items.map((item) => MapEntry(item.stableKey, item)));
    _pendingCacheSyncKeys.removeWhere(
      (key) => _cacheByKey[key] == _remoteByKey[key],
    );
  }

  void setValidBotIds(Set<String> botIds) {
    _validBotIds = Set<String>.unmodifiable(botIds);
  }

  void setValidLabelIds(Set<String> labelIds) {
    _validLabelIds = Set<String>.unmodifiable(labelIds);
  }

  void clearRemote() {
    _hasAuthority = false;
    _remoteKeys.clear();
    _remoteByKey.clear();
    _pendingCacheSyncKeys.clear();
  }

  void revokeAccess() {
    clearRemote();
    _cacheByKey.clear();
  }

  List<Conversation> visible(InboxQuery query) {
    if (!_hasAuthority) return localVisible(query);
    final items = <Conversation>[];
    for (final key in _remoteKeys) {
      final item = _pendingCacheSyncKeys.contains(key)
          ? _remoteByKey[key] ?? _cacheByKey[key]
          : _cacheByKey[key] ?? _remoteByKey[key];
      if (item != null && _hasValidChannel(item)) {
        final projected = _withValidLabels(item);
        if (query.matches(projected)) items.add(projected);
      }
    }
    return items;
  }

  List<Conversation> localVisible(InboxQuery query) {
    final items = _cacheByKey.values
        .map(_withValidLabels)
        .where((item) => _hasValidChannel(item) && query.matches(item))
        .toList();
    items.sort(compareInboxConversations);
    return items;
  }

  bool _hasValidChannel(Conversation item) {
    final validBotIds = _validBotIds;
    return validBotIds == null || validBotIds.contains(item.botId);
  }

  Conversation _withValidLabels(Conversation item) {
    final validLabelIds = _validLabelIds;
    if (validLabelIds == null) return item;
    final labels = item.labels
        .where((label) => validLabelIds.contains(label.id))
        .toList(growable: false);
    return labels.length == item.labels.length ? item : item.withLabels(labels);
  }

  static List<String> _deduplicatedKeys(List<Conversation> items) {
    final seen = <String>{};
    return <String>[
      for (final item in items)
        if (seen.add(item.stableKey)) item.stableKey,
    ];
  }
}
