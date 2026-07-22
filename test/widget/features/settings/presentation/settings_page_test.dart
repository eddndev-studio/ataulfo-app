import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_avatar.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/core/design/widgets/app_page_header.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/core/design/widgets/app_section_link.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/settings/presentation/pages/settings_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

const _identity = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
);

void main() {
  setUpAll(() => registerFallbackValue(const AuthLoggedOut()));

  late _MockAuthBloc authBloc;

  setUp(() => authBloc = _MockAuthBloc());

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: const Scaffold(body: SettingsPage()),
    ),
  );

  testWidgets('presenta identidad personal y no mezcla el rol organizacional', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('settings.header')), findsOneWidget);
    expect(
      tester.widget(find.byKey(const Key('settings.header'))),
      isA<AppPageHeader>(),
    );
    expect(find.byType(AppAvatar), findsOneWidget);
    expect(find.text('op@example.com'), findsOneWidget);
    expect(find.widgetWithText(AppPill, 'Cuenta personal'), findsOneWidget);
    expect(find.text('Propietario'), findsNothing);
    expect(find.text('u1'), findsNothing);
    expect(find.text('o1'), findsNothing);
  });

  testWidgets('Ajustes contiene sólo preferencias personales', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(host());

    final card = find.byKey(const Key('settings.card.personal'));
    expect(card, findsOneWidget);
    expect(tester.widget(card), isA<AppCard>());
    expect(
      find.descendant(of: card, matching: find.byType(AppSectionLink)),
      findsNWidgets(2),
    );
    expect(
      find.byKey(const Key('settings.notifications_tile')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('settings.appearance_tile')), findsOneWidget);

    // Estas áreas ahora viven en Organización o en su contexto operativo.
    expect(find.text('Tus organizaciones'), findsNothing);
    expect(find.text('Miembros'), findsNothing);
    expect(find.text('Configuración de IA'), findsNothing);
    expect(find.text('Catálogo de productos'), findsNothing);
    expect(find.text('Medios'), findsNothing);
    expect(find.text('Etiquetas'), findsNothing);
  });

  testWidgets('preferencias navegan con push y conservan el back', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
    final destinations = <String>[];
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const Scaffold(body: SettingsPage()),
          ),
        ),
        for (final path in <String>['/notifications', '/appearance'])
          GoRoute(
            path: path,
            builder: (context, _) {
              destinations.add(path);
              return Scaffold(
                body: Text(
                  Navigator.of(context).canPop() ? 'con back' : 'sin back',
                ),
              );
            },
          ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byKey(const Key('settings.notifications_tile')));
    await tester.pumpAndSettle();
    expect(destinations, <String>['/notifications']);
    expect(find.text('con back'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings.appearance_tile')));
    await tester.pumpAndSettle();
    expect(destinations, <String>['/notifications', '/appearance']);
    expect(find.text('con back'), findsOneWidget);
  });

  testWidgets('Cerrar sesión exige confirmación', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(host());
    await tester.ensureVisible(find.widgetWithText(AppButton, 'Cerrar sesión'));
    await tester.tap(find.widgetWithText(AppButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    verifyNever(() => authBloc.add(const AuthLoggedOut()));

    await tester.tap(find.byKey(const Key('settings.logout_confirm')));
    await tester.pumpAndSettle();
    verify(() => authBloc.add(const AuthLoggedOut())).called(1);
  });

  testWidgets('muestra la versión instalada al pie', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Ataulfo',
      packageName: 'studio.eddndev.ataulfo',
      version: '0.7.0',
      buildNumber: '18',
      buildSignature: '',
    );
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings.version')), findsOneWidget);
    expect(find.text('Ataulfo v0.7.0 (18)'), findsOneWidget);
  });

  testWidgets('sin sesión renderiza vacío mientras actúa el redirect', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());

    await tester.pumpWidget(host());

    expect(find.byType(AppButton), findsNothing);
    expect(find.byType(AppPill), findsNothing);
  });
}
