import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/domain/failures/auth_failure.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/auth/presentation/bloc/switch_org_cubit.dart';
import 'package:ataulfo/features/memberships/domain/entities/membership.dart';
import 'package:ataulfo/features/memberships/domain/failures/memberships_failure.dart';
import 'package:ataulfo/features/memberships/presentation/bloc/memberships_bloc.dart';
import 'package:ataulfo/features/memberships/presentation/pages/select_org_page.dart';
import 'package:ataulfo/features/memberships/presentation/widgets/org_membership_tile.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMembershipsBloc extends MockBloc<MembershipsEvent, MembershipsState>
    implements MembershipsBloc {}

class _MockSwitchOrgCubit extends MockCubit<SwitchOrgState>
    implements SwitchOrgCubit {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

// Sin org activa: el caso real de /select-org. Ningún tile matchea como activo.
const _noOrg = Identity(userId: 'u1', orgId: '', role: '', email: 'op@x.com');

const _acme = Membership(orgId: 'o-acme', orgName: 'Acme', role: 'OWNER');
const _bravo = Membership(orgId: 'o-bravo', orgName: 'Bravo', role: 'ADMIN');

void main() {
  setUpAll(() {
    registerFallbackValue(const MembershipsLoadRequested());
    registerFallbackValue(const AuthCheckRequested());
  });

  late _MockMembershipsBloc memberships;
  late _MockSwitchOrgCubit switchOrg;
  late _MockAuthBloc auth;

  setUp(() {
    memberships = _MockMembershipsBloc();
    switchOrg = _MockSwitchOrgCubit();
    auth = _MockAuthBloc();
    when(() => memberships.state).thenReturn(const MembershipsInitial());
    when(() => switchOrg.state).thenReturn(const SwitchOrgIdle());
    when(() => switchOrg.switchTo(any())).thenAnswer((_) async {});
    when(() => auth.state).thenReturn(const AuthAuthenticatedNoOrg(_noOrg));
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<MembershipsBloc>.value(value: memberships),
        BlocProvider<SwitchOrgCubit>.value(value: switchOrg),
        BlocProvider<AuthBloc>.value(value: auth),
      ],
      // Página content-only: la ruta aporta Scaffold + AppBar; en aislamiento
      // envolvemos en Scaffold para tener Material + ScaffoldMessenger.
      child: const Scaffold(body: SelectOrgPage()),
    ),
  );

  testWidgets('Loading muestra spinner', (tester) async {
    when(() => memberships.state).thenReturn(const MembershipsLoading());

    await tester.pumpWidget(host());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
    'Loading conserva "Cerrar sesión" (un /auth/memberships colgado no '
    'encierra al operador)',
    (tester) async {
      when(() => memberships.state).thenReturn(const MembershipsLoading());

      await tester.pumpWidget(host());
      await tester.tap(find.widgetWithText(AppButton, 'Cerrar sesión'));
      await tester.pump();

      verify(() => auth.add(const AuthLoggedOut())).called(1);
    },
  );

  testWidgets('Failed muestra mensaje y botón Reintentar', (tester) async {
    when(
      () => memberships.state,
    ).thenReturn(const MembershipsFailed(MembershipsNetworkFailure()));

    await tester.pumpWidget(host());

    expect(find.widgetWithText(AppButton, 'Reintentar'), findsOneWidget);
  });

  testWidgets('tap Reintentar dispara MembershipsLoadRequested', (
    tester,
  ) async {
    when(
      () => memberships.state,
    ).thenReturn(const MembershipsFailed(MembershipsNetworkFailure()));

    await tester.pumpWidget(host());
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    await tester.pump();

    verify(() => memberships.add(const MembershipsLoadRequested())).called(1);
  });

  testWidgets('Loaded vacío muestra el copy de sin organizaciones', (
    tester,
  ) async {
    when(
      () => memberships.state,
    ).thenReturn(const MembershipsLoaded(items: <Membership>[]));

    await tester.pumpWidget(host());

    expect(
      find.text('Todavía no perteneces a ninguna organización'),
      findsOneWidget,
    );
  });

  testWidgets('Loaded con items renderiza un OrgMembershipTile por org', (
    tester,
  ) async {
    when(
      () => memberships.state,
    ).thenReturn(const MembershipsLoaded(items: <Membership>[_acme, _bravo]));

    await tester.pumpWidget(host());

    expect(find.byType(OrgMembershipTile), findsNWidgets(2));
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('Bravo'), findsOneWidget);
  });

  testWidgets('todos los tiles son tappables (en /select-org no hay activa)', (
    tester,
  ) async {
    when(
      () => memberships.state,
    ).thenReturn(const MembershipsLoaded(items: <Membership>[_acme, _bravo]));

    await tester.pumpWidget(host());

    for (final tile in tester.widgetList<OrgMembershipTile>(
      find.byType(OrgMembershipTile),
    )) {
      expect(tile.onTap, isNotNull);
      expect(tile.isActive, isFalse);
    }
  });

  testWidgets('tap en un tile dispara switchTo(orgId)', (tester) async {
    when(
      () => memberships.state,
    ).thenReturn(const MembershipsLoaded(items: <Membership>[_acme, _bravo]));

    await tester.pumpWidget(host());
    await tester.tap(find.text('Bravo'));
    await tester.pump();

    verify(() => switchOrg.switchTo('o-bravo')).called(1);
  });

  testWidgets(
    'mientras Switching los taps se deshabilitan (evita doble-switch)',
    (tester) async {
      when(
        () => memberships.state,
      ).thenReturn(const MembershipsLoaded(items: <Membership>[_acme, _bravo]));
      when(() => switchOrg.state).thenReturn(const SwitchOrgSwitching());

      await tester.pumpWidget(host());
      await tester.tap(find.text('Bravo'), warnIfMissed: false);
      await tester.pump();

      verifyNever(() => switchOrg.switchTo(any()));
    },
  );

  testWidgets(
    'Switched dispara AuthCheckRequested (la página flipa la sesión)',
    (tester) async {
      when(
        () => memberships.state,
      ).thenReturn(const MembershipsLoaded(items: <Membership>[_acme]));
      whenListen(
        switchOrg,
        Stream<SwitchOrgState>.fromIterable(const <SwitchOrgState>[
          SwitchOrgSwitching(),
          SwitchOrgSwitched('o-acme'),
        ]),
        initialState: const SwitchOrgIdle(),
      );

      await tester.pumpWidget(host());
      await tester.pump();

      verify(() => auth.add(const AuthCheckRequested())).called(1);
    },
  );

  testWidgets('Failed NotMember recarga la lista y avisa con SnackBar', (
    tester,
  ) async {
    when(
      () => memberships.state,
    ).thenReturn(const MembershipsLoaded(items: <Membership>[_acme]));
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

    verify(() => memberships.add(const MembershipsLoadRequested())).called(1);
    expect(find.text('Ya no eres miembro de esa organización'), findsOneWidget);
  });

  testWidgets('Failed genérico NO recarga la lista, solo avisa con SnackBar', (
    tester,
  ) async {
    when(
      () => memberships.state,
    ).thenReturn(const MembershipsLoaded(items: <Membership>[_acme]));
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

    verifyNever(() => memberships.add(any()));
    expect(
      find.text('No pudimos cambiar de organización, reintenta'),
      findsOneWidget,
    );
  });

  testWidgets('"Cerrar sesión" dispara AuthLoggedOut', (tester) async {
    when(
      () => memberships.state,
    ).thenReturn(const MembershipsLoaded(items: <Membership>[_acme]));

    await tester.pumpWidget(host());
    await tester.tap(find.widgetWithText(AppButton, 'Cerrar sesión'));
    await tester.pump();

    verify(() => auth.add(const AuthLoggedOut())).called(1);
  });
}
