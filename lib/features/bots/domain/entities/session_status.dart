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
class SessionStatus {
  const SessionStatus({required this.state, this.qrCode});

  final SessionState state;
  final String? qrCode;

  @override
  bool operator ==(Object other) =>
      other is SessionStatus && other.state == state && other.qrCode == qrCode;

  @override
  int get hashCode => Object.hash(state, qrCode);
}
