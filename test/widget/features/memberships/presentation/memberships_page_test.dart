import 'package:agentic/core/design/app_design_theme.dart';
import 'package:agentic/core/design/tokens.dart';
import 'package:agentic/core/design/widgets/app_button.dart';
import 'package:agentic/core/design/widgets/app_card.dart';
import 'package:agentic/core/design/widgets/app_pill.dart';
import 'package:agentic/features/auth/domain/entities/identity.dart';
import 'package:agentic/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:agentic/features/memberships/domain/entities/membership.dart';
import 'package:agentic/features/memberships/domain/failures/memberships_failure.dart';
import 'package:agentic/features/memberships/presentation/bloc/memberships_bloc.dart';
import 'package:agentic/features/memberships/presentation/pages/memberships_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMembershipsBloc extends MockBloc<MembershipsEvent, MembershipsState>
    implements MembershipsBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

const _identity = Identity(
  userId: 'u1',
  orgId: 'o-active',
  role: 'OWNER',
  email: 'op@example.com',
);

const _activeMembership = Membership(
  orgId: 'o-active',
  orgName: 'Acme',
  role: 'OWNER',
);
const _otherMembership = Membership(
  orgId: 'o-other',
  orgName: 'Bravo',
  role: 'ADMIN',
);

void main() {
  setUpAll(() {
    registerFallbackValue(const MembershipsLoadRequested());
    registerFallbackValue(const AuthCheckRequested());
  });

  late _MockMembershipsBloc membershipsBloc;
  late _MockAuthBloc authBloc;

  setUp(() {
    membershipsBloc = _MockMembershipsBloc();
    authBloc = _MockAuthBloc();
    when(() => membershipsBloc.state).thenReturn(const MembershipsInitial());
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<MembershipsBloc>.value(value: membershipsBloc),
        BlocProvider<AuthBloc>.value(value: authBloc),
      ],
      // Página content-only: en aislamiento envolvemos en Scaffold para
      // tener Material upstream y AppBar real cuando la ruta la monte.
      child: const Scaffold(body: MembershipsPage()),
    ),
  );

  testWidgets('Loading muestra spinner con AppTokens.primary', (tester) async {
    when(() => membershipsBloc.state).thenReturn(const MembershipsLoading());

    await tester.pumpWidget(host());

    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.valueColor?.value, AppTokens.primary);
  });

  testWidgets('Loaded con N memberships renderiza una AppCard por cada uno', (
    tester,
  ) async {
    when(() => membershipsBloc.state).thenReturn(
      const MembershipsLoaded(
        items: <Membership>[_activeMembership, _otherMembership],
      ),
    );

    await tester.pumpWidget(host());

    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('Bravo'), findsOneWidget);
    expect(find.byType(AppCard), findsNWidgets(2));
  });

  testWidgets('Loaded vacío muestra empty state (sin tiles)', (tester) async {
    when(
      () => membershipsBloc.state,
    ).thenReturn(const MembershipsLoaded(items: <Membership>[]));

    await tester.pumpWidget(host());

    expect(find.text('Acme'), findsNothing);
    expect(find.byKey(const Key('memberships.empty')), findsOneWidget);
  });

  testWidgets(
    'badge "Activa" aparece SÓLO en la org que coincide con identity.orgId',
    (tester) async {
      // El orgId activo viene del AuthBloc (Identity.orgId == 'o-active'),
      // sin acoplar la página al wire de JWT ni a otro feature global.
      when(() => membershipsBloc.state).thenReturn(
        const MembershipsLoaded(
          items: <Membership>[_activeMembership, _otherMembership],
        ),
      );

      await tester.pumpWidget(host());

      // El badge tiene una key contractual para que los smoke tests futuros
      // (y este test) lo encuentren sin acoplarse a copy.
      expect(find.byKey(const Key('memberships.active_badge')), findsOneWidget);
      // El rol siempre se muestra como pill, en ambas filas.
      expect(find.byType(AppPill), findsAtLeastNWidgets(2));
    },
  );

  testWidgets('Failed muestra mensaje y botón Reintentar tonal', (
    tester,
  ) async {
    when(
      () => membershipsBloc.state,
    ).thenReturn(const MembershipsFailed(MembershipsNetworkFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('memberships.error')), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Reintentar'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('tap Reintentar dispara MembershipsLoadRequested', (
    tester,
  ) async {
    when(
      () => membershipsBloc.state,
    ).thenReturn(const MembershipsFailed(MembershipsNetworkFailure()));

    await tester.pumpWidget(host());
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    await tester.pump();

    verify(
      () => membershipsBloc.add(const MembershipsLoadRequested()),
    ).called(1);
  });
}
