import 'package:ataulfo/features/resources/data/repositories/dio_resources_repository.dart';
import 'package:ataulfo/features/resources/domain/entities/resource_item.dart';
import 'package:ataulfo/features/resources/domain/repositories/resources_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Map<String, Object?> _resource({
  String id = 'r-1',
  String kind = 'knowledge_document',
}) => <String, Object?>{
  'id': id,
  'sourceId': 'source-$id',
  'kind': kind,
  'name': 'Manual',
  'active': true,
  'sharedByDefault': false,
  'indexable': true,
  'sendable': false,
  'version': 3,
};

Response<T> _response<T>(String path, T data) => Response<T>(
  requestOptions: RequestOptions(path: path),
  statusCode: 200,
  data: data,
);

DioException _badResponse(int status, {Object? data}) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  response: Response<Object?>(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: status,
    data: data,
  ),
  type: DioExceptionType.badResponse,
);

void main() {
  late _MockDio dio;
  late DioResourcesRepository repository;

  setUp(() {
    dio = _MockDio();
    repository = DioResourcesRepository(dio);
  });

  test('lista organizacional mapea manifiesto tipado y revisión', () async {
    when(() => dio.get<Object?>('/resources?active=true')).thenAnswer(
      (_) async => _response<Object?>('/resources', <String, Object?>{
        'revision': 9,
        'resources': <Object?>[
          _resource(),
          _resource(id: 'r-future', kind: 'future_kind'),
        ],
      }),
    );

    final snapshot = await repository.listOrganization();

    expect(snapshot.revision, 9);
    expect(snapshot.resources, hasLength(2));
    expect(snapshot.resources.first.kind, ResourceKind.knowledgeDocument);
    expect(snapshot.resources.last.kind, ResourceKind.unknown);
    expect(snapshot.scope, isNull);
  });

  test('lista efectiva exige y mapea política ALL/SELECTED', () async {
    when(
      () => dio.get<Object?>('/assistants/a-1/resources?active=true'),
    ).thenAnswer(
      (_) async =>
          _response<Object?>('/assistants/a-1/resources', <String, Object?>{
            'revision': 10,
            'resources': <Object?>[_resource()],
            'policy': <String, Object?>{'scopeMode': 'SELECTED'},
          }),
    );

    final snapshot = await repository.listForAssistant('a-1');

    expect(snapshot.scope, AssistantResourceScope.selected);
    expect(snapshot.resources.single.id, 'r-1');
  });

  test('setScope y bindings escapan IDs y usan el wire estable', () async {
    when(
      () => dio.put<void>(
        '/assistants/a%2Fb/resource-policy',
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async => _response<void>('/x', null));
    when(
      () => dio.put<void>('/assistants/a%2Fb/resources/r%20x'),
    ).thenAnswer((_) async => _response<void>('/x', null));
    when(
      () => dio.delete<void>('/assistants/a%2Fb/resources/r%20x'),
    ).thenAnswer((_) async => _response<void>('/x', null));

    await repository.setScope('a/b', AssistantResourceScope.selected);
    await repository.attach('a/b', 'r x');
    await repository.detach('a/b', 'r x');

    final body =
        verify(
              () => dio.put<void>(
                '/assistants/a%2Fb/resource-policy',
                data: captureAny(named: 'data'),
              ),
            ).captured.single
            as Map<String, Object?>;
    expect(body, <String, Object?>{'scopeMode': 'SELECTED'});
    verify(() => dio.put<void>('/assistants/a%2Fb/resources/r%20x')).called(1);
    verify(
      () => dio.delete<void>('/assistants/a%2Fb/resources/r%20x'),
    ).called(1);
  });

  test('409 resource_inherited conserva semántica para la UI', () async {
    when(() => dio.delete<void>('/assistants/a/resources/r')).thenThrow(
      _badResponse(409, data: <String, Object?>{'error': 'resource_inherited'}),
    );

    await expectLater(
      repository.detach('a', 'r'),
      throwsA(
        isA<ResourcesFailure>()
            .having((failure) => failure.inherited, 'inherited', isTrue)
            .having(
              (failure) => failure.message,
              'message',
              contains('organización'),
            ),
      ),
    );
  });

  test(
    'payload malformado falla cerrado en vez de inventar recursos',
    () async {
      when(() => dio.get<Object?>('/resources?active=true')).thenAnswer(
        (_) async => _response<Object?>('/resources', <String, Object?>{
          'revision': 1,
          'resources': <Object?>[
            <String, Object?>{'id': 'incompleto'},
          ],
        }),
      );

      await expectLater(
        repository.listOrganization(),
        throwsA(isA<ResourcesFailure>()),
      );
    },
  );
}
