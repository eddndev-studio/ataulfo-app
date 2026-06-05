import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../labels/domain/entities/label.dart';
import '../../../labels/domain/failures/labels_failure.dart';
import '../../../labels/domain/repositories/labels_repository.dart';
import '../../domain/entities/wa_label.dart';
import '../../domain/entities/wa_label_mapping.dart';
import '../../domain/failures/wa_labels_failure.dart';
import '../../domain/repositories/wa_labels_repository.dart';

/// Bloc del mapeo etiqueta-WhatsApp ↔ Label interno de un bot (S21, Dirección 2).
/// Une tres lecturas: el catálogo WA (activas), los mapeos vigentes, y los
/// Labels internos de la org (para el selector y para resolver el nombre/color
/// del label mapeado). El set/clear NO empuja a WhatsApp: es metadata interna
/// que decide qué automatización dispara la etiqueta.
///
/// El set/clear aplica el cambio al estado TRAS confirmar el HTTP (no antes:
/// no es optimista, así que no necesita rollback); los mapeos no tienen
/// realtime. Ante fallo, `MutationFailed` preserva el snapshot para que el
/// selector muestre el error (p. ej. 422: el Label ya no existe en la org).
class WaLabelMappingBloc extends Bloc<WaMappingEvent, WaMappingState> {
  WaLabelMappingBloc({
    required WaLabelsRepository waRepo,
    required LabelsRepository labelsRepo,
    required String botId,
  }) : _wa = waRepo,
       _labels = labelsRepo,
       _botId = botId,
       super(const WaMappingLoading()) {
    on<WaMappingLoadRequested>(_onLoad);
    on<WaMappingSetRequested>(_onSet);
    on<WaMappingClearRequested>(_onClear);
  }

  final WaLabelsRepository _wa;
  final LabelsRepository _labels;
  final String _botId;

  String get botId => _botId;

  Future<void> _onLoad(
    WaMappingLoadRequested event,
    Emitter<WaMappingState> emit,
  ) async {
    if (state is! WaMappingLoading) {
      emit(const WaMappingLoading());
    }
    try {
      // Concurrente con Future.wait: escucha las tres a la vez, así un fallo de
      // una NO deja las otras como errores async sin capturar (lo que pasaría
      // con awaits secuenciales si la primera lanza antes de awaitar el resto).
      final results = await Future.wait<Object>(<Future<Object>>[
        _wa.listCatalog(_botId),
        _wa.listMappings(_botId),
        _labels.listLabels(),
      ]);
      final catalog = results[0] as List<WaLabel>;
      final mappings = results[1] as List<WaLabelMapping>;
      final internal = results[2] as List<Label>;
      emit(
        WaMappingLoaded(
          WaMappingData(
            waLabels: <WaLabel>[
              for (final l in catalog)
                if (!l.deleted) l,
            ],
            mappings: <String, String>{
              for (final m in mappings) m.waLabelId: m.labelId,
            },
            internalLabels: internal,
          ),
        ),
      );
    } on WaLabelsFailure catch (f) {
      emit(WaMappingFailed(_errorFromWa(f)));
    } on LabelsFailure catch (f) {
      emit(WaMappingFailed(_errorFromLabels(f)));
    }
  }

  Future<void> _onSet(
    WaMappingSetRequested event,
    Emitter<WaMappingState> emit,
  ) async {
    await _runMutation(emit, (data) async {
      await _wa.setMapping(
        botId: _botId,
        waLabelId: event.waLabelId,
        labelId: event.labelId,
      );
      return data.copyWith(
        mappings: <String, String>{
          ...data.mappings,
          event.waLabelId: event.labelId,
        },
      );
    });
  }

  Future<void> _onClear(
    WaMappingClearRequested event,
    Emitter<WaMappingState> emit,
  ) async {
    await _runMutation(emit, (data) async {
      await _wa.deleteMapping(botId: _botId, waLabelId: event.waLabelId);
      final next = Map<String, String>.of(data.mappings)
        ..remove(event.waLabelId);
      return data.copyWith(mappings: next);
    });
  }

  Future<void> _runMutation(
    Emitter<WaMappingState> emit,
    Future<WaMappingData> Function(WaMappingData data) mutate,
  ) async {
    final current = state;
    final WaMappingData snapshot;
    if (current is WaMappingLoaded) {
      snapshot = current.data;
    } else if (current is WaMappingMutationFailed) {
      snapshot = current.data;
    } else {
      return;
    }
    emit(WaMappingMutating(snapshot));
    try {
      emit(WaMappingLoaded(await mutate(snapshot)));
    } on WaLabelsFailure catch (f) {
      emit(WaMappingMutationFailed(snapshot, f));
    }
  }

  static WaMappingError _errorFromWa(WaLabelsFailure f) => switch (f) {
    WaLabelsForbiddenFailure() => WaMappingError.forbidden,
    WaLabelsNotFoundFailure() => WaMappingError.notFound,
    WaLabelsNetworkFailure() ||
    WaLabelsTimeoutFailure() => WaMappingError.network,
    _ => WaMappingError.generic,
  };

  static WaMappingError _errorFromLabels(LabelsFailure f) => switch (f) {
    LabelsForbiddenFailure() => WaMappingError.forbidden,
    LabelsNetworkFailure() || LabelsTimeoutFailure() => WaMappingError.network,
    _ => WaMappingError.generic,
  };
}

/// Vista unida que consume la pantalla de mapeo.
class WaMappingData {
  const WaMappingData({
    required this.waLabels,
    required this.mappings,
    required this.internalLabels,
  });

  /// Etiquetas WhatsApp activas (sin tombstones).
  final List<WaLabel> waLabels;

  /// `waLabelId → labelId` interno.
  final Map<String, String> mappings;

