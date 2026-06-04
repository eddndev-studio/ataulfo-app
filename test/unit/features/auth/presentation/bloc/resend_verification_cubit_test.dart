import 'package:ataulfo/features/auth/domain/failures/auth_failure.dart';
import 'package:ataulfo/features/auth/domain/repositories/auth_repository.dart';
import 'package:ataulfo/features/auth/presentation/bloc/resend_verification_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AuthRepository {}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  group('ResendVerificationCubit', () {
    test('estado inicial es ResendVerificationIdle', () {
      expect(
        ResendVerificationCubit(repo).state,
        const ResendVerificationIdle(),
      );
    });

    blocTest<ResendVerificationCubit, ResendVerificationState>(
      'OK: Sending → Sent y llama a resendVerification una vez',
      build: () {
        when(() => repo.resendVerification()).thenAnswer((_) async {});
        return ResendVerificationCubit(repo);
      },
      act: (c) => c.resend(),
      expect: () => const <ResendVerificationState>[
        ResendVerificationSending(),
        ResendVerificationSent(),
      ],
      verify: (_) {
        verify(() => repo.resendVerification()).called(1);
      },
    );

    blocTest<ResendVerificationCubit, ResendVerificationState>(
      'fallo del backend: Sending → Failed',
      build: () {
        when(() => repo.resendVerification()).thenThrow(const NetworkFailure());
        return ResendVerificationCubit(repo);
      },
      act: (c) => c.resend(),
      expect: () => const <ResendVerificationState>[
        ResendVerificationSending(),
        ResendVerificationFailed(),
      ],
    );
  });
}
