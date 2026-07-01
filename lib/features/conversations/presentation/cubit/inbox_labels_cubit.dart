import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../wa_labels/domain/entities/wa_label.dart';
import '../../../wa_labels/domain/entities/wa_label_live_event.dart';
import '../../../wa_labels/domain/repositories/wa_labels_repository.dart';

/// Etiquetas WhatsApp del bot proyectadas para la bandeja: el catálogo activo
/// (para los chips de filtro) y el mapa `chatLid → etiquetas aplicadas` (para
/// los blobs por chat). Vacío es el estado por defecto y también el de
/// degradación: las etiquetas enriquecen la bandeja, nunca la bloquean.
class InboxLabelsState {
  const InboxLabelsState({
    this.catalog = const <WaLabel>[],
    this.byChat = const <String, List<WaLabel>>{},
  });

  /// Catálogo activo del bot (sin tombstones), para ofrecer filtros.
  final List<WaLabel> catalog;

  /// Etiquetas activas aplicadas a cada chat, ya resueltas del catálogo.
  final Map<String, List<WaLabel>> byChat;

  @override
  bool operator ==(Object other) {
    if (other is! InboxLabelsState) return false;
    if (!listEquals(catalog, other.catalog)) return false;
    if (byChat.length != other.byChat.length) return false;
    for (final entry in byChat.entries) {
      if (!listEquals(entry.value, other.byChat[entry.key])) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(catalog), byChat.length);
}

/// Carga el catálogo de etiquetas WhatsApp y sus asociaciones por chat, y las
/// compone en un estado listo para pintar la bandeja (chips + blobs).
///
/// Una sola fuente de verdad para ambas caras: resuelve cada asociación contra
/// el catálogo activo, descartando las desasociadas (`labeled:false`) y las que
/// apuntan a una etiqueta borrada o desconocida. Si la lectura falla, degrada a
/// vacío en vez de propagar el error: la bandeja sigue funcionando sin
/// etiquetas.
class InboxLabelsCubit extends Cubit<InboxLabelsState> {
  InboxLabelsCubit({required WaLabelsRepository repo, required String botId})
    : _repo = repo,
      _botId = botId,
      super(const InboxLabelsState());

  final WaLabelsRepository _repo;
  final String _botId;

  StreamSubscription<WaLabelLiveEvent>? _liveSub;

  /// Carga inicial + suscripción al feed en vivo `label.wa.*` del bot. Es lo
  /// que hace la bandeja reflejar en el acto un etiquetado/desetiquetado (de
  /// esta app o de WhatsApp) sin recargar: el eco del propio cambio del
  /// operador vuelve por SSE tras persistirse el espejo, el mismo mecanismo del
  /// que ya dependía el pull-to-refresh. Espeja `MonitorAttentionCubit.watch`.
  Future<void> watchLive() async {
    await load();
    _startLive();
  }

  void _startLive() {
    // watchLive hace `await load()` antes de llegar aquí; si el cubit se cerró
    // durante esa ventana (el operador salió de la bandeja), close() ya corrió
    // su cancel con `_liveSub` en null y no volverá a correr. Suscribir ahora
    // fugaría un SSE que reconecta para siempre sobre un cubit muerto.
    if (isClosed) return;
    _liveSub?.cancel();
    _liveSub = _repo.liveEvents(_botId).listen((e) {
      switch (e) {
        case WaChatLabelChanged():
          _applyChatDelta(e);
        case WaLabelReconnected():
          // Tras un corte el SSE no reproduce el tramo perdido: reconcilia
          // catálogo + asociaciones contra el GET. Recarga sólo aquí (no por
          // cada delta) para no disparar una ráfaga de GETs en el fan-out.
          unawaited(load());
        case WaLabelCatalogChanged():
          // El catálogo cambió (alta/edición/tombstone): afecta chips y blobs;
          // recarga para reflejar nombres/colores/desapariciones.
          unawaited(load());
        case WaMessageLabelChanged():
          break; // nivel mensaje: no toca la proyección por chat de la bandeja
      }
    }, onError: (Object _) {});
  }

  /// Parchea `byChat` con un cambio de asociación en vivo, resolviendo la
  /// etiqueta contra el catálogo actual. Una etiqueta aún ausente del catálogo
  /// se ignora (la reconcilia el próximo load): sin nombre no hay blob que
  /// pintar, como en el sheet.
  void _applyChatDelta(WaChatLabelChanged e) {
    if (isClosed) return;
    final s = state;
    WaLabel? label;
    for (final l in s.catalog) {
      if (l.waLabelId == e.waLabelId) {
        label = l;
        break;
      }
    }
    if (label == null) return;
    final byChat = <String, List<WaLabel>>{
      for (final entry in s.byChat.entries)
        entry.key: List<WaLabel>.of(entry.value),
    };
    final current = byChat.putIfAbsent(e.chatLid, () => <WaLabel>[])
      ..removeWhere((l) => l.waLabelId == e.waLabelId);
    if (e.labeled) current.add(label);
    if (current.isEmpty) byChat.remove(e.chatLid);
    emit(InboxLabelsState(catalog: s.catalog, byChat: byChat));
  }

  Future<void> load() async {
    try {
      final catalogRaw = await _repo.listCatalog(_botId);
      final assocs = await _repo.listChatAssocs(_botId);

      final catalog = <WaLabel>[
        for (final l in catalogRaw)
          if (!l.deleted) l,
      ];
      final byId = <String, WaLabel>{for (final l in catalog) l.waLabelId: l};

      final byChat = <String, List<WaLabel>>{};
      for (final a in assocs) {
        if (!a.labeled) continue;
        final label = byId[a.waLabelId];
        if (label == null) continue;
        byChat.putIfAbsent(a.chatLid, () => <WaLabel>[]).add(label);
      }

      if (isClosed) return;
      emit(InboxLabelsState(catalog: catalog, byChat: byChat));
    } catch (_) {
      if (isClosed) return;
      emit(const InboxLabelsState());
    }
  }

  @override
  Future<void> close() {
    _liveSub?.cancel();
    return super.close();
  }
}
