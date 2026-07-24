import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bots_bloc.dart';
import 'package:ataulfo/features/invitations/domain/entities/created_invitation.dart';
import 'package:ataulfo/features/invitations/domain/entities/invitation.dart';
import 'package:ataulfo/features/invitations/domain/failures/invitations_failure.dart';
import 'package:ataulfo/features/invitations/domain/repositories/invitations_repository.dart';
import 'package:ataulfo/features/invitations/presentation/bloc/invitation_mutation_cubit.dart';
import 'package:ataulfo/features/invitations/presentation/bloc/invitations_bloc.dart';
import 'package:ataulfo/features/invitations/presentation/pages/invitations_page.dart';
import 'package:ataulfo/features/invitations/presentation/widgets/invitation_tile.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockInvitationsBloc extends MockBloc<InvitationsEvent, InvitationsState>
    implements InvitationsBloc {}

class _MockInvitationMutationCubit extends MockCubit<InvitationMutationState>
    implements InvitationMutationCubit {}

class _MockBotsBloc extends MockBloc<BotsEvent, BotsState>
    implements BotsBloc {}

class _MockInvitationsRepo extends Mock implements InvitationsRepository {}

const _bot = Bot(
  id: 'b1',
  orgId: 'o1',
  templateId: 't1',
  name: 'Ventas',
  channel: BotChannel.waba,
  identifier: null,
  version: 1,
  paused: false,
  aiDisabled: false,
);

Invitation _pending({String id = 'i1', String email = 'a@x.com'}) => Invitation(
  id: id,
  email: email,
  role: 'WORKER',
  status: 'PENDING',
  expiresAt: DateTime.utc(2100, 1, 1),
  createdAt: DateTime.utc(2026, 5, 25),
);

final _accepted = Invitation(
  id: 'i2',
  email: 'b@x.com',
  role: 'ADMIN',
  status: 'ACCEPTED',
  expiresAt: DateTime.utc(2100, 1, 1),
  createdAt: DateTime.utc(2026, 5, 24),
);

