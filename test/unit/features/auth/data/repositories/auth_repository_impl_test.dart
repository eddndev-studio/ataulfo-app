import 'package:ataulfo/features/auth/data/datasources/auth_datasource.dart';
import 'package:ataulfo/features/auth/data/dto/login_dto.dart';
import 'package:ataulfo/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:ataulfo/features/auth/data/repositories/token_storage.dart';
import 'package:ataulfo/features/auth/domain/entities/accepted_invitation.dart';
import 'package:ataulfo/features/auth/domain/entities/auth_tokens.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/domain/entities/pending_invitation.dart';
import 'package:ataulfo/features/auth/domain/failures/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDs extends Mock implements AuthDatasource {}

class _SpyStorage implements TokenStorage {
  _SpyStorage({this.onClear});

  final List<AuthTokens> saved = <AuthTokens>[];
  int clears = 0;

  /// Hook para observar el orden relativo de `clear()` frente a otros
  /// efectos (p. ej. el `onBeforeLogout`).
  final void Function()? onClear;

  @override
  Future<void> save(AuthTokens tokens) async => saved.add(tokens);

  @override
  Future<AuthTokens?> read() async => saved.isEmpty ? null : saved.last;

  @override
  Future<void> clear() async {
    onClear?.call();
    clears++;
  }
}

