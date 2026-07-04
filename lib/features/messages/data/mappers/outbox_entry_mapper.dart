import 'dart:convert';

import '../../../../core/db/app_db.dart';
import '../../domain/entities/outbox_entry.dart';

/// Proyecta una fila del outbox a [OutboxEntry] (la burbuja del hilo). El
/// `type`/`content`/`mediaRef` viven en el payload JSON; el estado y el error
/// son columnas. Devuelve `null` si la fila no es proyectable (sin token o
/// payload corrupto) — el repositorio la filtra; el coordinador ya marcó esas
/// filas terminal, así que no deberían aparecer en flujo normal.
class OutboxEntryMapper {
  static OutboxEntry? fromRow(OutboxRow row) {
    final token = row.clientToken;
    if (token == null) return null;
    try {
      final payload = jsonDecode(row.payload) as Map<String, dynamic>;
      return OutboxEntry(
        clientToken: token,
        type: payload['type'] as String,
        content: (payload['content'] as String?) ?? '',
        mediaRef: payload['mediaRef'] as String?,
        quotedId: payload['quotedId'] as String?,
        fileName: payload['fileName'] as String?,
        isFailed: row.state == 'failed',
        errorKind: row.errorKind,
        createdAtMs: row.createdAtMs,
      );
    } catch (_) {
      return null;
    }
  }
}
