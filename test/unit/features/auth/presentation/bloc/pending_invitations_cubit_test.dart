import 'dart:async';

import 'package:ataulfo/features/auth/domain/entities/accepted_invitation.dart';
import 'package:ataulfo/features/auth/domain/entities/pending_invitation.dart';
import 'package:ataulfo/features/auth/domain/failures/auth_failure.dart';
import 'package:ataulfo/features/auth/domain/repositories/auth_repository.dart';
import 'package:ataulfo/features/auth/presentation/bloc/pending_invitations_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AuthRepository {}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  const inv = PendingInvitation(
    id: 'inv-1',
    orgId: 'o-9',
    orgName: 'Acme',
    role: 'WORKER',
  );

  group('PendingInvitationsCubit', () {
    test('estado inicial es Loading', () {
      expect(
        PendingInvitationsCubit(repo).state,
        isA<PendingInvitationsLoading>(),
      );
    });

    blocTest<PendingInvitationsCubit, PendingInvitationsState>(
      'load OK → Ready(items)',
      build: () {
        when(
          repo.pendingInvitations,
        ).thenAnswer((_) async => const <PendingInvitation>[inv]);
        return PendingInvitationsCubit(repo);
      },
      act: (c) => c.load(),
      expect: () => const <PendingInvitationsState>[
        PendingInvitationsReady(items: <PendingInvitation>[inv]),
      ],
    );

    blocTest<PendingInvitationsCubit, PendingInvitationsState>(
      'load con fallo → Ready(vacío) (best-effort, sección oculta)',
      build: () {
        when(repo.pendingInvitations).thenThrow(const NetworkFailure());
        return PendingInvitationsCubit(repo);
      },
      act: (c) => c.load(),
      expect: () => const <PendingInvitationsState>[
        PendingInvitationsReady(items: <PendingInvitation>[]),
      ],
    );

    blocTest<PendingInvitationsCubit, PendingInvitationsState>(
      'join OK: marca joiningId, acepta, recarga y vacía la lista',
      build: () {
        when(
          repo.pendingInvitations,
        ).thenAnswer((_) async => const <PendingInvitation>[]);
        when(() => repo.acceptPendingInvitation('inv-1')).thenAnswer(
          (_) async => const AcceptedInvitation(
            orgId: 'o-9',
            orgName: 'Acme',
            role: 'WORKER',
          ),
        );
        return PendingInvitationsCubit(
          repo,
        )..emit(const PendingInvitationsReady(items: <PendingInvitation>[inv]));
      },
      act: (c) => c.join('inv-1'),
      expect: () => const <PendingInvitationsState>[
        PendingInvitationsReady(
          items: <PendingInvitation>[inv],
          joiningId: 'inv-1',
        ),
        PendingInvitationsReady(items: <PendingInvitation>[]),
      ],
    );

    test('join OK devuelve PendingJoinOk con el nombre de la org', () async {
      when(
        repo.pendingInvitations,
      ).thenAnswer((_) async => const <PendingInvitation>[]);
      when(() => repo.acceptPendingInvitation('inv-1')).thenAnswer(
        (_) async => const AcceptedInvitation(
          orgId: 'o-9',
          orgName: 'Acme',
          role: 'WORKER',
        ),
      );
      final cubit = PendingInvitationsCubit(repo)
        ..emit(const PendingInvitationsReady(items: <PendingInvitation>[inv]));

      final result = await cubit.join('inv-1');

      expect(result, isA<PendingJoinOk>());
      expect((result as PendingJoinOk).orgName, 'Acme');
    });

    test('join 403 devuelve NeedsVerification y conserva la lista', () async {
      when(
        () => repo.acceptPendingInvitation('inv-1'),
      ).thenThrow(const EmailNotVerifiedFailure());
      final cubit = PendingInvitationsCubit(repo)
        ..emit(const PendingInvitationsReady(items: <PendingInvitation>[inv]));

      final result = await cubit.join('inv-1');

      expect(result, isA<PendingJoinNeedsVerification>());
      expect(
        cubit.state,
        const PendingInvitationsReady(items: <PendingInvitation>[inv]),
      );
    });

    test(
      'join 409 devuelve AlreadyMember y recarga (fila desaparece)',
      () async {
        when(
          () => repo.acceptPendingInvitation('inv-1'),
        ).thenThrow(const AlreadyMemberFailure());
        when(
          repo.pendingInvitations,
        ).thenAnswer((_) async => const <PendingInvitation>[]);
        final cubit = PendingInvitationsCubit(
          repo,
        )..emit(const PendingInvitationsReady(items: <PendingInvitation>[inv]));

        final result = await cubit.join('inv-1');

        expect(result, isA<PendingJoinAlreadyMember>());
        verify(repo.pendingInvitations).called(1); // recargó
        expect(
          cubit.state,
          const PendingInvitationsReady(items: <PendingInvitation>[]),
        );
      },
    );

    test('join 410 devuelve Gone y recarga (fila desaparece)', () async {
      when(
        () => repo.acceptPendingInvitation('inv-1'),
      ).thenThrow(const ExpiredTokenFailure());
      when(
        repo.pendingInvitations,
      ).thenAnswer((_) async => const <PendingInvitation>[]);
      final cubit = PendingInvitationsCubit(repo)
        ..emit(const PendingInvitationsReady(items: <PendingInvitation>[inv]));

      final result = await cubit.join('inv-1');

      expect(result, isA<PendingJoinGone>());
      expect(
        cubit.state,
        const PendingInvitationsReady(items: <PendingInvitation>[]),
      );
    });

    test(
      'join fallo genérico (404/red) devuelve Failed y conserva la lista',
      () async {
        when(
          () => repo.acceptPendingInvitation('inv-1'),
        ).thenThrow(const NetworkFailure());
        final cubit = PendingInvitationsCubit(
          repo,
        )..emit(const PendingInvitationsReady(items: <PendingInvitation>[inv]));

        final result = await cubit.join('inv-1');

        expect(result, isA<PendingJoinFailed>());
        expect(
          cubit.state,
          const PendingInvitationsReady(items: <PendingInvitation>[inv]),
        );
      },
    );

    test('load tras cerrar el cubit no lanza (guarda isClosed)', () async {
      final completer = Completer<List<PendingInvitation>>();
      when(repo.pendingInvitations).thenAnswer((_) => completer.future);
      final cubit = PendingInvitationsCubit(repo);

      final f = cubit.load();
      await cubit.close();
      completer.complete(const <PendingInvitation>[inv]);

      await expectLater(f, completes);
    });

    test('join tras cerrar el cubit no lanza (guarda isClosed)', () async {
      final completer = Completer<AcceptedInvitation>();
      when(
        () => repo.acceptPendingInvitation('inv-1'),
      ).thenAnswer((_) => completer.future);
      final cubit = PendingInvitationsCubit(repo)
        ..emit(const PendingInvitationsReady(items: <PendingInvitation>[inv]));

      final f = cubit.join('inv-1');
      await cubit.close();
      completer.complete(
        const AcceptedInvitation(orgId: 'o-9', orgName: 'Acme', role: 'WORKER'),
      );

      await expectLater(f, completes);
    });
  });
}
