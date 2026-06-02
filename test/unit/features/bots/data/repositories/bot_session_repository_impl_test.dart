import 'package:ataulfo/features/bots/data/datasources/bot_session_datasource.dart';
import 'package:ataulfo/features/bots/data/repositories/bot_session_repository_impl.dart';
import 'package:ataulfo/features/bots/domain/entities/connect_link.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDs extends Mock implements BotSessionDatasource {}

void main() {
  late _MockDs ds;
  late BotSessionRepositoryImpl repo;

  setUp(() {
    ds = _MockDs();
    repo = BotSessionRepositoryImpl(datasource: ds);
  });

  test('startSession delega en el datasource', () async {
    when(() => ds.startSession('b1')).thenAnswer((_) async {});
    await repo.startSession('b1');
    verify(() => ds.startSession('b1')).called(1);
  });

  test('stopSession delega en el datasource', () async {
    when(() => ds.stopSession('b1')).thenAnswer((_) async {});
    await repo.stopSession('b1');
    verify(() => ds.stopSession('b1')).called(1);
  });

  test(
    'issueConnectLink delega y devuelve el ConnectLink del datasource',
    () async {
      final link = ConnectLink(url: 'u', expiresAt: DateTime.utc(2026));
      when(() => ds.issueConnectLink('b1')).thenAnswer((_) async => link);
      expect(await repo.issueConnectLink('b1'), link);
    },
  );

  test('clearConversations delega en el datasource', () async {
    when(() => ds.clearConversations('b1')).thenAnswer((_) async {});
    await repo.clearConversations('b1');
    verify(() => ds.clearConversations('b1')).called(1);
  });

  test('resetSessions delega en el datasource', () async {
    when(() => ds.resetSessions('b1')).thenAnswer((_) async {});
    await repo.resetSessions('b1');
    verify(() => ds.resetSessions('b1')).called(1);
  });
}
