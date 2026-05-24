import 'package:agentic/features/auth/domain/repositories/auth_repository.dart';
import 'package:agentic/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AuthRepository {}

void main() {
  group('AuthBloc', () {
    test('estado inicial = AuthInitial (todavía no verificado)', () {
      final bloc = AuthBloc(_MockRepo());

      expect(bloc.state, const AuthInitial());
    });
  });
}
