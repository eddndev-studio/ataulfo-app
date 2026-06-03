import 'package:ataulfo/features/notifications/domain/entities/notification_preference.dart';
import 'package:ataulfo/features/notifications/domain/failures/notifications_failure.dart';
import 'package:ataulfo/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:ataulfo/features/notifications/presentation/bloc/notification_preferences_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements NotificationsRepository {}

const _pref = NotificationPreference(
  eventType: NotificationEventType.messageInboundNew,
  enabled: true,
  botFilter: NotificationBotFilter(all: true),
  labelFilter: <String>[],
  priority: NotificationPriority.normal,
);

void main() {
  group('NotificationPreferencesBloc', () {
    test('estado inicial = Initial', () {
      expect(
        NotificationPreferencesBloc(_MockRepo()).state,
        const NotificationPreferencesInitial(),
      );
    });

    blocTest<NotificationPreferencesBloc, NotificationPreferencesState>(
      'load ok → Loading, Loaded',
      build: () {
        final repo = _MockRepo();
        when(
          repo.listPreferences,
        ).thenAnswer((_) async => const <NotificationPreference>[_pref]);
        return NotificationPreferencesBloc(repo);
      },
      act: (bloc) => bloc.add(const NotificationPreferencesLoadRequested()),
      expect: () => const <NotificationPreferencesState>[
        NotificationPreferencesLoading(),
        NotificationPreferencesLoaded(
          preferences: <NotificationPreference>[_pref],
        ),
      ],
    );

    blocTest<NotificationPreferencesBloc, NotificationPreferencesState>(
      'toggle cambia enabled y persiste',
      build: () {
        final repo = _MockRepo();
        when(() => repo.savePreferences(any())).thenAnswer(
          (_) async => const <NotificationPreference>[
            NotificationPreference(
              eventType: NotificationEventType.messageInboundNew,
              enabled: false,
              botFilter: NotificationBotFilter(all: true),
              labelFilter: <String>[],
              priority: NotificationPriority.normal,
            ),
          ],
        );
        return NotificationPreferencesBloc(repo);
      },
      seed: () => const NotificationPreferencesLoaded(
        preferences: <NotificationPreference>[_pref],
      ),
      act: (bloc) => bloc.add(
        const NotificationPreferenceToggled(
          NotificationEventType.messageInboundNew,
          false,
        ),
      ),
      expect: () => const <NotificationPreferencesState>[
        NotificationPreferencesLoaded(
          preferences: <NotificationPreference>[
            NotificationPreference(
              eventType: NotificationEventType.messageInboundNew,
              enabled: false,
              botFilter: NotificationBotFilter(all: true),
              labelFilter: <String>[],
              priority: NotificationPriority.normal,
            ),
          ],
          saving: true,
        ),
        NotificationPreferencesLoaded(
          preferences: <NotificationPreference>[
            NotificationPreference(
              eventType: NotificationEventType.messageInboundNew,
              enabled: false,
              botFilter: NotificationBotFilter(all: true),
              labelFilter: <String>[],
              priority: NotificationPriority.normal,
            ),
          ],
        ),
      ],
    );

    blocTest<NotificationPreferencesBloc, NotificationPreferencesState>(
      'load failure → Failed',
      build: () {
        final repo = _MockRepo();
        when(repo.listPreferences).thenAnswer(
          (_) => Future<List<NotificationPreference>>.error(
            const NotificationsNetworkFailure(),
          ),
        );
        return NotificationPreferencesBloc(repo);
      },
      act: (bloc) => bloc.add(const NotificationPreferencesLoadRequested()),
      expect: () => const <NotificationPreferencesState>[
        NotificationPreferencesLoading(),
        NotificationPreferencesFailed(NotificationsNetworkFailure()),
      ],
    );
  });
}
