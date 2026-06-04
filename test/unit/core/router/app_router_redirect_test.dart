import 'package:ataulfo/core/router/app_router.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _owner = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
);

const _worker = Identity(
  userId: 'u2',
  orgId: 'o1',
  role: 'WORKER',
  email: 'worker@example.com',
);

const _noOrg = Identity(
  userId: 'u3',
  orgId: '',
  role: '',
  email: 'op@example.com',
);

void main() {
  group('redirectForState — AuthInitial', () {
    test('ruta pública se preserva (no se descarta antes del primer check)', () {
      expect(
        redirectForState(const AuthInitial(), '/login'),
        isNull,
      );
      expect(
        redirectForState(const AuthInitial(), '/register'),
        isNull,
      );
    });

    test('ruta pública con query (?token=) sobrevive intacta', () {
      // El cold-open de un deep-link (reset/accept) llega antes del primer
      // check; AuthInitial NO debe descartarlo a / o se perdería el token.
      expect(
        redirectForState(const AuthInitial(), '/reset-password?token=abc'),
        isNull,
      );
    });

    test('/ se deja pasar (Splash)', () {
      expect(redirectForState(const AuthInitial(), '/'), isNull);
    });

    test('ruta protegida cualquiera → / (evita parpadeo pre-check)', () {
      expect(redirectForState(const AuthInitial(), '/home'), '/');
      expect(redirectForState(const AuthInitial(), '/bots/b1'), '/');
    });
  });

  group('redirectForState — AuthUnauthenticated', () {
    test('rutas públicas son alcanzables sin sesión', () {
      for (final loc in <String>[
        '/login',
        '/register',
        '/forgot-password',
        '/reset-password',
        '/accept-invite',
        '/verify-email',
      ]) {
        expect(
          redirectForState(const AuthUnauthenticated(), loc),
          isNull,
          reason: '$loc debe ser pública estando sin sesión',
        );
      }
    });

    test('ruta pública con query sobrevive', () {
      expect(
        redirectForState(
          const AuthUnauthenticated(),
          '/accept-invite?token=xyz',
        ),
        isNull,
      );
    });

    test('ruta protegida → /login', () {
      expect(
        redirectForState(const AuthUnauthenticated(), '/home'),
        '/login',
      );
      expect(
        redirectForState(const AuthUnauthenticated(), '/bots/b1'),
        '/login',
      );
      expect(redirectForState(const AuthUnauthenticated(), '/'), '/login');
    });
  });

  group('redirectForState — AuthAuthenticated', () {
    test('rutas de entrada (/ , /login , /register) rebotan a /home', () {
      expect(redirectForState(const AuthAuthenticated(_owner), '/'), '/home');
      expect(
        redirectForState(const AuthAuthenticated(_owner), '/login'),
        '/home',
      );
      expect(
        redirectForState(const AuthAuthenticated(_owner), '/register'),
        '/home',
      );
    });

    test('/verify-email y /accept-invite se permiten con sesión', () {
      expect(
        redirectForState(const AuthAuthenticated(_owner), '/verify-email'),
        isNull,
      );
      expect(
        redirectForState(const AuthAuthenticated(_owner), '/accept-invite'),
        isNull,
      );
    });

    test('rutas normales se permiten', () {
      expect(
        redirectForState(const AuthAuthenticated(_owner), '/home'),
        isNull,
      );
      expect(
        redirectForState(const AuthAuthenticated(_owner), '/bots/b1'),
        isNull,
      );
    });

    test('gateo ADMIN+ de sub-rutas bot-level: WORKER → detalle', () {
      expect(
        redirectForState(
          const AuthAuthenticated(_worker),
          '/bots/b1/variables',
        ),
        '/bots/b1',
      );
      expect(
        redirectForState(
          const AuthAuthenticated(_worker),
          '/bots/b1/maintenance',
        ),
        '/bots/b1',
      );
    });

    test('gateo ADMIN+: OWNER pasa a las sub-rutas bot-level', () {
      expect(
        redirectForState(
          const AuthAuthenticated(_owner),
          '/bots/b1/variables',
        ),
        isNull,
      );
    });
  });

  group('redirectForState — AuthAuthenticatedNoOrg', () {
    test('rutas permitidas devuelven null (sin loop)', () {
      for (final loc in <String>[
        '/select-org',
        '/verify-email',
        '/accept-invite',
      ]) {
        expect(
          redirectForState(const AuthAuthenticatedNoOrg(_noOrg), loc),
          isNull,
          reason: '$loc no debe redirigir (evita loop de redirect)',
        );
      }
    });

    test('cualquier otra ruta → /select-org', () {
      expect(
        redirectForState(const AuthAuthenticatedNoOrg(_noOrg), '/home'),
        '/select-org',
      );
      expect(
        redirectForState(const AuthAuthenticatedNoOrg(_noOrg), '/'),
        '/select-org',
      );
      expect(
        redirectForState(const AuthAuthenticatedNoOrg(_noOrg), '/bots/b1'),
        '/select-org',
      );
    });
  });
}
