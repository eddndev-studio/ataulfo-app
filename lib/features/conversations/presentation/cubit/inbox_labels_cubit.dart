import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../wa_labels/domain/entities/wa_label.dart';
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
}
