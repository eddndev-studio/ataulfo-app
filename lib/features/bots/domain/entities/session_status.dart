/// Estado de la sesión de canal de un Bot (S04), espejo de
/// `channel.State` del backend (`agentic-go/internal/domain/channel/state.go`).
///
/// Política fail-loud: un estado desconocido en el wire rompe al parsear; el
/// cliente no degrada a un "unknown" cosmético que escondería drift de
/// contrato.
enum SessionState {
  disconnected,
  pairing,
  connecting,
  connected,
  reconnecting;

  static SessionState fromWire(String raw) => switch (raw) {
    'DISCONNECTED' => SessionState.disconnected,
    'PAIRING' => SessionState.pairing,
    'CONNECTING' => SessionState.connecting,
    'CONNECTED' => SessionState.connected,
    'RECONNECTING' => SessionState.reconnecting,
    _ => throw ArgumentError.value(raw, 'SessionState.fromWire'),
  };
}

/// Estado vivo de la sesión más el código QR a escanear. El `qrCode` SÓLO
/// viene durante `pairing` (el backend lo embebe únicamente en ese estado);
/// fuera de pairing es null.
///
/// `disconnectReason`/`disconnectedAt` enriquecen un `DISCONNECTED` con causa
/// capturada por el runtime: por qué cayó y desde cuándo. Son null cuando el
/// estado es sano o cuando el DISCONNECTED no tiene causa (de nacimiento, bot
/// no-corriendo). `disconnectReason` es un código estable (la copy la pone el
/// cliente); se deja como String fail-soft: un código nuevo del backend cae a
/// la copy genérica en vez de romper la card.
class SessionStatus {
  const SessionStatus({
    required this.state,
    this.qrCode,
    this.disconnectReason,
    this.disconnectedAt,
  });

  final SessionState state;
  final String? qrCode;
  final String? disconnectReason;
  final DateTime? disconnectedAt;

  @override
  bool operator ==(Object other) =>
      other is SessionStatus &&
      other.state == state &&
      other.qrCode == qrCode &&
      other.disconnectReason == disconnectReason &&
      other.disconnectedAt == disconnectedAt;

  @override
  int get hashCode =>
      Object.hash(state, qrCode, disconnectReason, disconnectedAt);
}
