import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/domain/entities/pending_invitation.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/auth/presentation/bloc/pending_invitations_cubit.dart';
import 'package:ataulfo/features/memberships/presentation/bloc/memberships_bloc.dart';
import 'package:ataulfo/features/memberships/presentation/widgets/pending_invitations_section.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockPendingCubit extends MockCubit<PendingInvitationsState>
    implements PendingInvitationsCubit {}

class _MockMembershipsBloc extends MockBloc<MembershipsEvent, MembershipsState>
    implements MembershipsBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

const _inv = PendingInvitation(
  id: 'inv-1',
  orgId: 'o-9',
  orgName: 'Acme',
  role: 'WORKER',
);

const _identity = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
);

void main() {
  setUpAll(() {
    registerFallbackValue(const MembershipsLoadRequested());
  });

  late _MockPendingCubit pending;
  late _MockMembershipsBloc memberships;

  setUp(() {
    pending = _MockPendingCubit();
    memberships = _MockMembershipsBloc();
    when(() => memberships.state).thenReturn(const MembershipsInitial());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(
      body: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<PendingInvitationsCubit>.value(value: pending),
          BlocProvider<MembershipsBloc>.value(value: memberships),
        ],
        child: const PendingInvitationsSection(),
      ),
    ),
  );

  testWidgets('Loading: la sección se oculta', (tester) async {
    when(() => pending.state).thenReturn(const PendingInvitationsLoading());

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('memberships.pending_section')), findsNothing);
  });

  testWidgets('Ready vacío: la sección se oculta', (tester) async {
    when(
      () => pending.state,
    ).thenReturn(const PendingInvitationsReady(items: <PendingInvitation>[]));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('memberships.pending_section')), findsNothing);
  });

  testWidgets('Ready con items: pinta header, org, rol y botón Unirse', (
    tester,
  ) async {
    when(() => pending.state).thenReturn(
      const PendingInvitationsReady(items: <PendingInvitation>[_inv]),
    );

    await tester.pumpWidget(host());

    expect(
      find.byKey(const Key('memberships.pending_section')),
      findsOneWidget,
    );
    expect(find.text('Invitaciones pendientes'), findsOneWidget);
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('Agente'), findsOneWidget); // roleLabel(WORKER)
    expect(
      find.byKey(const Key('memberships.pending.join.inv-1')),
      findsOneWidget,
    );
  });

  testWidgets('joiningId marca el botón de esa fila en loading', (
    tester,
  ) async {
    when(() => pending.state).thenReturn(
      const PendingInvitationsReady(
        items: <PendingInvitation>[_inv],
        joiningId: 'inv-1',
      ),
    );

    await tester.pumpWidget(host());

    final button = tester.widget<AppButton>(
      find.byKey(const Key('memberships.pending.join.inv-1')),
    );
    expect(button.loading, isTrue);
  });

  testWidgets('Unirse OK: avisa y recarga memberships', (tester) async {
    when(() => pending.state).thenReturn(
      const PendingInvitationsReady(items: <PendingInvitation>[_inv]),
    );
    when(
      () => pending.join('inv-1'),
    ).thenAnswer((_) async => const PendingJoinOk(orgName: 'Acme'));

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('memberships.pending.join.inv-1')));
    await tester.pump();

    verify(() => pending.join('inv-1')).called(1);
    verify(() => memberships.add(const MembershipsLoadRequested())).called(1);
    expect(find.text('Ya eres parte de Acme'), findsOneWidget);
  });

  testWidgets('Unirse con fallo genérico: avisa sin recargar memberships', (
    tester,
  ) async {
    when(() => pending.state).thenReturn(
      const PendingInvitationsReady(items: <PendingInvitation>[_inv]),
    );
    when(
      () => pending.join('inv-1'),
    ).thenAnswer((_) async => const PendingJoinFailed());

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('memberships.pending.join.inv-1')));
    await tester.pump();

    expect(find.text('No pudimos unirte, reintenta'), findsOneWidget);
    verifyNever(() => memberships.add(any()));
  });

  testWidgets('AlreadyMember: avisa "ya eres parte" y recarga memberships', (
    tester,
  ) async {
    when(() => pending.state).thenReturn(
      const PendingInvitationsReady(items: <PendingInvitation>[_inv]),
    );
    when(
      () => pending.join('inv-1'),
    ).thenAnswer((_) async => const PendingJoinAlreadyMember());

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('memberships.pending.join.inv-1')));
    await tester.pump();

    expect(find.text('Ya eres parte de esta organización'), findsOneWidget);
    verify(() => memberships.add(const MembershipsLoadRequested())).called(1);
  });

  testWidgets('Gone: avisa "ya no está disponible" sin recargar', (
    tester,
  ) async {
    when(() => pending.state).thenReturn(
      const PendingInvitationsReady(items: <PendingInvitation>[_inv]),
    );
    when(
      () => pending.join('inv-1'),
    ).thenAnswer((_) async => const PendingJoinGone());

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('memberships.pending.join.inv-1')));
    await tester.pump();

    expect(find.text('La invitación ya no está disponible'), findsOneWidget);
    verifyNever(() => memberships.add(any()));
  });

  testWidgets('muchas invitaciones NO desbordan (alto acotado + scroll)', (
    tester,
  ) async {
    // Sin el tope de alto + scroll interno, una Column de N tarjetas desborda
    // la pantalla. Con el fix, la sección se acota y hace scroll: no hay
    // excepción de overflow y la lista es scrolleable.
    final many = <PendingInvitation>[
      for (var i = 0; i < 12; i++)
        PendingInvitation(
          id: 'inv-$i',
          orgId: 'o-$i',
          orgName: 'Org $i',
          role: 'WORKER',
        ),
    ];
    when(() => pending.state).thenReturn(PendingInvitationsReady(items: many));

    await tester.pumpWidget(host());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byKey(const Key('memberships.pending_section')),
        matching: find.byType(Scrollable),
      ),
      findsWidgets,
    );
  });

  testWidgets(
    'NeedsVerification: avisa y "Verificar" navega a /verify-email con email',
    (tester) async {
      final navigated = <String>[];
      final auth = _MockAuthBloc();
      when(() => auth.state).thenReturn(const AuthAuthenticated(_identity));
      when(() => pending.state).thenReturn(
        const PendingInvitationsReady(items: <PendingInvitation>[_inv]),
      );
      when(
        () => pending.join('inv-1'),
      ).thenAnswer((_) async => const PendingJoinNeedsVerification());

      final router = GoRouter(
        initialLocation: '/memberships',
        routes: <RouteBase>[
          GoRoute(
            path: '/memberships',
            builder: (_, _) => MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<PendingInvitationsCubit>.value(value: pending),
                BlocProvider<MembershipsBloc>.value(value: memberships),
                BlocProvider<AuthBloc>.value(value: auth),
              ],
              child: const Scaffold(body: PendingInvitationsSection()),
            ),
          ),
          GoRoute(
            path: '/verify-email',
            builder: (_, state) {
              navigated.add(state.uri.toString());
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: AppDesignTheme.dark(), routerConfig: router),
      );
      await tester.tap(find.byKey(const Key('memberships.pending.join.inv-1')));
      await tester.pump(); // completa el join (mock) y programa el SnackBar
      await tester.pump(const Duration(milliseconds: 750)); // el SnackBar entra

      expect(find.text('Verifica tu correo primero'), findsOneWidget);

      await tester.tap(find.text('Verificar'));
      await tester.pumpAndSettle();

      expect(navigated, <String>['/verify-email?email=op%40example.com']);
    },
  );
}
