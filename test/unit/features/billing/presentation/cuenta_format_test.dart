import 'package:ataulfo/features/billing/domain/entities/entitlement.dart';
import 'package:ataulfo/features/billing/presentation/cuenta_format.dart';
import 'package:flutter_test/flutter_test.dart';

Entitlement _ent({
  String planCode = 'trial',
  String status = 'trialing',
  bool trialExpired = false,
  int usedConversations = 12,
  int conversationCap = 50,
  bool withinQuota = true,
  bool quotaExceeded = false,
}) => Entitlement(
  planCode: planCode,
  status: status,
  trialExpired: trialExpired,
  usedConversations: usedConversations,
  conversationCap: conversationCap,
  withinQuota: withinQuota,
  quotaExceeded: quotaExceeded,
  storageUsedMb: 100,
  storageQuotaMb: 512,
  eligibleProviders: const <String>{'MINIMAX'},
  features: const <String>['media_gallery'],
);

void main() {
  group('planLabel', () {
    test('códigos conocidos al es-MX del producto', () {
      expect(planLabel('trial'), 'Prueba');
      expect(planLabel('starter'), 'Starter');
      expect(planLabel('pro'), 'Pro');
      expect(planLabel('business'), 'Business');
      expect(planLabel('cortesia'), 'Fundador');
    });

    test('código desconocido ⇒ capitalizado, nunca jerga cruda', () {
      expect(planLabel('enterprise'), 'Enterprise');
    });

    test('código vacío ⇒ fallback neutro', () {
      expect(planLabel(''), 'Plan');
    });
  });

  group('estadoIA', () {
    test('suscripción activa dentro de cuota ⇒ activa, sin banner', () {
      final estado = estadoIA(_ent(status: 'active', planCode: 'pro'));

      expect(estado.kind, EstadoIAKind.activa);
      expect(estado.pillLabel, 'Activo');
      expect(estado.titulo, isNull);
      expect(estado.cuerpo, isNull);
      expect(estado.ctaLabel, isNull);
      expect(estado.webPath, isNull);
    });

    test('trialing vigente ⇒ activa con pill "En prueba"', () {
      final estado = estadoIA(_ent(status: 'trialing'));

      expect(estado.kind, EstadoIAKind.activa);
      expect(estado.pillLabel, 'En prueba');
    });

    test('past_due ⇒ pausada por suscripción inactiva', () {
      final estado = estadoIA(_ent(status: 'past_due'));

      expect(estado.kind, EstadoIAKind.suscripcionInactiva);
      expect(estado.pillLabel, 'IA pausada');
      expect(estado.titulo, 'IA pausada');
      expect(
        estado.cuerpo,
        'Tu suscripción está inactiva. Revisa tu método de pago.',
      );
      expect(estado.ctaLabel, 'Gestiona tu plan');
      expect(estado.webPath, '/cuenta');
    });

    test('canceled ⇒ pausada por suscripción inactiva', () {
      expect(
        estadoIA(_ent(status: 'canceled')).kind,
        EstadoIAKind.suscripcionInactiva,
      );
    });

    test('prueba vencida ⇒ pausada con CTA a /precios', () {
      final estado = estadoIA(_ent(status: 'trialing', trialExpired: true));

      expect(estado.kind, EstadoIAKind.pruebaVencida);
      expect(estado.pillLabel, 'IA pausada');
      expect(estado.titulo, 'IA pausada');
      expect(
        estado.cuerpo,
        'Tu prueba terminó. Mejora tu plan para reactivar la IA de '
        'tus asistentes.',
      );
      expect(estado.ctaLabel, 'Ver planes');
      expect(estado.webPath, '/precios');
    });

    test('cuota agotada ⇒ límite alcanzado (pausa suave)', () {
      final estado = estadoIA(
        _ent(
          status: 'active',
          usedConversations: 50,
          withinQuota: false,
          quotaExceeded: true,
        ),
      );

      expect(estado.kind, EstadoIAKind.limiteAlcanzado);
      expect(estado.pillLabel, 'Límite alcanzado');
      expect(estado.titulo, 'Límite alcanzado');
      expect(
        estado.cuerpo,
        'Alcanzaste tu límite de conversaciones con IA esta semana. '
        'Se reinicia el próximo periodo.',
      );
      expect(estado.ctaLabel, 'Mejora tu plan');
      expect(estado.webPath, '/precios');
    });

    test('withinQuota=false basta aunque quotaExceeded no llegue', () {
      // Los dos flags viajan derivados; ante cualquier señal de cupo agotado
      // la UI explica el límite en vez de fingir normalidad.
      expect(
        estadoIA(_ent(status: 'active', withinQuota: false)).kind,
        EstadoIAKind.limiteAlcanzado,
      );
    });

    test('precedencia: cobro caído gana a prueba vencida y a cuota', () {
      // Mismo orden de decisión que el backend: estado de cobro, luego
      // caducidad del trial, luego cuota.
      final estado = estadoIA(
        _ent(
          status: 'past_due',
          trialExpired: true,
          withinQuota: false,
          quotaExceeded: true,
        ),
      );
      expect(estado.kind, EstadoIAKind.suscripcionInactiva);
    });

    test('precedencia: prueba vencida gana a cuota', () {
      final estado = estadoIA(
        _ent(trialExpired: true, withinQuota: false, quotaExceeded: true),
      );
      expect(estado.kind, EstadoIAKind.pruebaVencida);
    });
  });

  group('conversacionesLabel', () {
    test('con tope ⇒ "X de Y esta semana"', () {
      expect(conversacionesLabel(12, 50), '12 de 50 esta semana');
    });

    test('tope 0 ⇒ ilimitadas (convención del backend)', () {
      expect(conversacionesLabel(12, 0), 'Ilimitadas');
    });
  });

  group('almacenamientoLabel', () {
    test('con cuota ⇒ "X MB de Y MB"', () {
      expect(almacenamientoLabel(100, 512), '100 MB de 512 MB');
    });

    test('cuota 0 ⇒ ilimitado (convención del backend)', () {
      expect(almacenamientoLabel(100, 0), 'Ilimitado');
    });
  });

  group('imagenesIaLabel', () {
    test(
      'con tope ⇒ "X de Y este mes" (el periodo de imágenes es mensual)',
      () {
        expect(imagenesIaLabel(3, 150), '3 de 150 este mes');
      },
    );

    test('tope 0 ⇒ ilimitadas (convención del backend)', () {
      expect(imagenesIaLabel(3, 0), 'Ilimitadas');
    });
  });
}
