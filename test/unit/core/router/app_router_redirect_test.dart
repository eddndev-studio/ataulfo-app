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

const _supervisor = Identity(
  userId: 'u4',
  orgId: 'o1',
  role: 'SUPERVISOR',
  email: 'supervisor@example.com',
);

const _admin = Identity(
  userId: 'u5',
  orgId: 'o1',
  role: 'ADMIN',
  email: 'admin@example.com',
);

const _noOrg = Identity(
  userId: 'u3',
  orgId: '',
  role: '',
  email: 'op@example.com',
);

void main() {
  group('redirectForState — AuthInitial', () {
    test(
      'ruta pública se preserva (no se descarta antes del primer check)',
      () {
        expect(redirectForState(const AuthInitial(), '/login'), isNull);
        expect(redirectForState(const AuthInitial(), '/register'), isNull);
      },
    );

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

  group('redirectForState — AuthOfflinePending', () {
    test('/ se deja pasar (pinta la vista de reconexión, no el login)', () {
      expect(redirectForState(const AuthOfflinePending(), '/'), isNull);
    });

    test('ruta protegida → / (reconexión), NUNCA /login', () {
      // El punto del estado: con sesión persistida pero sin red, no se aparenta
      // un cierre de sesión mandando al login.
      expect(redirectForState(const AuthOfflinePending(), '/home'), '/');
      expect(redirectForState(const AuthOfflinePending(), '/bots/b1'), '/');
    });

    test('ruta pública se preserva (login a propósito sigue alcanzable)', () {
      expect(redirectForState(const AuthOfflinePending(), '/login'), isNull);
      expect(
        redirectForState(
          const AuthOfflinePending(),
          '/reset-password?token=abc',
        ),
        isNull,
      );
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
      expect(redirectForState(const AuthUnauthenticated(), '/home'), '/login');
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

    test(
      'aterrizaje del alta: /verify-email?email=… no rebota a /home con sesión',
      () {
        // El alta navega a /verify-email?email=… y dispara AuthCheckRequested;
        // cuando la sesión pasa a Authenticated el redirect NO debe comerse esa
        // navegación (la ruta se permite con sesión, incluida su query).
        expect(
          redirectForState(
            const AuthAuthenticated(_owner),
            '/verify-email?email=op%40example.com',
          ),
          isNull,
        );
      },
    );

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

    test(
      '/select-org rebota a /home (org activa nunca queda en selección)',
      () {
        // Tras un switch en /select-org la sesión flipa a Authenticated pero la
        // ubicación sigue siendo /select-org; sin este rebote el operador queda
        // varado en la pantalla de selección con una org ya activa.
        expect(
          redirectForState(const AuthAuthenticated(_owner), '/select-org'),
          '/home',
        );
      },
    );

    test('gateo ADMIN+ de sub-rutas bot-level: WORKER → detalle', () {
      for (final location in <String>[
        '/bots/b1/variables',
        '/bots/b1/maintenance',
        '/bots/b1/wa-label-mappings',
        '/bots/b1/sessions/chat-1/ai-log',
        '/bots/b1/sessions/chat-1/ai-ledger',
        '/bots/b1/sessions/chat-1/executions',
      ]) {
        expect(
          redirectForState(const AuthAuthenticated(_worker), location),
          '/bots/b1',
          reason: '$location requiere administrar el canal',
        );
      }
    });

    test('gateo ADMIN+: OWNER pasa a las sub-rutas bot-level', () {
      expect(
        redirectForState(const AuthAuthenticated(_owner), '/bots/b1/variables'),
        isNull,
      );
    });

    test('WORKER conserva las rutas operativas de sus canales', () {
      for (final location in <String>[
        '/home',
        '/bots/b1',
        '/bots/b1/sessions',
        '/bots/b1/sessions/s1/chat',
        '/notifications',
        '/appearance',
      ]) {
        expect(
          redirectForState(const AuthAuthenticated(_worker), location),
          isNull,
          reason: '$location forma parte de la operación del Agente',
        );
      }
    });

    test('WORKER no entra a herramientas globales SUPERVISOR+', () {
      for (final location in <String>[
        '/agenda/book',
        '/calendar/hours',
        '/catalog/products',
        '/media',
        '/cuenta',
      ]) {
        expect(
          redirectForState(const AuthAuthenticated(_worker), location),
          '/home',
          reason: '$location requiere SUPERVISOR+',
        );
      }
    });

    test('WORKER y SUPERVISOR no entran a administración global ADMIN+', () {
      for (final identity in <Identity>[_worker, _supervisor]) {
        for (final location in <String>[
          '/assistants/a1',
          '/templates',
          '/flows',
          '/org/labels',
        ]) {
          expect(
            redirectForState(AuthAuthenticated(identity), location),
            '/home',
            reason: '${identity.role} no puede abrir $location',
          );
        }
      }
    });

    test('Organización es visible a cualquier rol, su administración no', () {
      expect(
        redirectForState(const AuthAuthenticated(_worker), '/organization'),
        isNull,
      );
      for (final identity in <Identity>[_worker, _supervisor]) {
        for (final path in <String>[
          '/organization/team',
          '/organization/team?tab=invitations',
          '/members',
          '/members/m1/bots',
          '/invitations',
          '/org/ai-config',
          '/org/customization',
          '/org/public-catalog',
          '/org/stickers',
        ]) {
          expect(
            redirectForState(AuthAuthenticated(identity), path),
            '/organization',
            reason: '$path requiere administración organizacional ADMIN+',
          );
        }
      }
    });

    test('SUPERVISOR entra a herramientas globales pero no administra', () {
      for (final location in <String>[
        '/agenda/book',
        '/calendar/hours',
        '/catalog/products',
        '/media',
        '/cuenta',
      ]) {
        expect(
          redirectForState(const AuthAuthenticated(_supervisor), location),
          isNull,
          reason: '$location forma parte de las capacidades SUPERVISOR+',
        );
      }
    });

    test('ADMIN entra a administración y herramientas globales', () {
      for (final location in <String>[
        '/assistants/a1',
        '/members',
        '/invitations',
        '/organization/team',
        '/org/labels',
        '/media',
      ]) {
        expect(
          redirectForState(const AuthAuthenticated(_admin), location),
          isNull,
          reason: '$location debe estar disponible para ADMIN+',
        );
      }
    });

    test('OWNER entra a las áreas de administración organizacional', () {
      expect(
        redirectForState(const AuthAuthenticated(_owner), '/organization/team'),
        isNull,
      );
      expect(
        redirectForState(const AuthAuthenticated(_owner), '/org/customization'),
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
