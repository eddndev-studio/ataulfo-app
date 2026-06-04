import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/auth/presentation/bloc/resend_verification_cubit.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bots_bloc.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/presentation/bloc/labels_admin_bloc.dart';
import 'package:ataulfo/features/shell/presentation/pages/shell_page.dart';
import 'package:ataulfo/features/shell/presentation/widgets/email_verification_banner.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:ataulfo/features/templates/presentation/bloc/templates_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockBotsBloc extends MockBloc<BotsEvent, BotsState>
    implements BotsBloc {}

class _MockTemplatesBloc extends MockBloc<TemplatesEvent, TemplatesState>
    implements TemplatesBloc {}

class _MockLabelsAdminBloc extends MockBloc<LabelsAdminEvent, LabelsAdminState>
    implements LabelsAdminBloc {}

class _MockResendCubit extends MockBloc<Object, ResendVerificationState>
    implements ResendVerificationCubit {}

const _unverified = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
);

const _verified = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
  emailVerified: true,
);

void main() {
  late _MockAuthBloc authBloc;
  late _MockBotsBloc botsBloc;
  late _MockTemplatesBloc templatesBloc;
  late _MockLabelsAdminBloc labelsBloc;
  late _MockResendCubit resendCubit;

  setUp(() {
    authBloc = _MockAuthBloc();
    botsBloc = _MockBotsBloc();
    templatesBloc = _MockTemplatesBloc();
    labelsBloc = _MockLabelsAdminBloc();
    resendCubit = _MockResendCubit();
    when(() => resendCubit.state).thenReturn(const ResendVerificationIdle());
    when(() => labelsBloc.state).thenReturn(
      const LabelsAdminLoaded(labels: <Label>[], isRefreshing: false),
    );
    when(
      () => botsBloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[], isRefreshing: false));
    when(() => templatesBloc.state).thenReturn(
      const TemplatesLoaded(items: <Template>[], isRefreshing: false),
    );
  });

  Widget host() => MultiBlocProvider(
    providers: <BlocProvider<dynamic>>[
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<BotsBloc>.value(value: botsBloc),
      BlocProvider<TemplatesBloc>.value(value: templatesBloc),
      BlocProvider<LabelsAdminBloc>.value(value: labelsBloc),
      BlocProvider<ResendVerificationCubit>.value(value: resendCubit),
    ],
    child: const MaterialApp(home: ShellPage()),
  );

  testWidgets('email NO verificado: el shell muestra el aviso sobre los tabs', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_unverified));

    await tester.pumpWidget(host());

    expect(find.byType(EmailVerificationBanner), findsOneWidget);
    expect(find.text('Verifica tu correo'), findsOneWidget);
  });

  testWidgets('email verificado: el shell NO muestra texto del aviso', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_verified));

    await tester.pumpWidget(host());

    // El widget puede montarse (decide visibilidad por estado) pero su copy
    // no debe pintarse cuando el correo ya está verificado.
    expect(find.text('Verifica tu correo'), findsNothing);
  });
}