  /// Labels internos de la org (selector + resolución de nombre/color).
  final List<Label> internalLabels;

  /// El Label interno al que mapea una etiqueta WA, o `null` si no está mapeada
  /// (o si el mapeo apunta a un Label que ya no existe en la org).
  Label? mappedLabel(String waLabelId) {
    final id = mappings[waLabelId];
    if (id == null) return null;
    for (final l in internalLabels) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Labels internos que el selector puede ofrecer al editar el vínculo de
  /// [waLabelId]: todos los de la org MENOS los ya vinculados a OTRA etiqueta
  /// WhatsApp del bot. El Label que esta misma etiqueta ya tiene vinculado SÍ se
  /// incluye, para mostrarlo marcado y permitir quitarlo. Refleja en la UI la
  /// exclusividad 1:1 que el backend enforza (un Label interno lo otorga a lo
  /// sumo una etiqueta WhatsApp por bot): oculta lo que un set chocaría con 409,
  /// sin esperar al rechazo del servidor.
  List<Label> selectableLabelsFor(String waLabelId) {
    final own = mappings[waLabelId];
    // Solo los mapeos de etiquetas WhatsApp ACTIVAS bloquean una org-label. Un
    // mapeo huérfano (su etiqueta WhatsApp fue borrada ⇒ ausente de waLabels)
    // dejaría su org-label inseleccionable para siempre; lo ignoramos. Defensa
    // de cliente: el backend ya limpia el mapeo al recibir label.wa.removed.
    final activeWa = <String>{for (final w in waLabels) w.waLabelId};
    final takenByOthers = <String>{
      for (final e in mappings.entries)
        if (e.key != waLabelId && activeWa.contains(e.key)) e.value,
    }..remove(own);
    return <Label>[
      for (final l in internalLabels)
        if (!takenByOthers.contains(l.id)) l,
    ];
  }

  WaMappingData copyWith({Map<String, String>? mappings}) => WaMappingData(
    waLabels: waLabels,
    mappings: mappings ?? this.mappings,
    internalLabels: internalLabels,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WaMappingData) return false;
    if (other.waLabels.length != waLabels.length) return false;
    for (var i = 0; i < waLabels.length; i++) {
      if (other.waLabels[i] != waLabels[i]) return false;
    }
    if (other.internalLabels.length != internalLabels.length) return false;
    for (var i = 0; i < internalLabels.length; i++) {
      if (other.internalLabels[i] != internalLabels[i]) return false;
    }
    if (other.mappings.length != mappings.length) return false;
    for (final e in mappings.entries) {
      if (other.mappings[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(waLabels),
    Object.hashAll(internalLabels),
    Object.hashAllUnordered(mappings.entries.map((e) => '${e.key}=${e.value}')),
  );
}

/// Motivo del fallo de carga (unifica las dos taxonomías de failure de las
/// fuentes que la pantalla une).
enum WaMappingError { forbidden, notFound, network, generic }

// Events --------------------------------------------------------------------

sealed class WaMappingEvent {
  const WaMappingEvent();
}

class WaMappingLoadRequested extends WaMappingEvent {
  const WaMappingLoadRequested();
  @override
  bool operator ==(Object other) => other is WaMappingLoadRequested;
  @override
  int get hashCode => (WaMappingLoadRequested).hashCode;
}

class WaMappingSetRequested extends WaMappingEvent {
  const WaMappingSetRequested({required this.waLabelId, required this.labelId});

  final String waLabelId;
  final String labelId;

  @override
  bool operator ==(Object other) =>
      other is WaMappingSetRequested &&
      other.waLabelId == waLabelId &&
      other.labelId == labelId;
  @override
  int get hashCode => Object.hash(waLabelId, labelId);
}

class WaMappingClearRequested extends WaMappingEvent {
  const WaMappingClearRequested({required this.waLabelId});

  final String waLabelId;

  @override
  bool operator ==(Object other) =>
      other is WaMappingClearRequested && other.waLabelId == waLabelId;
  @override
  int get hashCode => waLabelId.hashCode;
}

// States --------------------------------------------------------------------

sealed class WaMappingState {
  const WaMappingState();
}

class WaMappingLoading extends WaMappingState {
  const WaMappingLoading();
  @override
  bool operator ==(Object other) => other is WaMappingLoading;
  @override
  int get hashCode => (WaMappingLoading).hashCode;
}

class WaMappingLoaded extends WaMappingState {
  const WaMappingLoaded(this.data);

  final WaMappingData data;

  @override
  bool operator ==(Object other) =>
      other is WaMappingLoaded && other.data == data;
  @override
  int get hashCode => data.hashCode;
}

class WaMappingFailed extends WaMappingState {
  const WaMappingFailed(this.error);

  final WaMappingError error;

  @override
  bool operator ==(Object other) =>
      other is WaMappingFailed && other.error == error;
  @override
  int get hashCode => error.hashCode;
}

/// Una mutación (set/clear) está en vuelo. Lleva el snapshot para que la lista
/// siga visible mientras el selector dibuja su spinner.
class WaMappingMutating extends WaMappingState {
  const WaMappingMutating(this.data);

  final WaMappingData data;

  @override
  bool operator ==(Object other) =>
      other is WaMappingMutating && other.data == data;
  @override
  int get hashCode => data.hashCode;
}

/// Mutación fallida; preserva el snapshot y la failure (p. ej. 422: el Label ya
/// no existe en la org). El selector interpreta y muestra el copy.
class WaMappingMutationFailed extends WaMappingState {
  const WaMappingMutationFailed(this.data, this.failure);

  final WaMappingData data;
  final WaLabelsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is WaMappingMutationFailed &&
      other.data == data &&
      other.failure == failure;
  @override
  int get hashCode => Object.hash(data, failure);
}
