import 'package:ataulfo/features/trainer/data/datasources/workspace_datasource.dart';
import 'package:ataulfo/features/trainer/data/dto/workspace_doc_dto.dart';
import 'package:ataulfo/features/trainer/domain/failures/trainer_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Map<String, dynamic> docJson({
  String name = 'menu-precios',
  String? content = 'Tacos \$25',
  int version = 1,
}) => <String, dynamic>{
  'name': name,
  if (content != null) 'content': content,
  'sizeBytes': content?.length ?? 0,
  'updatedByKind': 'trainer',
  'version': version,
  'createdAt': '2026-06-10T10:00:00.000Z',
  'updatedAt': '2026-06-10T11:00:00.000Z',
};

void main() {
  late _MockDio dio;
  late DioWorkspaceDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioWorkspaceDatasource(dio);
  });

  DioException bad(int status) => DioException(
    requestOptions: RequestOptions(path: '/x'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/x'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  group('WorkspaceDocDto', () {
    test('parsea el item de listado (sin content) y el doc completo', () {
      final item = WorkspaceDocDto.fromJson(docJson(content: null));
      expect(item.name, 'menu-precios');
      expect(item.content, '');
      expect(item.updatedByKind, 'trainer');

      final full = WorkspaceDocDto.fromJson(docJson());
      expect(full.content, 'Tacos \$25');
      expect(full.version, 1);
      expect(full.updatedAt, DateTime.utc(2026, 6, 10, 11));
    });

    test('campos canónicos ausentes → FormatException', () {
      for (final key in <String>['name', 'version', 'updatedAt']) {
        final json = docJson()..remove(key);
        expect(() => WorkspaceDocDto.fromJson(json), throwsFormatException);
      }
    });
  });

  group('listDocs', () {
    test('GET /templates/{id}/workspace/docs y desempaca {docs}', () async {
      when(
        () => dio.get<Map<String, dynamic>>(any()),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/x'),
          data: <String, dynamic>{
            'docs': <dynamic>[docJson(content: null)],
          },
        ),
      );

      final docs = await ds.listDocs(templateId: 't1');
      expect(docs, hasLength(1));
      expect(docs.first.name, 'menu-precios');
      verify(
        () => dio.get<Map<String, dynamic>>('/templates/t1/workspace/docs'),
      ).called(1);
    });
  });

  group('getDoc / create / update / delete', () {
    test('GET por name devuelve el doc completo', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/x'),
          data: docJson(),
        ),
      );
      final doc = await ds.getDoc(templateId: 't1', name: 'menu-precios');
      expect(doc.content, 'Tacos \$25');
      verify(
        () => dio.get<Map<String, dynamic>>(
          '/templates/t1/workspace/docs/menu-precios',
        ),
      ).called(1);
    });

    test('POST crea con name+content', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 201,
          data: docJson(),
        ),
      );
      await ds.createDoc(templateId: 't1', name: 'menu-precios', content: 'x');
      final captured =
          verify(
                () => dio.post<Map<String, dynamic>>(
                  '/templates/t1/workspace/docs',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(captured['name'], 'menu-precios');
      expect(captured['content'], 'x');
    });

    test('PUT manda content+version (CAS)', () async {
      when(
        () => dio.put<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/x'),
          data: docJson(version: 2),
        ),
      );
      await ds.updateDoc(
        templateId: 't1',
        name: 'menu-precios',
        content: 'y',
        version: 1,
      );
      final captured =
          verify(
                () => dio.put<Map<String, dynamic>>(
                  '/templates/t1/workspace/docs/menu-precios',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(captured['version'], 1);
    });

    test('DELETE manda version en query', () async {
      when(
        () => dio.delete<void>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(requestOptions: RequestOptions(path: '/x')),
      );
      await ds.deleteDoc(templateId: 't1', name: 'menu-precios', version: 3);
      verify(
        () => dio.delete<void>(
          '/templates/t1/workspace/docs/menu-precios',
          queryParameters: <String, dynamic>{'version': '3'},
        ),
      ).called(1);
    });

    test('409 ⇒ Conflict, 422 ⇒ Validation, 404 ⇒ NotFound', () async {
      for (final c in <(int, Type)>[
        (409, TrainerConflictFailure),
        (422, TrainerValidationFailure),
        (404, TrainerNotFoundFailure),
      ]) {
        when(
          () =>
              dio.put<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenThrow(bad(c.$1));
        await expectLater(
          () => ds.updateDoc(
            templateId: 't1',
            name: 'n',
            content: 'x',
            version: 1,
          ),
          throwsA(isA<TrainerFailure>().having((f) => f.runtimeType, 'tipo', c.$2)),
        );
      }
    });
  });
}