void main() {
  late _MockDs ds;
  late _SpyStorage storage;
  late AuthRepositoryImpl repo;

  setUp(() {
    ds = _MockDs();
    storage = _SpyStorage();
    repo = AuthRepositoryImpl(datasource: ds, storage: storage);
  });

  group('login', () {
    test('OK guarda los tokens y los devuelve', () async {
      const tokens = AuthTokens(
        accessToken: 'a',
        refreshToken: 'r',
        tokenType: 'Bearer',
        expiresInSeconds: 900,
      );
      when(
        () => ds.login(email: 'op@x.com', password: 'p'),
      ).thenAnswer((_) async => tokens);

      final got = await repo.login(email: 'op@x.com', password: 'p');

      expect(got, tokens);
      expect(storage.saved, <AuthTokens>[tokens]);
    });

    test('falla del datasource propaga y no persiste tokens', () async {
      when(
        () => ds.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const InvalidCredentialsFailure());

      await expectLater(
        repo.login(email: 'x@y.z', password: 'bad'),
        throwsA(isA<InvalidCredentialsFailure>()),
      );
      expect(storage.saved, isEmpty);
    });
  });

  group('me', () {
    test('OK devuelve la identidad del datasource sin tocar storage', () async {
      const identity = Identity(
        userId: 'u1',
        orgId: 'o1',
        role: 'OWNER',
        email: 'op@example.com',
      );
      when(() => ds.me()).thenAnswer((_) async => identity);

      final got = await repo.me();

      expect(got, identity);
      expect(storage.saved, isEmpty);
      expect(storage.clears, 0);
    });

    test('falla del datasource propaga sin tocar storage', () async {
      when(() => ds.me()).thenThrow(const InvalidCredentialsFailure());

      await expectLater(repo.me(), throwsA(isA<InvalidCredentialsFailure>()));
      expect(storage.saved, isEmpty);
      expect(storage.clears, 0);
    });
  });

  group('register', () {
    test('OK persiste los tokens devueltos y los retorna', () async {
      const tokens = AuthTokens(
        accessToken: 'a',
        refreshToken: 'r',
        tokenType: 'Bearer',
        expiresInSeconds: 900,
      );
      when(
        () => ds.register(email: 'new@x.com', password: 'p'),
      ).thenAnswer((_) async => tokens);

      final got = await repo.register(email: 'new@x.com', password: 'p');

      expect(got, tokens);
      expect(storage.saved, <AuthTokens>[tokens]);
    });

    test('falla del datasource propaga y no persiste tokens', () async {
      when(
        () => ds.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const EmailTakenFailure());

      await expectLater(
        repo.register(email: 'taken@x.com', password: 'p'),
        throwsA(isA<EmailTakenFailure>()),
      );
      expect(storage.saved, isEmpty);
    });
  });

  group('switchOrg', () {
    test('OK persiste el nuevo par de tokens y lo retorna', () async {
      const tokens = AuthTokens(
        accessToken: 'a2',
        refreshToken: 'r2',
        tokenType: 'Bearer',
        expiresInSeconds: 900,
      );
      when(() => ds.switchOrg('o-789')).thenAnswer((_) async => tokens);

      final got = await repo.switchOrg('o-789');

      expect(got, tokens);
      expect(storage.saved, <AuthTokens>[tokens]);
    });

    test('falla del datasource propaga y no persiste tokens', () async {
      when(() => ds.switchOrg(any())).thenThrow(const NotMemberFailure());

      await expectLater(
        repo.switchOrg('o-foreign'),
        throwsA(isA<NotMemberFailure>()),
      );
      expect(storage.saved, isEmpty);
    });
  });

  group('createOrganization', () {
    test('OK persiste el par de la org nueva y lo retorna', () async {
      const tokens = AuthTokens(
        accessToken: 'a3',
        refreshToken: 'r3',
        tokenType: 'Bearer',
        expiresInSeconds: 900,
      );
      when(() => ds.createOrganization('Acme')).thenAnswer((_) async => tokens);

      final got = await repo.createOrganization('Acme');

      expect(got, tokens);
      expect(storage.saved, <AuthTokens>[tokens]);
    });

    test('falla del datasource propaga y no persiste', () async {
      when(
        () => ds.createOrganization(any()),
      ).thenThrow(const UnknownAuthFailure());

      await expectLater(
        repo.createOrganization('Acme'),
        throwsA(isA<UnknownAuthFailure>()),
      );
      expect(storage.saved, isEmpty);
    });
  });

  group('renameOrganization', () {
    test('OK delega en el datasource (sin tocar tokens)', () async {
      when(() => ds.renameOrganization(any())).thenAnswer((_) async {});

      await repo.renameOrganization('Nuevo');

      verify(() => ds.renameOrganization('Nuevo')).called(1);
      expect(storage.saved, isEmpty);
    });

    test('falla del datasource propaga', () async {
      when(
        () => ds.renameOrganization(any()),
      ).thenThrow(const NetworkFailure());

      // Closure: rename es un delegate síncrono (=>) y mocktail.thenThrow lanza
      // sync al invocarse; expectLater necesita la función para atraparlo.
      await expectLater(
        () => repo.renameOrganization('X'),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('verifyEmail', () {
    test(
      'delega al datasource, devuelve alreadyVerified, sin tocar storage',
      () async {
        when(
          () => ds.verifyEmail(email: 'op@x.com', code: '123456'),
        ).thenAnswer((_) async => const VerifyEmailResp(alreadyVerified: true));

        final got = await repo.verifyEmail(email: 'op@x.com', code: '123456');

        expect(got, isTrue);
        expect(storage.saved, isEmpty);
        expect(storage.clears, 0);
      },
    );
  });

  group(
    'forgotPassword / resetPassword / acceptInvitation / resendVerification',
    () {
      test('forgotPassword delega sin tocar storage', () async {
        when(() => ds.forgotPassword('op@x.com')).thenAnswer((_) async {});

        await repo.forgotPassword('op@x.com');

        verify(() => ds.forgotPassword('op@x.com')).called(1);
        expect(storage.saved, isEmpty);
      });

      test('resetPassword delega sin tocar storage', () async {
        when(
          () => ds.resetPassword(
            email: 'op@x.com',
            code: '123456',
            newPassword: 'n',
          ),
        ).thenAnswer((_) async {});

        await repo.resetPassword(
          email: 'op@x.com',
          code: '123456',
          newPassword: 'n',
        );

        verify(
          () => ds.resetPassword(
            email: 'op@x.com',
            code: '123456',
            newPassword: 'n',
          ),
        ).called(1);
        expect(storage.saved, isEmpty);
      });

      test('acceptInvitation delega sin tocar storage', () async {
        when(() => ds.acceptInvitation('inv')).thenAnswer((_) async {});

        await repo.acceptInvitation('inv');

        verify(() => ds.acceptInvitation('inv')).called(1);
        expect(storage.saved, isEmpty);
      });

      test('resendVerification delega sin tocar storage', () async {
        when(ds.resendVerification).thenAnswer((_) async {});

        await repo.resendVerification();

        verify(ds.resendVerification).called(1);
        expect(storage.saved, isEmpty);
      });

      test('pendingInvitations delega sin tocar storage', () async {
        when(
          ds.pendingInvitations,
        ).thenAnswer((_) async => const <PendingInvitation>[]);

        await repo.pendingInvitations();

        verify(ds.pendingInvitations).called(1);
        expect(storage.saved, isEmpty);
      });

      test('acceptPendingInvitation delega sin tocar storage', () async {
        const accepted = AcceptedInvitation(
          orgId: 'o-9',
          orgName: 'Acme',
          role: 'WORKER',
        );
        when(
          () => ds.acceptPendingInvitation('inv-1'),
        ).thenAnswer((_) async => accepted);

        final got = await repo.acceptPendingInvitation('inv-1');

        expect(got, accepted);
        verify(() => ds.acceptPendingInvitation('inv-1')).called(1);
        expect(storage.saved, isEmpty);
      });
    },
  );

  group('logout', () {
    test('sin tokens persistidos: no llama al datasource y no falla', () async {
      // Storage empieza vacío (saved.isEmpty → read() = null).
      await repo.logout();

      verifyNever(() => ds.logout(any()));
      expect(storage.clears, 0);
    });

    test(
      'con tokens: lee refresh → ds.logout(refresh) → storage.clear()',
      () async {
        const tokens = AuthTokens(
          accessToken: 'a',
          refreshToken: 'r-32',
          tokenType: 'Bearer',
          expiresInSeconds: 900,
        );
        await storage.save(tokens);
        when(() => ds.logout('r-32')).thenAnswer((_) async {});

        await repo.logout();

        verify(() => ds.logout('r-32')).called(1);
        expect(storage.clears, 1);
      },
    );

    test(
      'backend falla con NetworkFailure → storage.clear() igual + no rethrow',
      () async {
        const tokens = AuthTokens(
          accessToken: 'a',
          refreshToken: 'r-32',
          tokenType: 'Bearer',
          expiresInSeconds: 900,
        );
        await storage.save(tokens);
        when(() => ds.logout(any())).thenThrow(const NetworkFailure());

        await repo.logout(); // No debe propagar.

        verify(() => ds.logout('r-32')).called(1);
        expect(storage.clears, 1);
      },
    );

    test(
      'backend falla con InvalidCredentials → storage.clear() igual + no rethrow',
      () async {
        const tokens = AuthTokens(
          accessToken: 'a',
          refreshToken: 'r-32',
          tokenType: 'Bearer',
          expiresInSeconds: 900,
        );
        await storage.save(tokens);
        when(
          () => ds.logout(any()),
        ).thenThrow(const InvalidCredentialsFailure());

        await repo.logout();

        expect(storage.clears, 1);
      },
    );

    test(
      'onBeforeLogout corre ANTES de storage.clear() (Bearer aún válido)',
      () async {
        // El gancho de pre-logout debe ejecutarse mientras los tokens siguen
        // persistidos, para que cualquier request que dispare (p. ej. el
        // desregistro del device de push) viaje con el Authorization vivo.
        // Si corriera después de clear(), el request iría sin Bearer → 401.
        const tokens = AuthTokens(
          accessToken: 'a',
          refreshToken: 'r-32',
          tokenType: 'Bearer',
          expiresInSeconds: 900,
        );
        var hookRanWithTokens = false;
        final order = <String>[];
        final spy = _SpyStorage(onClear: () => order.add('clear'));
        await spy.save(tokens);
        final repoWithHook = AuthRepositoryImpl(
          datasource: ds,
          storage: spy,
          onBeforeLogout: () async {
            order.add('hook');
            hookRanWithTokens = (await spy.read()) != null;
          },
        );
        when(() => ds.logout('r-32')).thenAnswer((_) async {});

        await repoWithHook.logout();

        expect(order, <String>['hook', 'clear']);
        expect(hookRanWithTokens, isTrue);
      },
    );

    test('onBeforeLogout no se invoca si no hay tokens persistidos', () async {
      var hookCalls = 0;
      final repoWithHook = AuthRepositoryImpl(
        datasource: ds,
        storage: storage,
        onBeforeLogout: () async => hookCalls++,
      );

      await repoWithHook.logout();

      expect(hookCalls, 0);
      verifyNever(() => ds.logout(any()));
    });

    test('onBeforeLogout que lanza no aborta el teardown ni propaga', () async {
      const tokens = AuthTokens(
        accessToken: 'a',
        refreshToken: 'r-32',
        tokenType: 'Bearer',
        expiresInSeconds: 900,
      );
      await storage.save(tokens);
      final repoWithHook = AuthRepositoryImpl(
        datasource: ds,
        storage: storage,
        onBeforeLogout: () async => throw StateError('boom'),
      );
      when(() => ds.logout('r-32')).thenAnswer((_) async {});

      await repoWithHook.logout(); // No debe propagar.

      verify(() => ds.logout('r-32')).called(1);
      expect(storage.clears, 1);
    });
  });
}
