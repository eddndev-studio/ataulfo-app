import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/members/domain/entities/member.dart';
import 'package:ataulfo/features/members/domain/failures/members_failure.dart';
import 'package:ataulfo/features/members/presentation/bloc/member_mutation_cubit.dart';
import 'package:ataulfo/features/members/presentation/bloc/members_bloc.dart';
import 'package:ataulfo/features/members/presentation/pages/members_page.dart';
import 'package:ataulfo/features/members/presentation/widgets/member_tile.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMembersBloc extends MockBloc<MembersEvent, MembersState>
    implements MembersBloc {}

class _MockMemberMutationCubit extends MockCubit<MemberMutationState>
    implements MemberMutationCubit {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

// El caller logueado: su userId NO coincide con _owner/_worker (no es self).
const _caller = Identity(
  userId: 'u-admin',
  orgId: 'o1',
  role: 'ADMIN',
  email: 'admin@x.com',
);

const _owner = Member(
  id: 'm1',
  userId: 'u1',
  email: 'owner@x.com',
  emailVerified: true,
  role: 'OWNER',
);
const _worker = Member(
  id: 'm2',
  userId: 'u2',
  email: 'worker@x.com',
  emailVerified: false,
  role: 'WORKER',
);
// El propio caller como fila de la lista (userId == _caller.userId).
const _self = Member(
  id: 'm3',
  userId: 'u-admin',
  email: 'admin@x.com',
  emailVerified: true,
  role: 'ADMIN',
);

void main() {
  setUpAll(() {
    registerFallbackValue(const MembersLoadRequested());
  });

  late _MockMembersBloc bloc;
  late _MockMemberMutationCubit mutation;
  late _MockAuthBloc auth;

  setUp(() {
    bloc = _MockMembersBloc();
    mutation = _MockMemberMutationCubit();
    auth = _MockAuthBloc();
    when(() => bloc.state).thenReturn(const MembersInitial());
    when(() => mutation.state).thenReturn(const MemberMutationIdle());
    when(() => mutation.changeRole(any(), any())).thenAnswer((_) async {});
    when(() => mutation.remove(any())).thenAnswer((_) async {});
    when(() => auth.state).thenReturn(const AuthAuthenticated(_caller));
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<MembersBloc>.value(value: bloc),
        BlocProvider<MemberMutationCubit>.value(value: mutation),
        BlocProvider<AuthBloc>.value(value: auth),
      ],
      // Página content-only: la ruta aporta Scaffold + AppBar; en aislamiento
      // envolvemos en Scaffold para tener Material + ScaffoldMessenger.
      child: const Scaffold(body: MembersPage()),
    ),
  );

  testWidgets('Initial/Loading muestra spinner', (tester) async {
    when(() => bloc.state).thenReturn(const MembersLoading());

    await tester.pumpWidget(host());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Loaded renderiza un MemberTile por miembro', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const MembersLoaded(items: <Member>[_owner, _worker]));

    await tester.pumpWidget(host());

    expect(find.byType(MemberTile), findsNWidgets(2));
    expect(find.text('owner@x.com'), findsOneWidget);
    expect(find.text('worker@x.com'), findsOneWidget);
    // El badge distingue confirmados de altas sin confirmar.
    expect(find.byKey(const Key('members.verified_badge')), findsOneWidget);
    expect(find.byKey(const Key('members.unverified_badge')), findsOneWidget);
  });

  testWidgets('Loaded vacío muestra el copy de sin miembros', (tester) async {
    when(() => bloc.state).thenReturn(const MembersLoaded(items: <Member>[]));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('members.empty')), findsOneWidget);
    expect(find.byType(MemberTile), findsNothing);
  });

  testWidgets('Failed muestra mensaje y botón Reintentar', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const MembersFailed(MembersServerFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('members.error')), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Reintentar'), findsOneWidget);
  });

  testWidgets('tap Reintentar dispara MembersLoadRequested', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const MembersFailed(MembersNetworkFailure()));

    await tester.pumpWidget(host());
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    await tester.pump();

    verify(() => bloc.add(const MembersLoadRequested())).called(1);
  });

  testWidgets('Forbidden también muestra el error con reintento', (
    tester,
  ) async {
    // El gate del tile es cosmético; si un rol por debajo de ADMIN llegara a la
    // página igual recibe el error (la autoridad es el 403 del backend). El
    // reintento es inocuo: vuelve a 403.
    when(
      () => bloc.state,
    ).thenReturn(const MembersFailed(MembersForbiddenFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('members.error')), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Reintentar'), findsOneWidget);
  });

  testWidgets('tap en un miembro abre la hoja de gestión', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const MembersLoaded(items: <Member>[_worker]));

    await tester.pumpWidget(host());
    await tester.tap(find.byType(MemberTile));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('member_edit.role')), findsOneWidget);
  });

  testWidgets('elegir rol y Guardar despacha changeRole en el cubit', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const MembersLoaded(items: <Member>[_worker]));

    await tester.pumpWidget(host());
    await tester.tap(find.byType(MemberTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('member_edit.role')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ADMIN').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('member_edit.save')));
    await tester.pumpAndSettle();

    verify(() => mutation.changeRole('m2', 'ADMIN')).called(1);
  });

  testWidgets('quitar (confirmado) despacha remove en el cubit', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const MembersLoaded(items: <Member>[_worker]));

    await tester.pumpWidget(host());
    await tester.tap(find.byType(MemberTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('member_edit.remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('member_edit.remove_confirm')));
    await tester.pumpAndSettle();

    verify(() => mutation.remove('m2')).called(1);
  });

  testWidgets('la fila propia oculta el botón de quitar (self-row)', (
    tester,
  ) async {
    // _self.userId == _caller.userId: la página marca la fila como propia y la
    // hoja esconde "Quitar" (auto-quitarse cerraría la sesión).
    when(
      () => bloc.state,
    ).thenReturn(const MembersLoaded(items: <Member>[_self]));

    await tester.pumpWidget(host());
    await tester.tap(find.byType(MemberTile));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('member_edit.role')), findsOneWidget);
    expect(find.byKey(const Key('member_edit.remove')), findsNothing);
  });

  testWidgets('mutación Success recarga la lista y avisa', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const MembersLoaded(items: <Member>[_worker]));
    whenListen(
      mutation,
      Stream<MemberMutationState>.fromIterable(const <MemberMutationState>[
        MemberMutationInProgress(),
        MemberMutationSuccess(MemberMutationAction.roleChanged),
      ]),
      initialState: const MemberMutationIdle(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    verify(() => bloc.add(const MembersLoadRequested())).called(1);
    expect(find.text('Rol actualizado'), findsOneWidget);
  });

  testWidgets('mutación Success de quitar avisa "Miembro eliminado"', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const MembersLoaded(items: <Member>[_worker]));
    whenListen(
      mutation,
      Stream<MemberMutationState>.fromIterable(const <MemberMutationState>[
        MemberMutationInProgress(),
        MemberMutationSuccess(MemberMutationAction.removed),
      ]),
      initialState: const MemberMutationIdle(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('Miembro eliminado'), findsOneWidget);
  });

  testWidgets(
    'mutación Success de transferir avisa "Propiedad transferida" (no el copy '
    'de rol)',
    (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(const MembersLoaded(items: <Member>[_worker]));
      whenListen(
        mutation,
        Stream<MemberMutationState>.fromIterable(const <MemberMutationState>[
          MemberMutationInProgress(),
          MemberMutationSuccess(MemberMutationAction.ownershipTransferred),
        ]),
        initialState: const MemberMutationIdle(),
      );

      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.text('Propiedad transferida'), findsOneWidget);
      expect(find.text('Rol actualizado'), findsNothing);
    },
  );

  testWidgets('mutación Failure self-upgrade avisa con copy específico', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const MembersLoaded(items: <Member>[_worker]));
    whenListen(
      mutation,
      Stream<MemberMutationState>.fromIterable(const <MemberMutationState>[
        MemberMutationInProgress(),
        MemberMutationFailure(MembersSelfRoleUpgradeFailure()),
      ]),
      initialState: const MemberMutationIdle(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('No puedes ascender tu propio rol'), findsOneWidget);
    // Un fallo NO recarga la lista (no hubo cambio que reflejar).
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('mutación Failure sole-owner avisa con copy específico', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const MembersLoaded(items: <Member>[_owner]));
    whenListen(
      mutation,
      Stream<MemberMutationState>.fromIterable(const <MemberMutationState>[
        MemberMutationInProgress(),
        MemberMutationFailure(MembersSoleOwnerFailure()),
      ]),
      initialState: const MemberMutationIdle(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(
      find.text('La organización necesita al menos un propietario'),
      findsOneWidget,
    );
  });
}
