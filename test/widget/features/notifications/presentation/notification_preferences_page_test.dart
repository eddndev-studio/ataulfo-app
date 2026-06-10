import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_switch.dart';
import 'package:ataulfo/features/notifications/domain/entities/notification_preference.dart';
import 'package:ataulfo/features/notifications/domain/failures/notifications_failure.dart';
import 'package:ataulfo/features/notifications/presentation/bloc/notification_preferences_bloc.dart';
import 'package:ataulfo/features/notifications/presentation/pages/notification_preferences_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPreferencesBloc
    extends MockBloc<NotificationPreferencesEvent, NotificationPreferencesState>
    implements NotificationPreferencesBloc {}

const _pref = NotificationPreference(
  eventType: NotificationEventType.messageInboundNew,
  enabled: true,
  botFilter: NotificationBotFilter(all: true),
  labelFilter: <String>[],
  priority: NotificationPriority.normal,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const NotificationPreferencesLoadRequested());
    registerFallbackValue(
      const NotificationPreferenceToggled(
        NotificationEventType.messageInboundNew,
        false,
      ),
    );
  });

  late _MockPreferencesBloc bloc;

  setUp(() {
    bloc = _MockPreferencesBloc();
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<NotificationPreferencesBloc>.value(
      value: bloc,
      child: const Scaffold(body: NotificationPreferencesPage()),
    ),
  );

  testWidgets('SaveFailed avisa con SnackBar y conserva la lista', (
    tester,
  ) async {
    const failed = NotificationPreferencesSaveFailed(
      preferences: <NotificationPreference>[_pref],
    );
    whenListen(
      bloc,
      Stream<NotificationPreferencesState>.fromIterable(
        const <NotificationPreferencesState>[failed],
      ),
      initialState: const NotificationPreferencesLoaded(
        preferences: <NotificationPreference>[_pref],
      ),
    );

    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump();

    expect(
      find.text('No pudimos guardar tu preferencia. Intenta de nuevo.'),
      findsOneWidget,
    );
    // La lista sigue renderizada con las prefs originales (switch revertido).
    expect(find.byType(AppSwitch), findsOneWidget);
  });

  testWidgets('loading muestra estado de carga', (tester) async {
    when(() => bloc.state).thenReturn(const NotificationPreferencesLoading());

    await tester.pumpWidget(host());

    expect(
      find.byKey(const Key('notification_preferences.loading')),
      findsOneWidget,
    );
  });

  testWidgets('loaded renderiza preferencia con switch', (tester) async {
    when(() => bloc.state).thenReturn(
      const NotificationPreferencesLoaded(
        preferences: <NotificationPreference>[_pref],
      ),
    );

    await tester.pumpWidget(host());

    expect(find.text('Mensajes nuevos'), findsOneWidget);
    expect(find.byType(AppSwitch), findsOneWidget);
    expect(tester.widget<AppSwitch>(find.byType(AppSwitch)).value, isTrue);
  });

  testWidgets('tap switch despacha toggle', (tester) async {
    when(() => bloc.state).thenReturn(
      const NotificationPreferencesLoaded(
        preferences: <NotificationPreference>[_pref],
      ),
    );

    await tester.pumpWidget(host());
    await tester.tap(find.byType(AppSwitch));

    verify(
      () => bloc.add(
        const NotificationPreferenceToggled(
          NotificationEventType.messageInboundNew,
          false,
        ),
      ),
    ).called(1);
  });

  testWidgets('saving deshabilita switch', (tester) async {
    when(() => bloc.state).thenReturn(
      const NotificationPreferencesLoaded(
        preferences: <NotificationPreference>[_pref],
        saving: true,
      ),
    );

    await tester.pumpWidget(host());

    expect(tester.widget<AppSwitch>(find.byType(AppSwitch)).onChanged, isNull);
  });

  testWidgets('failed muestra retry', (tester) async {
    when(() => bloc.state).thenReturn(
      const NotificationPreferencesFailed(NotificationsNetworkFailure()),
    );

    await tester.pumpWidget(host());

    expect(
      find.byKey(const Key('notification_preferences.error')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    verify(
      () => bloc.add(const NotificationPreferencesLoadRequested()),
    ).called(1);
  });
}
