import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_avatar.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/profile/domain/entities/chat_profile.dart';
import 'package:ataulfo/features/profile/domain/failures/profile_failure.dart';
import 'package:ataulfo/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:ataulfo/features/profile/presentation/pages/profile_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

const _dm = ChatProfile(
  chatLid: 'lid-dm',
  isGroup: false,
  phone: '521555',
  displayName: 'Alice',
  photoUrl: null,
  isArchived: false,
  isPinned: true,
  isMarkedUnread: false,
  mutedUntil: null,
);

void main() {
  setUpAll(() => registerFallbackValue(const ProfileLoadRequested()));

  late _MockProfileBloc bloc;
  setUp(() {
    bloc = _MockProfileBloc();
    when(() => bloc.state).thenReturn(const ProfileInitial());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<ProfileBloc>.value(
      value: bloc,
      child: const Scaffold(body: ProfilePage()),
    ),
  );

  testWidgets('Loading → spinner', (tester) async {
    when(() => bloc.state).thenReturn(const ProfileLoading());
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('profile.loading')), findsOneWidget);
  });

  testWidgets('Loaded → avatar, nombre, phone y pill de app-state', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const ProfileLoaded(_dm));
    await tester.pumpWidget(host());
    expect(find.byType(AppAvatar), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('521555'), findsOneWidget);
    expect(find.widgetWithText(AppPill, 'Fijado'), findsOneWidget);
  });

  testWidgets('Failed NotFound → copy específico', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const ProfileFailed(ProfileNotFoundFailure()));
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('profile.error.not_found')), findsOneWidget);
  });

  testWidgets('Failed genérico → Reintentar dispara ProfileLoadRequested', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const ProfileFailed(ProfileNetworkFailure()));
    await tester.pumpWidget(host());
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    await tester.pump();
    verify(() => bloc.add(const ProfileLoadRequested())).called(1);
  });
}
