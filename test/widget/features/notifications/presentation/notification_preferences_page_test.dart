import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/core/design/widgets/app_switch.dart';
import 'package:ataulfo/core/design/widgets/app_toggle_row.dart';
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

  testWidgets('las preferencias viven en UNA card como toggle rows', (
    tester,
  ) async {
    const other = NotificationPreference(
      eventType: NotificationEventType.botDisconnected,
      enabled: false,
      botFilter: NotificationBotFilter(all: true),
      labelFilter: <String>[],
      priority: NotificationPriority.high,
    );
    when(() => bloc.state).thenReturn(
      const NotificationPreferencesLoaded(
        preferences: <NotificationPreference>[_pref, other],
      ),
    );

    await tester.pumpWidget(host());

    // Anatomía canónica de ajustes: una sola card por sección, con una fila
    // de toggle por preferencia separada por hairlines sp5 — no una card por
    // preferencia (eso es patrón de lista de entidades).
    expect(find.byType(AppCard), findsOneWidget);
    expect(find.byType(AppToggleRow), findsNWidgets(2));
    final divider = tester.widget<Divider>(find.byType(Divider));
    expect(divider.height, AppTokens.sp5);
    expect(divider.color, AppTokens.divider);
    // El label de la fila lo pone AppToggleRow con el titleMedium del theme.
    final context = tester.element(find.byType(AppCard));
    final label = tester.widget<Text>(find.text('Mensajes nuevos'));
    expect(label.style, Theme.of(context).textTheme.titleMedium);
    // Sin glifo leading: en una fila de toggle el ícono no aporta acción ni
    // identidad (como en la card de controles del detalle del bot).
    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
    expect(find.byIcon(Icons.link_off_outlined), findsNothing);
  });

  testWidgets('la copy del estado vacío sale del textTheme', (tester) async {
    when(() => bloc.state).thenReturn(
      const NotificationPreferencesLoaded(
        preferences: <NotificationPreference>[],
      ),
    );

    await tester.pumpWidget(host());

    final context = tester.element(find.byType(NotificationPreferencesPage));
    final textTheme = Theme.of(context).textTheme;
    // Copy secundaria = bodyMedium del theme atenuado a text2, no un
    // TextStyle crudo.
    final empty = tester.widget<Text>(
      find.text('Sin preferencias configuradas'),
    );
    expect(empty.style, textTheme.bodyMedium?.copyWith(color: AppTokens.text2));
  });

  testWidgets('la copy del fallo sale del textTheme', (tester) async {
    when(() => bloc.state).thenReturn(
      const NotificationPreferencesFailed(NotificationsNetworkFailure()),
    );

    await tester.pumpWidget(host());

    final context = tester.element(find.byType(NotificationPreferencesPage));
    final textTheme = Theme.of(context).textTheme;
    final failedCopy = tester.widget<Text>(
      find.text('No se pudieron cargar las preferencias'),
    );
    expect(
      failedCopy.style,
      textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
    );
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
