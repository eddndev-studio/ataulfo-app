import 'package:ataulfo/features/notifications/domain/entities/notification_inbox_item.dart';
import 'package:ataulfo/features/notifications/domain/entities/notification_preference.dart';
import 'package:ataulfo/features/notifications/domain/failures/notifications_failure.dart';
import 'package:ataulfo/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:ataulfo/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements NotificationsRepository {}

final _item = NotificationInboxItem(
  id: 'ni-1',
  eventType: NotificationEventType.messageInboundNew,
  title: 'Nuevo mensaje',
  body: 'hola',
  priority: NotificationPriority.normal,
  count: 1,
  status: NotificationInboxStatus.unread,
  createdAt: DateTime.utc(2026, 6, 3, 12),
  updatedAt: DateTime.utc(2026, 6, 3, 12),
);

void main() {
  group('NotificationsBloc', () {
    test('estado inicial = NotificationsInitial', () {
      expect(
        NotificationsBloc(_MockRepo()).state,
        const NotificationsInitial(),
      );
    });

    blocTest<NotificationsBloc, NotificationsState>(
      'load ok → Loading, Loaded',
      build: () {
        final repo = _MockRepo();
        when(
          () => repo.listInbox(unreadOnly: true),
        ).thenAnswer((_) async => <NotificationInboxItem>[_item]);
        return NotificationsBloc(repo);
      },
      act: (bloc) => bloc.add(const NotificationsLoadRequested()),
      expect: () => <NotificationsState>[
        const NotificationsLoading(),
        NotificationsLoaded(items: <NotificationInboxItem>[_item]),
      ],
    );

    blocTest<NotificationsBloc, NotificationsState>(
      'load network failure → Failed',
      build: () {
        final repo = _MockRepo();
        when(() => repo.listInbox(unreadOnly: true)).thenAnswer(
          (_) => Future<List<NotificationInboxItem>>.error(
            const NotificationsNetworkFailure(),
          ),
        );
        return NotificationsBloc(repo);
      },
      act: (bloc) => bloc.add(const NotificationsLoadRequested()),
      expect: () => const <NotificationsState>[
        NotificationsLoading(),
        NotificationsFailed(NotificationsNetworkFailure()),
      ],
    );

    blocTest<NotificationsBloc, NotificationsState>(
      'mark read optimista elimina item y llama repo',
      build: () {
        final repo = _MockRepo();
        when(() => repo.markRead('ni-1')).thenAnswer((_) async {});
        return NotificationsBloc(repo);
      },
      seed: () => NotificationsLoaded(items: <NotificationInboxItem>[_item]),
      act: (bloc) => bloc.add(const NotificationMarkReadRequested('ni-1')),
      expect: () => const <NotificationsState>[
        NotificationsLoaded(items: <NotificationInboxItem>[]),
      ],
      verify: (bloc) => verify(() => bloc.repo.markRead('ni-1')).called(1),
    );

    blocTest<NotificationsBloc, NotificationsState>(
      'mark all limpia items y llama repo',
      build: () {
        final repo = _MockRepo();
        when(repo.markAllRead).thenAnswer((_) async {});
        return NotificationsBloc(repo);
      },
      seed: () => NotificationsLoaded(items: <NotificationInboxItem>[_item]),
      act: (bloc) => bloc.add(const NotificationsMarkAllReadRequested()),
      expect: () => const <NotificationsState>[
        NotificationsLoaded(items: <NotificationInboxItem>[]),
      ],
      verify: (bloc) => verify(bloc.repo.markAllRead).called(1),
    );
  });
}
