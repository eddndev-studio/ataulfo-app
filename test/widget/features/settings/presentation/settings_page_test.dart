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

const _identity = Identity(userId: 'u1', orgId: 'o1', role: 'OWNER');

void main() {
  setUpAll(() {
    registerFallbackValue(const AuthLoggedOut());
  });

  late _MockAuthBloc authBloc;

  setUp(() {
    authBloc = _MockAuthBloc();
  });

  Widget host() => MaterialApp(
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: const SettingsPage(),
    ),
  );

  testWidgets('Authenticated muestra el rol como chip y botón Cerrar sesión', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(host());

    expect(find.text('OWNER'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Cerrar sesión'),
      findsOneWidget,
    );
  });

  testWidgets('tap Cerrar sesión dispara AuthLoggedOut en el bloc', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(host());
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
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
    expect(find.byType(FilledButton), findsNothing);
  });
}
