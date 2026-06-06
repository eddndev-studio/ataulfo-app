/// Failures del arranque manual de flujos (S11 `GET /sessions/:botId/flows` +
/// `POST /sessions/:botId/:chatLid/flows/:flowId/run`). Jerarquía sellada para
/// el switch exhaustivo. 401 lo absorbe el AuthInterceptor.
sealed class FlowRunFailure implements Exception {
  const FlowRunFailure();
}

/// Sin conexión / DNS / TLS.
final class FlowRunNetworkFailure extends FlowRunFailure {
  const FlowRunNetworkFailure();
}

/// Timeout connect/receive/send.
final class FlowRunTimeoutFailure extends FlowRunFailure {
  const FlowRunTimeoutFailure();
}

/// 403: el RBAC del backend rechaza la acción.
final class FlowRunForbiddenFailure extends FlowRunFailure {
  const FlowRunForbiddenFailure();
}

/// 404: bot ajeno, o flujo inexistente / inactivo / de otra Template del bot.
final class FlowRunNotFoundFailure extends FlowRunFailure {
  const FlowRunNotFoundFailure();
}

/// 423: el bot está pausado; el run no toca el wire hasta reanudarlo.
final class FlowRunPausedFailure extends FlowRunFailure {
  const FlowRunPausedFailure();
}

/// 409 sin razón de gate: doble-tap exacto (idempotencia del slot). Raro con la
/// clave por intento; se trata como conflicto neutro.
final class FlowRunConflictFailure extends FlowRunFailure {
  const FlowRunConflictFailure();
}

/// 5xx propio del backend.
final class FlowRunServerFailure extends FlowRunFailure {
  const FlowRunServerFailure();
}

/// Status no contemplado o body malformado.
final class UnknownFlowRunFailure extends FlowRunFailure {
  const UnknownFlowRunFailure();
}

/// 409 con razón de gate: el flujo no arrancó porque un gate lo bloqueó
/// (`COOLDOWN` | `LIMIT` | `EXCLUDED`). NO es un error de transporte — el
/// operador ve la razón y decide.
final class FlowRunBlockedFailure extends FlowRunFailure {
  const FlowRunBlockedFailure(this.reason);

  final String reason;

  @override
  bool operator ==(Object other) =>
      other is FlowRunBlockedFailure && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}
