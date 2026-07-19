import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/network/sse/reconnecting_stream.dart';
import '../../../../core/network/sse/sse_parser.dart';
import '../../domain/entities/inbox_live_event.dart';

abstract interface class ConversationsEventsDatasource {
  Stream<InboxLiveEvent> liveEvents();
}

class DioConversationsEventsDatasource
    implements ConversationsEventsDatasource {
  DioConversationsEventsDatasource(this._dio);

  final Dio _dio;

  static const Set<String> _topics = <String>{
    'message.inbound',
    'message.outbound',
    'label.assigned',
    'label.removed',
    'ai.failed',
    'flow.failed',
    'agent.alert',
  };

  @override
  Stream<InboxLiveEvent> liveEvents() => reconnectingStream<InboxLiveEvent>(
    connectOnce,
    reconnectMarker: InboxReconnected.new,
  );

  Stream<InboxLiveEvent> connectOnce() async* {
    final cancel = CancelToken();
    try {
      final response = await _dio.get<ResponseBody>(
        '/inbox/events',
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero,
          headers: const <String, String>{'Accept': 'text/event-stream'},
        ),
      );
      final body = response.data;
      if (body == null) return;
      await for (final event in decodeSseEvents(body.stream)) {
        if (!_topics.contains(event.event)) continue;
        final parsed = _tryParse(event.event, event.data);
        if (parsed != null) yield parsed;
      }
    } finally {
      cancel.cancel();
    }
  }

  InboxInvalidated? _tryParse(String topic, String data) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) return null;
      final botId = json['botId'];
      final chatLid = json['chatLid'];
      final attention = json['needsAttention'];
      if (botId is! String ||
          botId.isEmpty ||
          chatLid is! String ||
          chatLid.isEmpty ||
          (attention != null && attention is! bool)) {
        return null;
      }
      return InboxInvalidated(
        topic: topic,
        botId: botId,
        chatLid: chatLid,
        needsAttention: (attention as bool?) ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}
