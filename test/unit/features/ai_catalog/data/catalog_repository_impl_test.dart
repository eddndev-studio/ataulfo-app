import 'package:ataulfo/features/ai_catalog/data/datasources/catalog_datasource.dart';
import 'package:ataulfo/features/ai_catalog/data/repositories/catalog_repository_impl.dart';
import 'package:ataulfo/features/ai_catalog/domain/entities/catalog.dart';
import 'package:ataulfo/features/ai_catalog/domain/failures/catalog_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDs extends Mock implements CatalogDatasource {}

void main() {
  late _MockDs ds;
  late CatalogRepositoryImpl repo;

  setUp(() {
    ds = _MockDs();
    repo = CatalogRepositoryImpl(datasource: ds);
  });

  group('CatalogRepositoryImpl.fetch', () {
    test('delega al datasource y devuelve el catálogo', () async {
      const catalog = Catalog(
        providers: [
          ProviderEntry(
            provider: 'GEMINI',
            defaultModel: 'gemini-3.1-pro-preview',
            models: [
              AIModel(
                id: 'gemini-3.1-pro-preview',
                supportsTemperature: true,
                supportsThinking: true,
              ),
            ],
          ),
        ],
      );
      when(() => ds.fetch()).thenAnswer((_) async => catalog);

      final got = await repo.fetch();

      expect(got, catalog);
      verify(() => ds.fetch()).called(1);
    });

    test('propaga la failure del datasource sin envolverla', () async {
      when(() => ds.fetch()).thenThrow(const CatalogNetworkFailure());

      // Closure: mocktail.thenThrow lanza sync al invocarse; expectLater
      // necesita una función para atrapar sync-throws igual que async.
      await expectLater(
        () => repo.fetch(),
        throwsA(isA<CatalogNetworkFailure>()),
      );
    });
  });
}
