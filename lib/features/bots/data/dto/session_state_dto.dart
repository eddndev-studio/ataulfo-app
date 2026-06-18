import '../../domain/entities/session_status.dart';

/// DTO del wire de `GET /bots/:id/session`
/// (`agentic-go/internal/adapters/httpsession/dto.go` `sessionResp`):
/// `{state, qr?: {code}, reason?, disconnectedAt?}`. `qr` (omitempty) sólo viene
/// en PAIRING; `reason`/`disconnectedAt` (omitempty) sólo en un DISCONNECTED con
/// causa capturada.
class SessionStateResp {
  const SessionStateResp({
    required this.state,
    this.qrCode,
    this.reason,
    this.disconnectedAt,
  });

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
    final rawReason = json['reason'];
    final rawSince = json['disconnectedAt'];
    return SessionStateResp(
      state: state,
      qrCode: qrCode,
      reason: (rawReason is String && rawReason.isNotEmpty) ? rawReason : null,
      disconnectedAt: rawSince is String ? DateTime.tryParse(rawSince) : null,
    );
  }

  final String state;
  final String? qrCode;
  final String? reason;
  final DateTime? disconnectedAt;

  /// Traduce a dominio. `SessionState.fromWire` es fail-loud (ArgumentError en
  /// estado desconocido); el datasource lo colapsa a `UnknownBotsFailure`.
  SessionStatus toDomain() => SessionStatus(
    state: SessionState.fromWire(state),
    qrCode: qrCode,
    disconnectReason: reason,
    disconnectedAt: disconnectedAt,
  );
}
