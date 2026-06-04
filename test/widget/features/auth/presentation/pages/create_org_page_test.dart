import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/auth/domain/failures/auth_failure.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/auth/presentation/bloc/create_org_cubit.dart';
import 'package:ataulfo/features/auth/presentation/pages/create_org_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockCreateOrgCubit extends MockCubit<CreateOrgState>
    implements CreateOrgCubit {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(const AuthCheckRequested());
  });

  late _MockCreateOrgCubit cubit;
  late _MockAuthBloc auth;

  setUp(() {
    cubit = _MockCreateOrgCubit();
    auth = _MockAuthBloc();
    when(() => cubit.state).thenReturn(const CreateOrgIdle());
    when(() => cubit.create(any())).thenAnswer((_) async {});
    when(() => auth.state).thenReturn(const AuthInitial());
  });

  Widget host() => MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/create-org',
      routes: <RouteBase>[
        GoRoute(
          path: '/create-org',
          builder: (_, _) => MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<CreateOrgCubit>.value(value: cubit),
              BlocProvider<AuthBloc>.value(value: auth),
            ],
            child: const Scaffold(body: CreateOrgPage()),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('HOME')),
        ),
      ],
    ),
  );

  testWidgets('muestra el campo de nombre y el botón crear', (tester) async {
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('create_org.name')), findsOneWidget);
    expect(find.byKey(const Key('create_org.submit')), findsOneWidget);
  });

  testWidgets('Crear está deshabilitado con el nombre vacío', (tester) async {
    await tester.pumpWidget(host());

    final submit = tester.widget<AppButton>(
      find.byKey(const Key('create_org.submit')),
    );
    expect(submit.onPressed, isNull);
  });

  testWidgets('con nombre, crear despacha create(name) recortado', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.enterText(find.byKey(const Key('create_org.name')), '  Acme  ');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create_org.submit')));
    await tester.pump();

    verify(() => cubit.create('Acme')).called(1);
  });

  testWidgets('Created flipa la sesión (AuthCheckRequested) y va a /home', (
    tester,
  ) async {
    whenListen(
      cubit,
      Stream<CreateOrgState>.fromIterable(const <CreateOrgState>[
        CreateOrgCreating(),
        CreateOrgCreated(),
      ]),
      initialState: const CreateOrgIdle(),
    );

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    verify(() => auth.add(const AuthCheckRequested())).called(1);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('Failed muestra aviso de error', (tester) async {
    whenListen(
      cubit,
      Stream<CreateOrgState>.fromIterable(const <CreateOrgState>[
        CreateOrgCreating(),
        CreateOrgFailed(NetworkFailure()),
      ]),
      initialState: const CreateOrgIdle(),
    );

    await tester.pumpWidget(host());
    await tester.pump();

    expect(
      find.text('Sin conexión. Revisa tu red e inténtalo de nuevo.'),
      findsOneWidget,
    );
  });
}
