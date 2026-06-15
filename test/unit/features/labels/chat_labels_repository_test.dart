import 'package:ataulfo/features/labels/data/datasources/chat_labels_datasource.dart';
import 'package:ataulfo/features/labels/data/repositories/chat_labels_repository_impl.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDs extends Mock implements ChatLabelsDatasource {}

void main() {
  late _MockDs ds;
  late ChatLabelsRepositoryImpl repo;

  setUp(() {
    ds = _MockDs();
    repo = ChatLabelsRepositoryImpl(datasource: ds);
  });

  test('listForChat delega en el datasource', () async {
    const l = Label(id: 'l1', name: 'VIP', color: '#fff', description: '');
    when(() => ds.listForChat('b', 'c')).thenAnswer((_) async => <Label>[l]);
    expect(await repo.listForChat('b', 'c'), <Label>[l]);
    verify(() => ds.listForChat('b', 'c')).called(1);
  });
}
