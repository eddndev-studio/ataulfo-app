import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/members/domain/entities/member.dart';
import 'package:ataulfo/features/members/domain/failures/members_failure.dart';
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

void main() {
  setUpAll(() {
    registerFallbackValue(const MembersLoadRequested());
  });

  late _MockMembersBloc bloc;

  setUp(() {
    bloc = _MockMembersBloc();
    when(() => bloc.state).thenReturn(const MembersInitial());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<MembersBloc>.value(
      value: bloc,
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
    when(
      () => bloc.state,
    ).thenReturn(const MembersLoaded(items: <Member>[]));

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
}