void main() {
  setUpAll(() {
    registerFallbackValue(const InvitationsLoadRequested());
  });

  late _MockInvitationsBloc bloc;
  late _MockInvitationMutationCubit mutation;
  late _MockBotsBloc botsBloc;
  late _MockInvitationsRepo repo;

  setUp(() {
    bloc = _MockInvitationsBloc();
    mutation = _MockInvitationMutationCubit();
    botsBloc = _MockBotsBloc();
    repo = _MockInvitationsRepo();
    when(() => bloc.state).thenReturn(const InvitationsInitial());
    when(() => mutation.state).thenReturn(const InvitationMutationIdle());
    when(
      () => botsBloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[_bot], isRefreshing: false));
    when(() => mutation.cancel(any())).thenAnswer((_) async {});
    when(() => repo.create(any(), any(), any())).thenAnswer(
      (invocation) async => CreatedInvitation(
        email: invocation.positionalArguments.first as String,
        token: 'RAW-SHARE',
        emailSent: true,
      ),
    );
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: RepositoryProvider<InvitationsRepository>.value(
      value: repo,
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<InvitationsBloc>.value(value: bloc),
          BlocProvider<InvitationMutationCubit>.value(value: mutation),
          BlocProvider<BotsBloc>.value(value: botsBloc),
        ],
        child: const Scaffold(body: InvitationsPage()),
      ),
    ),
  );

  testWidgets('Loading muestra spinner y conserva el botón Invitar', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const InvitationsLoading());

    await tester.pumpWidget(host());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('invitations.invite')), findsOneWidget);
  });

  testWidgets('Loaded renderiza una InvitationTile por invitación', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(InvitationsLoaded(items: <Invitation>[_pending(), _accepted]));

    await tester.pumpWidget(host());

    expect(find.byType(InvitationTile), findsNWidgets(2));
  });

  testWidgets('Loaded vacío muestra copy y CONSERVA el botón Invitar '
      '(no es un callejón sin salida)', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const InvitationsLoaded(items: <Invitation>[]));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('invitations.empty')), findsOneWidget);
    expect(find.byKey(const Key('invitations.invite')), findsOneWidget);
  });

  testWidgets('Failed muestra error y Reintentar', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const InvitationsFailed(InvitationsServerFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('invitations.error')), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Reintentar'), findsOneWidget);
  });

  testWidgets('crear permanece en la hoja, muestra éxito y luego recarga', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const InvitationsLoaded(items: <Invitation>[]));

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('invitations.invite')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('invite.email')), 'new@x.com');
    await tester.pump();
    await tester.tap(find.byKey(const Key('invite.continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite.submit')));
    await tester.pumpAndSettle();

    expect(find.text('Invitación creada'), findsOneWidget);
    verify(
      () => repo.create('new@x.com', 'WORKER', const <String>[]),
    ).called(1);
    verifyNever(() => mutation.create(any(), any(), any()));

    final done = find.byKey(const Key('invitation_share.done'));
    await tester.ensureVisible(done);
    await tester.pumpAndSettle();
    await tester.tap(done);
    await tester.pumpAndSettle();

    verify(() => bloc.add(const InvitationsLoadRequested())).called(1);
  });

  testWidgets('cancelar una PENDING (confirmado) despacha cancel', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(InvitationsLoaded(items: <Invitation>[_pending()]));

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('invitation_tile.cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invitations.cancel_confirm')));
    await tester.pumpAndSettle();

    verify(() => mutation.cancel('i1')).called(1);
  });

  testWidgets('las terminales (ACCEPTED) no ofrecen cancelar', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(InvitationsLoaded(items: <Invitation>[_accepted]));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('invitation_tile.cancel')), findsNothing);
  });

  testWidgets('Success(canceled) recarga y avisa', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(InvitationsLoaded(items: <Invitation>[_pending()]));
    whenListen(
      mutation,
      Stream<InvitationMutationState>.fromIterable(
        const <InvitationMutationState>[
          InvitationMutationInProgress(),
          InvitationMutationSuccess(InvitationMutationAction.canceled),
        ],
      ),
      initialState: const InvitationMutationIdle(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    verify(() => bloc.add(const InvitationsLoadRequested())).called(1);
    expect(find.text('Invitación cancelada'), findsOneWidget);
  });

  testWidgets('Failure(Duplicate) avisa y NO recarga (no cambió el servidor)', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const InvitationsLoaded(items: <Invitation>[]));
    whenListen(
      mutation,
      Stream<InvitationMutationState>.fromIterable(
        const <InvitationMutationState>[
          InvitationMutationInProgress(),
          InvitationMutationFailure(InvitationsDuplicateFailure()),
        ],
      ),
      initialState: const InvitationMutationIdle(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(
      find.text(
        'Ya hay una invitación pendiente para ese correo; '
        'cancélala para reinvitar.',
      ),
      findsOneWidget,
    );
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('Failure(Server) recarga por seguridad y muestra el copy', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const InvitationsLoaded(items: <Invitation>[]));
    whenListen(
      mutation,
      Stream<InvitationMutationState>.fromIterable(
        const <InvitationMutationState>[
          InvitationMutationInProgress(),
          InvitationMutationFailure(InvitationsServerFailure()),
        ],
      ),
      initialState: const InvitationMutationIdle(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    verify(() => bloc.add(const InvitationsLoadRequested())).called(1);
    expect(
      find.text('No pudimos confirmar la operación; revisa el historial.'),
      findsOneWidget,
    );
  });

  testWidgets('Failure(Gone) avisa y recarga (la lista local quedó stale)', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(InvitationsLoaded(items: <Invitation>[_pending()]));
    whenListen(
      mutation,
      Stream<InvitationMutationState>.fromIterable(
        const <InvitationMutationState>[
          InvitationMutationInProgress(),
          InvitationMutationFailure(InvitationsGoneFailure()),
        ],
      ),
      initialState: const InvitationMutationIdle(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    verify(() => bloc.add(const InvitationsLoadRequested())).called(1);
    expect(
      find.text('Esa invitación ya no se puede cancelar.'),
      findsOneWidget,
    );
  });
}
