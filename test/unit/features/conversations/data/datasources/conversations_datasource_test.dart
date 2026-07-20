import 'package:ataulfo/features/conversations/data/datasources/conversations_datasource.dart';
import 'package:ataulfo/features/conversations/domain/entities/inbox_query.dart';
import 'package:ataulfo/features/conversations/domain/failures/conversations_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Map<String, dynamic> itemJson() => <String, dynamic>{
  'bot_id': 'bot-1',
  'chat_lid': 'lid-1',
  'kind': 'DM',
  'is_archived': false,
  'is_pinned': false,
  'is_marked_unread': false,
  'unread_count': 0,
  'needs_attention': false,
  'assistant_id': 'assistant-1',
  'assistant_name': 'Ventas regionales',
  'channel_name': 'Ventas Guatemala',
  'channel_type': 'WA_UNOFFICIAL',
  'labels': <dynamic>[],
};

void main() {
  late _MockDio dio;
  late DioConversationsDatasource datasource;

  setUp(() {
    dio = _MockDio();
    datasource = DioConversationsDatasource(dio);
  });

  Response<Map<String, dynamic>> response(Map<String, dynamic>? body) =>
      Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/inbox/conversations'),
        statusCode: 200,
        data: body,
      );

  test('consulta una sola página org-scoped con una etiqueta', () async {
    const path =
        '/inbox/conversations?q=rivera&status=attention&botId=bot-1'
        '&labelId=vip&cursor=opaque%2Bcursor&limit=40';
    when(() => dio.get<Map<String, dynamic>>(path)).thenAnswer(
      (_) async => response(<String, dynamic>{
        'items': <Map<String, dynamic>>[itemJson()],
        'next_cursor': 'next',
      }),
    );

    final page = await datasource.list(
      const InboxQuery(
        search: ' rivera ',
        status: InboxStatus.attention,
        botId: 'bot-1',
        labelId: 'vip',
        cursor: 'opaque+cursor',
      ),
    );

    expect(page.items.single.botId, 'bot-1');
    expect(page.nextCursor, 'next');
    verify(() => dio.get<Map<String, dynamic>>(path)).called(1);
    verifyNoMoreInteractions(dio);
  });

  test('consulta mínima siempre envía estado y límite', () async {
    const path = '/inbox/conversations?status=all&limit=40';
    when(() => dio.get<Map<String, dynamic>>(path)).thenAnswer(
      (_) async => response(<String, dynamic>{'items': <dynamic>[]}),
    );

    final page = await datasource.list(const InboxQuery());

    expect(page.items, isEmpty);
    expect(page.nextCursor, isNull);
  });

  test('422 de filtro o cursor → ConversationsInvalidQueryFailure', () async {
    const path = '/inbox/conversations?status=all&limit=40';
    when(() => dio.get<Map<String, dynamic>>(path)).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: path),
        response: Response<void>(
          requestOptions: RequestOptions(path: path),
          statusCode: 422,
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    await expectLater(
      datasource.list(const InboxQuery()),
      throwsA(isA<ConversationsInvalidQueryFailure>()),
    );
  });

  test('403 → ConversationsForbiddenFailure', () async {
    const path = '/inbox/conversations?status=all&limit=40';
    when(() => dio.get<Map<String, dynamic>>(path)).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: path),
        response: Response<void>(
          requestOptions: RequestOptions(path: path),
          statusCode: 403,
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    await expectLater(
      datasource.list(const InboxQuery()),
      throwsA(isA<ConversationsForbiddenFailure>()),
    );
  });

  test('body nulo o malformado → UnknownConversationsFailure', () async {
    const path = '/inbox/conversations?status=all&limit=40';
    when(
      () => dio.get<Map<String, dynamic>>(path),
    ).thenAnswer((_) async => response(null));

    await expectLater(
      datasource.list(const InboxQuery()),
      throwsA(isA<UnknownConversationsFailure>()),
    );
  });
}
