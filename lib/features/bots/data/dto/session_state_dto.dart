import '../../domain/entities/session_status.dart';

/// DTO del wire de `GET /bots/:id/session`
/// (`agentic-go/internal/adapters/httpsession/dto.go` `sessionResp`):
/// `{state, qr?: {code}}`. El `qr` (omitempty) sólo viene en PAIRING.
class SessionStateResp {
  const SessionStateResp({required this.state, this.qrCode});

  factory SessionStateResp.fromJson(Map<String, dynamic> json) {
    final state = json['state'];
    if (state is! String) {
      throw const FormatException('sessionResp: state ausente');
    }
    String? qrCode;
    final qr = json['qr'];
    if (qr is Map<String, dynamic>) {
      final code = qr['code'];
      if (code is String) {
        qrCode = code;
      }
    }
    return SessionStateResp(state: state, qrCode: qrCode);
  }

  final String state;
  final String? qrCode;

  /// Traduce a dominio. `SessionState.fromWire` es fail-loud (ArgumentError en
  /// estado desconocido); el datasource lo colapsa a `UnknownBotsFailure`.
  SessionStatus toDomain() =>
      SessionStatus(state: SessionState.fromWire(state), qrCode: qrCode);
}
