import '../domain/entities/entitlement.dart';

/// Nombre humano del plan para la pantalla Cuenta. Los códigos del catálogo
/// llegan como jerga de wire (`trial`, `starter`…); un código que el cliente
/// aún no conoce se capitaliza en vez de filtrarse crudo — el backend puede
/// ganar planes entre releases sin romper esta pantalla.
String planLabel(String planCode) => switch (planCode) {
  'trial' => 'Prueba',
  'starter' => 'Starter',
  'pro' => 'Pro',
  'business' => 'Business',
  'cortesia' => 'Fundador',
  '' => 'Plan',
  _ => planCode[0].toUpperCase() + planCode.substring(1),
};

/// Clasificación del estado de la IA que la pantalla Cuenta proyecta del
/// entitlement. Solo `activa` va sin banner; el resto explica la pausa.
enum EstadoIAKind {
  activa,

  /// Cobro caído (past_due/canceled): pausa dura hasta regularizar el pago.
  suscripcionInactiva,

  /// Prueba vencida (E-B5): pausa dura hasta contratar un plan.
  pruebaVencida,

  /// Créditos del mes agotados: pausa suave — se reinicia sola al mes
  /// siguiente; los flujos y la mensajería nunca se detienen.
  limiteAlcanzado,
}

/// Estado de la IA listo para pintarse: pill de la card de plan + banner
/// (título/cuerpo/CTA) cuando no está activa. El copy vive AQUÍ y no en el
/// widget para que los tests lo fijen como contrato; `webPath` es la ruta
/// del sitio (se concatena a la base web) a la que lleva el CTA.
class EstadoIA {
  const EstadoIA._({
    required this.kind,
    required this.pillLabel,
    this.titulo,
    this.cuerpo,
    this.ctaLabel,
    this.webPath,
  });

  final EstadoIAKind kind;
  final String pillLabel;
  final String? titulo;
  final String? cuerpo;
  final String? ctaLabel;
  final String? webPath;
}

/// Proyecta el entitlement al estado de IA con la MISMA precedencia con la
/// que decide el backend: estado de cobro, luego caducidad del trial, luego
/// cuota. El cliente no re-deriva nada — solo ordena flags que llegan ya
/// derivados para contar una única historia coherente.
EstadoIA estadoIA(Entitlement e) {
  if (e.status == 'past_due' || e.status == 'canceled') {
    return const EstadoIA._(
      kind: EstadoIAKind.suscripcionInactiva,
      pillLabel: 'IA pausada',
      titulo: 'IA pausada',
      cuerpo: 'Tu suscripción está inactiva. Revisa tu método de pago.',
      ctaLabel: 'Gestiona tu plan',
      webPath: '/cuenta',
    );
  }
  if (e.trialExpired) {
    return const EstadoIA._(
      kind: EstadoIAKind.pruebaVencida,
      pillLabel: 'IA pausada',
      titulo: 'IA pausada',
      cuerpo:
          'Tu prueba terminó. Mejora tu plan para reactivar la IA de '
          'tus asistentes.',
      ctaLabel: 'Ver planes',
      webPath: '/precios',
    );
  }
  // Cualquier señal de cupo agotado explica el límite; los dos flags viajan
  // derivados y ser sensible a ambos cubre un backend a media migración.
  if (e.quotaExceeded || !e.withinQuota) {
    return const EstadoIA._(
      kind: EstadoIAKind.limiteAlcanzado,
      pillLabel: 'Límite alcanzado',
      titulo: 'Límite alcanzado',
      cuerpo:
          'Alcanzaste tu límite de créditos de IA de este mes. '
          'Se reinicia el próximo mes.',
      ctaLabel: 'Mejora tu plan',
      webPath: '/precios',
    );
  }
  return EstadoIA._(
    kind: EstadoIAKind.activa,
    pillLabel: e.status == 'trialing' ? 'En prueba' : 'Activo',
  );
}

/// Consumo de créditos de IA del periodo (mensual). Tope 0 = ilimitado
/// (convención del backend, la misma del cap de almacenamiento).
String creditosLabel(int used, int cap) =>
    cap == 0 ? 'Ilimitados' : '$used de $cap este mes';

/// Consumo de almacenamiento de la galería. Cuota 0 = ilimitado.
String almacenamientoLabel(int usedMb, int quotaMb) =>
    quotaMb == 0 ? 'Ilimitado' : '$usedMb MB de $quotaMb MB';

/// Consumo de imágenes generadas con IA, también mensual. Tope 0 =
/// ilimitadas.
String imagenesIaLabel(int used, int cap) =>
    cap == 0 ? 'Ilimitadas' : '$used de $cap este mes';
