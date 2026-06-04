import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:ataulfo/features/bots/domain/repositories/bots_repository.dart';
import 'package:ataulfo/features/members/domain/failures/members_failure.dart';
import 'package:ataulfo/features/members/domain/repositories/members_repository.dart';
import 'package:ataulfo/features/members/presentation/bloc/assign_bots_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMembersRepo extends Mock implements MembersRepository {}

class _MockBotsRepo extends Mock implements BotsRepository {}

Bot _bot(String id, String name) => Bot(
  id: id,
  orgId: 'o1',
  templateId: 't1',
  name: name,
  channel: BotChannel.waUnofficial,
  identifier: null,
  version: 1,
  paused: false,
  aiDisabled: false,
);

final _bots = <Bot>[_bot('b1', 'Uno'), _bot('b2', 'Dos'), _bot('b3', 'Tres')];

AssignBotsCubit _build({
  required MembersRepository members,
  required BotsRepository bots,
}) => AssignBotsCubit(membershipId: 'm1', membersRepo: members, botsRepo: bots);

void main() {
  group('AssignBotsCubit', () {
    test('estado inicial = AssignBotsLoading', () {
      expect(
        _build(members: _MockMembersRepo(), bots: _MockBotsRepo()).state,
        const AssignBotsLoading(),
      );
    });

    blocTest<AssignBotsCubit, AssignBotsState>(
      'load OK → Ready con los bots de la org y la selección actual',
      build: () {
        final members = _MockMembersRepo();
        final bots = _MockBotsRepo();
        when(bots.list).thenAnswer((_) async => _bots);
        when(
          () => members.assignedBots('m1'),
        ).thenAnswer((_) async => <String>['b2']);
        return _build(members: members, bots: bots);
      },
      act: (cubit) => cubit.load(),
      expect: () => <AssignBotsState>[
        const AssignBotsLoading(),
        AssignBotsReady(bots: _bots, selected: const <String>{'b2'}),
      ],
    );

    blocTest<AssignBotsCubit, AssignBotsState>(
      'load falla (BotsFailure del listado) → Failed(load)',
      build: () {
        final members = _MockMembersRepo();
        final bots = _MockBotsRepo();
        when(bots.list).thenThrow(const BotsNetworkFailure());
        when(
          () => members.assignedBots(any()),
        ).thenAnswer((_) async => const <String>[]);
        return _build(members: members, bots: bots);
      },
      act: (cubit) => cubit.load(),
      expect: () => const <AssignBotsState>[
        AssignBotsLoading(),
        AssignBotsFailed(AssignBotsPhase.load),
      ],
    );

    blocTest<AssignBotsCubit, AssignBotsState>(
      'load falla (MembersFailure del GET de asignados) → Failed(load)',
      build: () {
        final members = _MockMembersRepo();
        final bots = _MockBotsRepo();
        when(bots.list).thenAnswer((_) async => _bots);
        when(
          () => members.assignedBots(any()),
        ).thenThrow(const MembersForbiddenFailure());
        return _build(members: members, bots: bots);
      },
      act: (cubit) => cubit.load(),
      expect: () => const <AssignBotsState>[
        AssignBotsLoading(),
        AssignBotsFailed(AssignBotsPhase.load),
      ],
    );

    blocTest<AssignBotsCubit, AssignBotsState>(
      'toggle agrega y quita de la selección',
      build: () {
        final members = _MockMembersRepo();
        final bots = _MockBotsRepo();
        when(bots.list).thenAnswer((_) async => _bots);
        when(
          () => members.assignedBots('m1'),
        ).thenAnswer((_) async => const <String>[]);
        return _build(members: members, bots: bots);
      },
      act: (cubit) async {
        await cubit.load();
        cubit
          ..toggle('b1')
          ..toggle('b3')
          ..toggle('b1');
      },
      expect: () => <AssignBotsState>[
        const AssignBotsLoading(),
        AssignBotsReady(bots: _bots, selected: const <String>{}),
        AssignBotsReady(bots: _bots, selected: const <String>{'b1'}),
        AssignBotsReady(bots: _bots, selected: const <String>{'b1', 'b3'}),
        AssignBotsReady(bots: _bots, selected: const <String>{'b3'}),
      ],
    );

    blocTest<AssignBotsCubit, AssignBotsState>(
      'save OK envía el set completo seleccionado → Saved',
      build: () {
        final members = _MockMembersRepo();
        final bots = _MockBotsRepo();
        when(bots.list).thenAnswer((_) async => _bots);
        when(
          () => members.assignedBots('m1'),
        ).thenAnswer((_) async => <String>['b2']);
        when(() => members.assignBots(any(), any())).thenAnswer((_) async {});
        return _build(members: members, bots: bots);
      },
      act: (cubit) async {
        await cubit.load();
        cubit.toggle('b1');
        await cubit.save();
      },
      verify: (_) {},
      expect: () => <AssignBotsState>[
        const AssignBotsLoading(),
        AssignBotsReady(bots: _bots, selected: const <String>{'b2'}),
        AssignBotsReady(bots: _bots, selected: const <String>{'b2', 'b1'}),
        const AssignBotsSaving(),
        const AssignBotsSaved(),
      ],
    );

    blocTest<AssignBotsCubit, AssignBotsState>(
      'save falla → Failed(save)',
      build: () {
        final members = _MockMembersRepo();
        final bots = _MockBotsRepo();
        when(bots.list).thenAnswer((_) async => _bots);
        when(
          () => members.assignedBots('m1'),
        ).thenAnswer((_) async => const <String>[]);
        when(
          () => members.assignBots(any(), any()),
        ).thenThrow(const MembersNotFoundFailure());
        return _build(members: members, bots: bots);
      },
      act: (cubit) async {
        await cubit.load();
        await cubit.save();
      },
      expect: () => <AssignBotsState>[
        const AssignBotsLoading(),
        AssignBotsReady(bots: _bots, selected: const <String>{}),
        const AssignBotsSaving(),
        const AssignBotsFailed(AssignBotsPhase.save),
      ],
    );

    blocTest<AssignBotsCubit, AssignBotsState>(
      'backToEditing tras un fallo de guardado vuelve a Ready conservando la '
      'selección (el operador reintenta sin perder lo elegido)',
      build: () {
        final members = _MockMembersRepo();
        final bots = _MockBotsRepo();
        when(bots.list).thenAnswer((_) async => _bots);
        when(
          () => members.assignedBots('m1'),
        ).thenAnswer((_) async => const <String>[]);
        when(
          () => members.assignBots(any(), any()),
        ).thenThrow(const MembersServerFailure());
        return _build(members: members, bots: bots);
      },
      act: (cubit) async {
        await cubit.load();
        cubit.toggle('b1');
        await cubit.save();
        cubit.backToEditing();
      },
      expect: () => <AssignBotsState>[
        const AssignBotsLoading(),
        AssignBotsReady(bots: _bots, selected: const <String>{}),
        AssignBotsReady(bots: _bots, selected: const <String>{'b1'}),
        const AssignBotsSaving(),
        const AssignBotsFailed(AssignBotsPhase.save),
        AssignBotsReady(bots: _bots, selected: const <String>{'b1'}),
      ],
    );
  });
}
