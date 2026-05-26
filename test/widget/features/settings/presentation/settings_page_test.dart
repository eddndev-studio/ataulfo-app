import 'package:agentic/core/design/app_design_theme.dart';
import 'package:agentic/core/design/widgets/app_button.dart';
import 'package:agentic/core/design/widgets/app_pill.dart';
import 'package:agentic/features/auth/domain/entities/identity.dart';
import 'package:agentic/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:agentic/features/settings/presentation/pages/settings_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

const _identity = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
);

void main() {
  setUpAll(() {
    registerFallbackValue(const AuthLoggedOut());
  });

  late _MockAuthBloc authBloc;

  setUp(() {
    authBloc = _MockAuthBloc();
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      // En el shell real, SettingsPage es content-only del Scaffold del
      // ShellPage. En aislamiento, lo envolvemos en Scaffold para que
      // los primitivos del DS tengan Material upstream.
      child: const Scaffold(body: SettingsPage()),
    ),
  );

  testWidgets('Authenticated muestra el rol como AppPill + AppButton.danger', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(host());

    expect(find.byType(AppPill), findsOneWidget);
    expect(find.widgetWithText(AppPill, 'OWNER'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Cerrar sesión'), findsOneWidget);
    // Los M3 baseline ya no deben aparecer.
    expect(find.byType(Chip), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('tap Cerrar sesión dispara AuthLoggedOut en el bloc', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(host());
    await tester.tap(find.widgetWithText(AppButton, 'Cerrar sesión'));
    await tester.pump();

    verify(() => authBloc.add(const AuthLoggedOut())).called(1);
  });

  testWidgets('non-Authenticated renderiza vacío (trust router redirect)', (
    tester,
  ) async {
    // El redirect del router debería navegar fuera antes de que esto
    // sea visible más de un frame; mostramos nada en lugar de un
    // estado UI específico para evitar ruido en transiciones.
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());

    await tester.pumpWidget(host());

    expect(find.text('OWNER'), findsNothing);
    expect(find.byType(AppButton), findsNothing);
    expect(find.byType(AppPill), findsNothing);
  });
}
