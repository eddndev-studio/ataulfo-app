import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_header_card.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/domain/failures/auth_failure.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/auth/presentation/bloc/switch_org_cubit.dart';
import 'package:ataulfo/features/billing/domain/entities/entitlement.dart';
import 'package:ataulfo/features/billing/presentation/bloc/entitlement_bloc.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bots_bloc.dart';
import 'package:ataulfo/features/invitations/presentation/bloc/invitation_mutation_cubit.dart';
import 'package:ataulfo/features/invitations/presentation/bloc/invitations_bloc.dart';
import 'package:ataulfo/features/members/presentation/bloc/member_mutation_cubit.dart';
import 'package:ataulfo/features/members/presentation/bloc/members_bloc.dart';
import 'package:ataulfo/features/memberships/domain/entities/membership.dart';
import 'package:ataulfo/features/memberships/presentation/bloc/memberships_bloc.dart';
import 'package:ataulfo/features/organization/presentation/pages/organization_page.dart';
import 'package:ataulfo/features/organization/presentation/pages/organization_team_page.dart';
import 'package:ataulfo/features/organization/presentation/widgets/organization_context_switcher.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockMembershipsBloc extends MockBloc<MembershipsEvent, MembershipsState>
    implements MembershipsBloc {}

class _MockSwitchOrgCubit extends MockCubit<SwitchOrgState>
    implements SwitchOrgCubit {}

class _MockMembersBloc extends MockBloc<MembersEvent, MembersState>
    implements MembersBloc {}

class _MockInvitationsBloc extends MockBloc<InvitationsEvent, InvitationsState>
    implements InvitationsBloc {}

class _MockEntitlementBloc extends MockBloc<EntitlementEvent, EntitlementState>
    implements EntitlementBloc {}

class _MockMemberMutationCubit extends MockCubit<MemberMutationState>
    implements MemberMutationCubit {}

class _MockInvitationMutationCubit extends MockCubit<InvitationMutationState>
    implements InvitationMutationCubit {}

class _MockBotsBloc extends MockBloc<BotsEvent, BotsState>
    implements BotsBloc {}

const _owner = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'owner@example.com',
);

const _worker = Identity(
  userId: 'u2',
  orgId: 'o1',
  role: 'WORKER',
  email: 'worker@example.com',
);

const _memberships = <Membership>[
  Membership(orgId: 'o1', orgName: 'Acme Belize', role: 'OWNER'),
  Membership(orgId: 'o2', orgName: 'Estudio Norte', role: 'ADMIN'),
];

