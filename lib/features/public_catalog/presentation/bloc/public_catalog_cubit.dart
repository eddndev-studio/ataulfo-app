import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/catalog_appearance.dart';
import '../../domain/entities/public_catalog_settings.dart';
import '../../domain/failures/public_catalog_failure.dart';
import '../../domain/repositories/public_catalog_repository.dart';

enum PublicCatalogStatus { loading, loaded, error }

/// Estado del catálogo público de la org: la carga inicial (status + settings o
/// loadFailure) y el pulso de guardado (saving + saveFailure). El guardado
/// conserva los settings vigentes hasta que llega el nuevo estado.
class PublicCatalogState {
  const PublicCatalogState({
    required this.status,
    required this.settings,
    required this.loadFailure,
    required this.saving,
    required this.saveFailure,
  });

  const PublicCatalogState.loading()
    : status = PublicCatalogStatus.loading,
      settings = null,
      loadFailure = null,
      saving = false,
      saveFailure = null;

  final PublicCatalogStatus status;
  final PublicCatalogSettings? settings;
  final PublicCatalogFailure? loadFailure;
  final bool saving;
  final PublicCatalogFailure? saveFailure;

  PublicCatalogState copyWith({
    PublicCatalogStatus? status,
    PublicCatalogSettings? settings,
    PublicCatalogFailure? loadFailure,
    bool? saving,
    PublicCatalogFailure? saveFailure,
    bool clearSaveFailure = false,
  }) => PublicCatalogState(
    status: status ?? this.status,
    settings: settings ?? this.settings,
    loadFailure: loadFailure ?? this.loadFailure,
    saving: saving ?? this.saving,
    saveFailure: clearSaveFailure ? null : (saveFailure ?? this.saveFailure),
  );
}

/// Carga y guarda los ajustes del catálogo público. El guardado devuelve el
/// estado como quedó en el backend (fuente de verdad del slug/url): la vista
/// nunca adivina el slug generado ni la URL.
class PublicCatalogCubit extends Cubit<PublicCatalogState> {
  PublicCatalogCubit(this._repo) : super(const PublicCatalogState.loading());

  final PublicCatalogRepository _repo;

  Future<void> load() async {
    emit(const PublicCatalogState.loading());
    try {
      final s = await _repo.get();
      if (isClosed) return;
      emit(
        PublicCatalogState(
          status: PublicCatalogStatus.loaded,
          settings: s,
          loadFailure: null,
          saving: false,
          saveFailure: null,
        ),
      );
    } on PublicCatalogFailure catch (f) {
      if (isClosed) return;
      emit(
        PublicCatalogState(
          status: PublicCatalogStatus.error,
          settings: null,
          loadFailure: f,
          saving: false,
          saveFailure: null,
        ),
      );
    }
  }

  /// Aplica toggle + slug + apariencia (design/accent). Éxito ⇒ settings del
  /// backend; falla ⇒ saveFailure (la vista muestra el copy y conserva lo que
  /// ya se veía).
  Future<void> save({
    required bool enabled,
    required String slug,
    required CatalogDesign design,
    required CatalogAccent accent,
  }) async {
    if (state.saving) return;
    emit(state.copyWith(saving: true, clearSaveFailure: true));
    try {
      final s = await _repo.update(
        enabled: enabled,
        slug: slug,
        design: design,
        accent: accent,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          status: PublicCatalogStatus.loaded,
          settings: s,
          saving: false,
          clearSaveFailure: true,
        ),
      );
    } on PublicCatalogFailure catch (f) {
      if (isClosed) return;
      emit(state.copyWith(saving: false, saveFailure: f));
    }
  }
}
