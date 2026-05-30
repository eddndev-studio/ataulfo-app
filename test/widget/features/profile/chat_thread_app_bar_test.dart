import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_avatar.dart';
import 'package:ataulfo/features/profile/domain/entities/chat_profile.dart';
import 'package:ataulfo/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:ataulfo/features/profile/presentation/widgets/chat_thread_app_bar.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

void main() {
  late _MockProfileBloc bloc;
  setUp(() {
    bloc = _MockProfileBloc();
    when(() => bloc.state).thenReturn(const ProfileInitial());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<ProfileBloc>.value(
      value: bloc,
      child: const Scaffold(
        appBar: ChatThreadAppBar(botId: 'b1', chatLid: 'lid-dm'),
        body: SizedBox.shrink(),
      ),
    ),
  );

  testWidgets('cargado muestra el nombre real + avatar', (tester) async {
    when(() => bloc.state).thenReturn(
      const ProfileLoaded(
        ChatProfile(
          chatLid: 'lid-dm',
          isGroup: false,
          phone: '521555',
          displayName: 'Alice',
          photoUrl: null,
          isArchived: false,
          isPinned: false,
          isMarkedUnread: false,
          mutedUntil: null,
        ),
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('Alice'), findsOneWidget);
    expect(find.byType(AppAvatar), findsOneWidget);
  });

  testWidgets('mientras carga cae al chatLid (no bloquea el header)', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const ProfileLoading());
    await tester.pumpWidget(host());
    expect(find.text('lid-dm'), findsOneWidget);
  });

  testWidgets('el header es tappable (InkWell para abrir el perfil)', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const ProfileLoading());
    await tester.pumpWidget(host());
    expect(find.byType(InkWell), findsOneWidget);
  });
}