void main() {
  late _MockAuthBloc auth;
  late _MockMembershipsBloc memberships;
  late _MockSwitchOrgCubit switcher;

  setUp(() {
    auth = _MockAuthBloc();
    memberships = _MockMembershipsBloc();
    switcher = _MockSwitchOrgCubit();
    when(() => auth.state).thenReturn(const AuthAuthenticated(_owner));
    when(
      () => memberships.state,
    ).thenReturn(const MembershipsLoaded(items: _memberships));
    when(() => switcher.state).thenReturn(const SwitchOrgIdle());
  });

  testWidgets('selector global muestra contexto y cambia a otra organización', (
    tester,
  ) async {
    when(() => switcher.switchTo('o2')).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<MembershipsBloc>.value(value: memberships),
            BlocProvider<SwitchOrgCubit>.value(value: switcher),
          ],
          child: const Scaffold(body: OrganizationContextSwitcher()),
        ),
      ),
    );

    expect(find.text('Acme Belize'), findsOneWidget);
    expect(find.text('Propietario'), findsOneWidget);

    await tester.tap(find.byKey(const Key('organization.context.mobile')));
    await tester.pumpAndSettle();

    expect(find.text('Cambiar organización'), findsOneWidget);
    expect(find.text('Estudio Norte'), findsOneWidget);
    expect(find.byKey(const Key('organization.switch.manage')), findsOneWidget);
    expect(find.byKey(const Key('organization.switch.close')), findsNothing);
    expect(find.byKey(const Key('organization.switch.list')), findsOneWidget);
    expect(
      find.byKey(const Key('organization.switch.active.o1')),
      findsOneWidget,
    );

    final bottomSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(bottomSheet.showDragHandle, isTrue);
    expect(bottomSheet.enableDrag, isTrue);

    final sheetTop = tester.getTopLeft(find.byType(BottomSheet)).dy;
    final titleTop = tester.getTopLeft(find.text('Cambiar organización')).dy;
    expect(titleTop - sheetTop, greaterThanOrEqualTo(40));

    await tester.tap(find.byKey(const Key('organization.switch.org.o2')));
    verify(() => switcher.switchTo('o2')).called(1);
  });

  testWidgets('selector usa la variante compacta en el rail', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<MembershipsBloc>.value(value: memberships),
            BlocProvider<SwitchOrgCubit>.value(value: switcher),
          ],
          child: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: OrganizationContextSwitcher(compact: true),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('organization.context.rail')), findsOneWidget);
    expect(find.byKey(const Key('organization.context.mobile')), findsNothing);
    expect(find.text('Acme Belize'), findsOneWidget);
  });

  testWidgets(
    'un switch en curso termina de procesarse aunque se descarte la hoja',
    (tester) async {
      final states = StreamController<SwitchOrgState>.broadcast();
      addTearDown(states.close);
      SwitchOrgState currentState = const SwitchOrgIdle();
      when(() => switcher.state).thenAnswer((_) => currentState);
      when(() => switcher.stream).thenAnswer((_) => states.stream);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<AuthBloc>.value(value: auth),
              BlocProvider<MembershipsBloc>.value(value: memberships),
              BlocProvider<SwitchOrgCubit>.value(value: switcher),
            ],
            child: const Scaffold(body: OrganizationContextSwitcher()),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('organization.context.mobile')));
      await tester.pumpAndSettle();
      currentState = const SwitchOrgSwitching();
      states.add(currentState);
      await tester.pump();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Cambiar organización'), findsNothing);

      currentState = const SwitchOrgFailed(NetworkFailure());
      states.add(currentState);
      await tester.pumpAndSettle();

      expect(
        find.text('Sin conexión. Revisa tu red e inténtalo de nuevo.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('hoja del selector sigue navegable en un teléfono corto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<MembershipsBloc>.value(value: memberships),
            BlocProvider<SwitchOrgCubit>.value(value: switcher),
          ],
          child: const Scaffold(body: OrganizationContextSwitcher()),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('organization.context.mobile')));
    await tester.pumpAndSettle();
    expect(find.text('Cambiar organización'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('organization.switch.manage')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hub ADMIN reúne las cuatro áreas y un resumen legible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final members = _MockMembersBloc();
    final invitations = _MockInvitationsBloc();
    final entitlement = _MockEntitlementBloc();
    when(() => members.state).thenReturn(const MembersLoaded(items: []));
    when(
      () => invitations.state,
    ).thenReturn(const InvitationsLoaded(items: []));
    when(() => entitlement.state).thenReturn(
      const EntitlementLoaded(
        entitlement: Entitlement(
          planCode: 'pro',
          status: 'active',
          trialExpired: false,
          creditsUsed: 12,
          creditCap: 100,
          withinQuota: true,
          quotaExceeded: false,
          storageUsedMb: 4,
          storageQuotaMb: 100,
          eligibleProviders: <String>{},
          features: <String>[],
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<MembershipsBloc>.value(value: memberships),
            BlocProvider<MembersBloc>.value(value: members),
            BlocProvider<InvitationsBloc>.value(value: invitations),
            BlocProvider<EntitlementBloc>.value(value: entitlement),
          ],
          child: const Scaffold(
            body: OrganizationPage(canManage: true, hasBilling: true),
          ),
        ),
      ),
    );

    expect(find.text('Acme Belize'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.byType(AppHeaderCard), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const Key('organization.general')), findsOneWidget);
    expect(find.byKey(const Key('organization.team')), findsOneWidget);
    expect(find.byKey(const Key('organization.ai')), findsOneWidget);
    expect(find.byKey(const Key('organization.plan')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hub WORKER es informativo y no ofrece administración', (
    tester,
  ) async {
    when(() => auth.state).thenReturn(const AuthAuthenticated(_worker));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<MembershipsBloc>.value(value: memberships),
          ],
          child: const Scaffold(
            body: OrganizationPage(canManage: false, hasBilling: false),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('organization.read_only')), findsOneWidget);
    expect(find.byKey(const Key('organization.management')), findsNothing);
    expect(find.byKey(const Key('organization.change')), findsOneWidget);
  });

  testWidgets('Equipo cambia de miembros a invitaciones sin nueva ruta', (
    tester,
  ) async {
    final members = _MockMembersBloc();
    final invitations = _MockInvitationsBloc();
    final memberMutation = _MockMemberMutationCubit();
    final invitationMutation = _MockInvitationMutationCubit();
    final bots = _MockBotsBloc();
    when(() => members.state).thenReturn(const MembersLoaded(items: []));
    when(
      () => invitations.state,
    ).thenReturn(const InvitationsLoaded(items: []));
    when(() => memberMutation.state).thenReturn(const MemberMutationIdle());
    when(
      () => invitationMutation.state,
    ).thenReturn(const InvitationMutationIdle());
    when(
      () => bots.state,
    ).thenReturn(const BotsLoaded(items: [], isRefreshing: false));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<MembersBloc>.value(value: members),
            BlocProvider<InvitationsBloc>.value(value: invitations),
            BlocProvider<MemberMutationCubit>.value(value: memberMutation),
            BlocProvider<InvitationMutationCubit>.value(
              value: invitationMutation,
            ),
            BlocProvider<BotsBloc>.value(value: bots),
          ],
          child: const Scaffold(body: OrganizationTeamPage()),
        ),
      ),
    );

    expect(find.text('Aún trabajas en solitario'), findsOneWidget);
    await tester.tap(find.byKey(const Key('members.empty.invite')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invitations.invite')), findsOneWidget);
    expect(find.text('Todavía no hay invitaciones'), findsOneWidget);
  });
}
