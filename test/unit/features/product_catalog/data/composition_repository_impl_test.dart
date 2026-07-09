import 'package:ataulfo/features/product_catalog/data/datasources/composition_datasource.dart';
import 'package:ataulfo/features/product_catalog/data/repositories/composition_repository_impl.dart';
import 'package:ataulfo/features/product_catalog/domain/entities/composition_job.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDs extends Mock implements CompositionDatasource {}

void main() {
  late _MockDs ds;
  late CompositionRepositoryImpl repo;

  setUp(() {
    ds = _MockDs();
    repo = CompositionRepositoryImpl(datasource: ds);
  });

  test('delega compose con premium', () async {
    when(
      () => ds.compose(
        productId: any(named: 'productId'),
        preset: any(named: 'preset'),
        premium: any(named: 'premium'),
      ),
    ).thenAnswer((_) async => 'j1');
    final id = await repo.compose(
      productId: 'p1',
      preset: 'madera',
      premium: true,
    );
    expect(id, 'j1');
    verify(
      () => ds.compose(productId: 'p1', preset: 'madera', premium: true),
    ).called(1);
  });

  test('delega listJobs, accept y discard', () async {
    when(() => ds.listJobs(any())).thenAnswer((_) async => <CompositionJob>[]);
    when(() => ds.accept(any())).thenAnswer((_) async {});
    when(() => ds.discard(any())).thenAnswer((_) async {});

    expect(await repo.listJobs('p1'), isEmpty);
    await repo.accept('j1');
    await repo.discard('j2');

    verify(() => ds.listJobs('p1')).called(1);
    verify(() => ds.accept('j1')).called(1);
    verify(() => ds.discard('j2')).called(1);
  });
}
