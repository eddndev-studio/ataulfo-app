import 'package:ataulfo/features/auth/domain/failures/auth_failure.dart';
import 'package:ataulfo/features/auth/domain/repositories/auth_repository.dart';
import 'package:ataulfo/features/auth/presentation/bloc/forgot_password_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AuthRepository {}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  group('ForgotPasswordBloc', () {
    test('estado inicial es ForgotPasswordInitial', () {
      expect(ForgotPasswordBloc(repo).state, const ForgotPasswordInitial());
    });

    blocTest<ForgotPasswordBloc, ForgotPasswordState>(
      'OK: Submitting → Sent y llama a forgotPassword una vez',
      build: () {
        when(() => repo.forgotPassword('op@x.com')).thenAnswer((_) async {});
        return ForgotPasswordBloc(repo);
      },
      act: (b) =>
          b.add(const ForgotPasswordSubmitted(email: 'op@x.com')),
      expect: () => const <ForgotPasswordState>[
        ForgotPasswordSubmitting(),
        ForgotPasswordSent(),
      ],
      verify: (_) {
        verify(() => repo.forgotPassword('op@x.com')).called(1);
      },
    );

    blocTest<ForgotPasswordBloc, ForgotPasswordState>(
      'cuenta inexistente (backend siempre 202): igualmente → Sent',
      build: () {
        // El backend NO distingue cuenta existente vs. inexistente (anti
        // enumeración): devuelve 202 siempre. El bloc espeja eso — Sent
        // pase lo que pase, sin filtrar la existencia de la cuenta.
        when(() => repo.forgotPassword(any())).thenAnswer((_) async {});
        return ForgotPasswordBloc(repo);
      },
      act: (b) =>
          b.add(const ForgotPasswordSubmitted(email: 'desconocido@x.com')),
      expect: () => const <ForgotPasswordState>[
        ForgotPasswordSubmitting(),
        ForgotPasswordSent(),
      ],
    );

    blocTest<ForgotPasswordBloc, ForgotPasswordState>(
      'timeout: Submitting → Failed(network)',
      build: () {
        when(
          () => repo.forgotPassword(any()),
        ).thenThrow(const NetworkFailure());
        return ForgotPasswordBloc(repo);
      },
      act: (b) =>
          b.add(const ForgotPasswordSubmitted(email: 'op@x.com')),
      expect: () => const <ForgotPasswordState>[
        ForgotPasswordSubmitting(),
        ForgotPasswordFailed(ForgotPasswordFailureKind.network),
      ],
    );

    blocTest<ForgotPasswordBloc, ForgotPasswordState>(
      '429: Submitting → Failed(rateLimited)',
      build: () {
        when(
          () => repo.forgotPassword(any()),
        ).thenThrow(const RateLimitedFailure());
        return ForgotPasswordBloc(repo);
      },
      act: (b) =>
          b.add(const ForgotPasswordSubmitted(email: 'op@x.com')),
      expect: () => const <ForgotPasswordState>[
        ForgotPasswordSubmitting(),
        ForgotPasswordFailed(ForgotPasswordFailureKind.rateLimited),
      ],
    );

    blocTest<ForgotPasswordBloc, ForgotPasswordState>(
      '5xx u otro: Submitting → Failed(unknown)',
      build: () {
        when(
          () => repo.forgotPassword(any()),
        ).thenThrow(const UnknownAuthFailure());
        return ForgotPasswordBloc(repo);
      },
      act: (b) =>
          b.add(const ForgotPasswordSubmitted(email: 'op@x.com')),
      expect: () => const <ForgotPasswordState>[
        ForgotPasswordSubmitting(),
        ForgotPasswordFailed(ForgotPasswordFailureKind.unknown),
      ],
    );
  });
}
