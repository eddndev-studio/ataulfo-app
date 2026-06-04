import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/domain/failures/auth_failure.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/auth/presentation/bloc/rename_org_cubit.dart';
import 'package:ataulfo/features/auth/presentation/bloc/switch_org_cubit.dart';
import 'package:ataulfo/features/memberships/domain/entities/membership.dart';
import 'package:ataulfo/features/memberships/domain/failures/memberships_failure.dart';
import 'package:ataulfo/features/memberships/presentation/bloc/memberships_bloc.dart';
import 'package:ataulfo/features/memberships/presentation/pages/memberships_page.dart';
import 'package:ataulfo/features/memberships/presentation/widgets/org_membership_tile.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockMembershipsBloc extends MockBloc<MembershipsEvent, MembershipsState>
    implements MembershipsBloc {}

class _MockSwitchOrgCubit extends MockCubit<SwitchOrgState>
    implements SwitchOrgCubit {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRenameOrgCubit extends MockCubit<RenameOrgState>
    implements RenameOrgCubit {}

const _identity = Identity(
  userId: 'u1',
  orgId: 'o-active',
  role: 'OWNER',
  email: 'op@example.com',
);

const _supervisor = Identity(
  userId: 'u1',
  orgId: 'o-active',
  role: 'SUPERVISOR',
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
  late _MockSwitchOrgCubit switchOrg;
  late _MockAuthBloc authBloc;
  late _MockRenameOrgCubit renameOrg;

  setUp(() {
    membershipsBloc = _MockMembershipsBloc();
    switchOrg = _MockSwitchOrgCubit();
    authBloc = _MockAuthBloc();
    renameOrg = _MockRenameOrgCubit();
    when(() => membershipsBloc.state).thenReturn(const MembershipsInitial());
    when(() => switchOrg.state).thenReturn(const SwitchOrgIdle());
    when(() => switchOrg.switchTo(any())).thenAnswer((_) async {});
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
    when(() => renameOrg.state).thenReturn(const RenameOrgIdle());
    when(() => renameOrg.rename(any())).thenAnswer((_) async {});
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<MembershipsBloc>.value(value: membershipsBloc),
        BlocProvider<SwitchOrgCubit>.value(value: switchOrg),
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<RenameOrgCubit>.value(value: renameOrg),
      ],
      // Página content-only: en aislamiento envolvemos en Scaffold para
      // tener Material upstream y AppBar real cuando la ruta la monte.
      child: const Scaffold(body: MembershipsPage()),
    ),
  );

  // Harness con router: el switch exitoso navega a /home, lo que en el host
  // sin GoRouter reventaría. Dos rutas — la página en /memberships y un
  // centinela en /home — dejan asertar la navegación de forma determinista.
  Widget routedHost() {
    final router = GoRouter(
      initialLocation: '/memberships',
      routes: <RouteBase>[
        GoRoute(
          path: '/memberships',
          builder: (_, _) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<MembershipsBloc>.value(value: membershipsBloc),
              BlocProvider<SwitchOrgCubit>.value(value: switchOrg),
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<RenameOrgCubit>.value(value: renameOrg),
            ],
            child: const Scaffold(body: MembershipsPage()),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) =>
              const Scaffold(body: Text('home-sentinel', key: Key('home'))),
        ),
        GoRoute(
          path: '/create-org',
          builder: (_, _) => const Scaffold(
            body: Text('create-org-sentinel', key: Key('create-org')),
          ),
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppDesignTheme.dark(),
      routerConfig: router,
    );
  }

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
      // El badge debe estar dentro del tile de la org ACTIVA (Acme), no de
      // la otra (Bravo). Sin este assert un bug "siempre activa" sólo se
      // cazaría visualmente: ambas filas tendrían el badge y el contador
      // global seguiría correcto si la regresión clonara el widget.
      expect(
        find.ancestor(
          of: find.byKey(const Key('memberships.active_badge')),
          matching: find.widgetWithText(AppCard, 'Acme'),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.byKey(const Key('memberships.active_badge')),
          matching: find.widgetWithText(AppCard, 'Bravo'),
        ),
        findsNothing,
      );
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

  testWidgets('el tile de la org activa NO es tappable; los demás SÍ', (
    tester,
  ) async {
    // La org activa (Acme) nunca dispara un switch — cambiar a la org en la
    // que ya estás no tiene efecto y sólo arriesga un doble-switch. El tile no
    // activo (Bravo) sí es tappable para cambiar de org.
    when(() => membershipsBloc.state).thenReturn(
      const MembershipsLoaded(
        items: <Membership>[_activeMembership, _otherMembership],
      ),
    );

    await tester.pumpWidget(host());

    final active = tester.widget<OrgMembershipTile>(
      find.ancestor(
        of: find.text('Acme'),
        matching: find.byType(OrgMembershipTile),
      ),
    );
    expect(active.isActive, isTrue);

    final other = tester.widget<OrgMembershipTile>(
      find.ancestor(
        of: find.text('Bravo'),
        matching: find.byType(OrgMembershipTile),
      ),
    );
    expect(other.isActive, isFalse);
    expect(other.onTap, isNotNull);
  });

  testWidgets('tap en una org no-activa dispara switchTo(orgId)', (
    tester,
  ) async {
    when(() => membershipsBloc.state).thenReturn(
      const MembershipsLoaded(
        items: <Membership>[_activeMembership, _otherMembership],
      ),
    );

    await tester.pumpWidget(host());
    await tester.tap(find.text('Bravo'));
    await tester.pump();

    verify(() => switchOrg.switchTo('o-other')).called(1);
  });

  testWidgets(
    'mientras Switching los taps se deshabilitan (evita doble-switch)',
    (tester) async {
      when(() => membershipsBloc.state).thenReturn(
        const MembershipsLoaded(
          items: <Membership>[_activeMembership, _otherMembership],
        ),
      );
      when(() => switchOrg.state).thenReturn(const SwitchOrgSwitching());

      await tester.pumpWidget(host());
      await tester.tap(find.text('Bravo'), warnIfMissed: false);
      await tester.pump();

      verifyNever(() => switchOrg.switchTo(any()));
    },
  );

  testWidgets(
    'tras un switch exitoso (Switched) los taps siguen deshabilitados',
    (tester) async {
      // Tras el éxito el cubit pasa a Switched (no Switching); la página flipa
      // la sesión y navega, pero hasta que el árbol se desmonte un segundo tap
      // rápido correría carrera con el switch ya consumado.
      when(() => membershipsBloc.state).thenReturn(
        const MembershipsLoaded(
          items: <Membership>[_activeMembership, _otherMembership],
        ),
      );
      when(
        () => switchOrg.state,
      ).thenReturn(const SwitchOrgSwitched('o-other'));

      await tester.pumpWidget(host());
      await tester.tap(find.text('Bravo'), warnIfMissed: false);
      await tester.pump();

      verifyNever(() => switchOrg.switchTo(any()));
    },
  );

  testWidgets(
    'Switched flipa la sesión (AuthCheckRequested) y navega a /home',
    (tester) async {
      when(() => membershipsBloc.state).thenReturn(
        const MembershipsLoaded(items: <Membership>[_otherMembership]),
      );
      whenListen(
        switchOrg,
        Stream<SwitchOrgState>.fromIterable(const <SwitchOrgState>[
          SwitchOrgSwitching(),
          SwitchOrgSwitched('o-other'),
        ]),
        initialState: const SwitchOrgIdle(),
      );

      await tester.pumpWidget(routedHost());
      await tester.pumpAndSettle();

      verify(() => authBloc.add(const AuthCheckRequested())).called(1);
      expect(find.byKey(const Key('home')), findsOneWidget);
    },
  );

  testWidgets('Failed NotMember recarga la lista y avisa con SnackBar', (
    tester,
  ) async {
    when(() => membershipsBloc.state).thenReturn(
      const MembershipsLoaded(items: <Membership>[_otherMembership]),
    );
    whenListen(
      switchOrg,
      Stream<SwitchOrgState>.fromIterable(const <SwitchOrgState>[
        SwitchOrgSwitching(),
        SwitchOrgFailed(NotMemberFailure()),
      ]),
      initialState: const SwitchOrgIdle(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    verify(
      () => membershipsBloc.add(const MembershipsLoadRequested()),
    ).called(1);
    expect(find.text('Ya no eres miembro de esa organización'), findsOneWidget);
  });

  testWidgets('Failed genérico NO recarga la lista, solo avisa con SnackBar', (
    tester,
  ) async {
    when(() => membershipsBloc.state).thenReturn(
      const MembershipsLoaded(items: <Membership>[_otherMembership]),
    );
    whenListen(
      switchOrg,
      Stream<SwitchOrgState>.fromIterable(const <SwitchOrgState>[
        SwitchOrgSwitching(),
        SwitchOrgFailed(NetworkFailure()),
      ]),
      initialState: const SwitchOrgIdle(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    verifyNever(() => membershipsBloc.add(any()));
    expect(
      find.text('No pudimos cambiar de organización, reintenta'),
      findsOneWidget,
    );
  });

  // --- Crear / renombrar organización (S9) ------------------------------------

  testWidgets('Loaded ofrece "Crear organización"', (tester) async {
    when(() => membershipsBloc.state).thenReturn(
      const MembershipsLoaded(items: <Membership>[_activeMembership]),
    );

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('memberships.create')), findsOneWidget);
  });

  testWidgets('tap "Crear organización" navega a /create-org', (tester) async {
    when(() => membershipsBloc.state).thenReturn(
      const MembershipsLoaded(items: <Membership>[_activeMembership]),
    );

    await tester.pumpWidget(routedHost());
    await tester.tap(find.byKey(const Key('memberships.create')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-org')), findsOneWidget);
  });

  testWidgets('OWNER ve "Renombrar organización"', (tester) async {
    when(() => membershipsBloc.state).thenReturn(
      const MembershipsLoaded(items: <Membership>[_activeMembership]),
    );

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('memberships.rename')), findsOneWidget);
  });

  testWidgets('SUPERVISOR NO ve "Renombrar organización" (gate ADMIN+)', (
    tester,
  ) async {
    when(
      () => authBloc.state,
    ).thenReturn(const AuthAuthenticated(_supervisor));
    when(() => membershipsBloc.state).thenReturn(
      const MembershipsLoaded(items: <Membership>[_activeMembership]),
    );

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('memberships.rename')), findsNothing);
  });

  testWidgets(
    'tap "Renombrar" abre la hoja prellenada con el nombre activo y al '
    'guardar despacha rename',
    (tester) async {
      when(() => membershipsBloc.state).thenReturn(
        const MembershipsLoaded(items: <Membership>[_activeMembership]),
      );

      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('memberships.rename')));
      await tester.pumpAndSettle();

      // Prellenada con el nombre de la org activa.
      expect(find.widgetWithText(TextField, 'Acme'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('rename_org.name')),
        'Acme Inc.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rename_org.submit')));
      await tester.pumpAndSettle();

      verify(() => renameOrg.rename('Acme Inc.')).called(1);
    },
  );

  testWidgets('Renamed recarga la lista y avisa', (tester) async {
    when(() => membershipsBloc.state).thenReturn(
      const MembershipsLoaded(items: <Membership>[_activeMembership]),
    );
    whenListen(
      renameOrg,
      Stream<RenameOrgState>.fromIterable(const <RenameOrgState>[
        RenameOrgRenaming(),
        RenameOrgRenamed(),
      ]),
      initialState: const RenameOrgIdle(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    verify(
      () => membershipsBloc.add(const MembershipsLoadRequested()),
    ).called(1);
    expect(find.text('Organización renombrada'), findsOneWidget);
  });

  testWidgets('Failed al renombrar avisa con SnackBar', (tester) async {
    when(() => membershipsBloc.state).thenReturn(
      const MembershipsLoaded(items: <Membership>[_activeMembership]),
    );
    whenListen(
      renameOrg,
      Stream<RenameOrgState>.fromIterable(const <RenameOrgState>[
        RenameOrgRenaming(),
        RenameOrgFailed(NetworkFailure()),
      ]),
      initialState: const RenameOrgIdle(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(
      find.text('Sin conexión. Revisa tu red e inténtalo de nuevo.'),
      findsOneWidget,
    );
  });
}
