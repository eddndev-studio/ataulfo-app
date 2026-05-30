import 'package:ataulfo/features/profile/domain/entities/chat_profile.dart';
import 'package:ataulfo/features/profile/domain/failures/profile_failure.dart';
import 'package:ataulfo/features/profile/domain/repositories/profile_repository.dart';
import 'package:ataulfo/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements ProfileRepository {}

const _profile = ChatProfile(
  chatLid: 'lid-1',
  isGroup: false,
  phone: '521555',
  displayName: 'Alice',
  photoUrl: 'https://cdn/p.jpg',
  isArchived: false,
  isPinned: false,
  isMarkedUnread: false,
  mutedUntil: null,
);

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  ProfileBloc build() => ProfileBloc(repo: repo, botId: 'b1', chatLid: 'lid-1');

  blocTest<ProfileBloc, ProfileState>(
    'load OK → [Loading, Loaded]',
    setUp: () =>
        when(() => repo.fetch('b1', 'lid-1')).thenAnswer((_) async => _profile),
    build: build,
    act: (b) => b.add(const ProfileLoadRequested()),
    expect: () => <ProfileState>[
      const ProfileLoading(),
      const ProfileLoaded(_profile),
    ],
  );

  blocTest<ProfileBloc, ProfileState>(
    'load falla → [Loading, Failed]',
    setUp: () => when(
      () => repo.fetch('b1', 'lid-1'),
    ).thenThrow(const ProfileNotFoundFailure()),
    build: build,
    act: (b) => b.add(const ProfileLoadRequested()),
    expect: () => <ProfileState>[
      const ProfileLoading(),
      const ProfileFailed(ProfileNotFoundFailure()),
    ],
  );
}
