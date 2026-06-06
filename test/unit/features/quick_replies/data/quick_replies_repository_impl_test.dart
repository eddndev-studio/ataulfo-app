import 'package:ataulfo/features/quick_replies/data/datasources/quick_replies_catalog_datasource.dart';
import 'package:ataulfo/features/quick_replies/data/repositories/quick_replies_repository_impl.dart';
import 'package:ataulfo/features/quick_replies/domain/entities/quick_reply.dart';
import 'package:ataulfo/features/quick_replies/domain/failures/quick_replies_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCatalog extends Mock implements QuickRepliesCatalogDatasource {}

void main() {
  late _MockCatalog catalog;
  late QuickRepliesRepositoryImpl repo;

  setUp(() {
    catalog = _MockCatalog();
    repo = QuickRepliesRepositoryImpl(catalog: catalog);
  });

  test('listCatalog delega en el datasource y devuelve su resultado', () async {
    const items = <QuickReply>[
      QuickReply(
        waQuickReplyId: '61',
        shortcut: 'saludo',
        message: 'Hola',
        deleted: false,
      ),
    ];
    when(() => catalog.listCatalog('b1')).thenAnswer((_) async => items);

    expect(await repo.listCatalog('b1'), items);
    verify(() => catalog.listCatalog('b1')).called(1);
  });

  test('propaga la failure del datasource sin envolverla', () async {
    when(
      () => catalog.listCatalog('b1'),
    ).thenThrow(const QuickRepliesForbiddenFailure());
    await expectLater(
      () => repo.listCatalog('b1'),
      throwsA(isA<QuickRepliesForbiddenFailure>()),
    );
  });
}
