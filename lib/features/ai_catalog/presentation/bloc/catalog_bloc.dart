import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/catalog.dart';
import '../../domain/failures/catalog_failure.dart';
import '../../domain/repositories/catalog_repository.dart';

/// Bloc del catálogo IA. Se monta page-scoped: el editor de AIConfig
/// dispara `LoadRequested` al abrirse para alimentar los pickers de
/// provider/model. Sin Refresh event — la tabla es estática del lado
/// backend; un retry desde Failed reusa LoadRequested.
class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  CatalogBloc(this._repo) : super(const CatalogInitial()) {
    on<CatalogLoadRequested>(_onLoad);
  }

  final CatalogRepository _repo;

  Future<void> _onLoad(
    CatalogLoadRequested event,
    Emitter<CatalogState> emit,
  ) async {
    emit(const CatalogLoading());
    try {
      final catalog = await _repo.fetch();
      emit(CatalogLoaded(catalog: catalog));
    } on CatalogFailure catch (f) {
      emit(CatalogFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class CatalogEvent {
  const CatalogEvent();
}

class CatalogLoadRequested extends CatalogEvent {
  const CatalogLoadRequested();

  @override
  bool operator ==(Object other) => other is CatalogLoadRequested;
  @override
  int get hashCode => (CatalogLoadRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class CatalogState {
  const CatalogState();
}

class CatalogInitial extends CatalogState {
  const CatalogInitial();
  @override
  bool operator ==(Object other) => other is CatalogInitial;
  @override
  int get hashCode => (CatalogInitial).hashCode;
}

class CatalogLoading extends CatalogState {
  const CatalogLoading();
  @override
  bool operator ==(Object other) => other is CatalogLoading;
  @override
  int get hashCode => (CatalogLoading).hashCode;
}

class CatalogLoaded extends CatalogState {
  const CatalogLoaded({required this.catalog});

  final Catalog catalog;

  @override
  bool operator ==(Object other) =>
      other is CatalogLoaded && other.catalog == catalog;

  @override
  int get hashCode => catalog.hashCode;
}

class CatalogFailed extends CatalogState {
  const CatalogFailed(this.failure);

  final CatalogFailure failure;

  @override
  bool operator ==(Object other) =>
      other is CatalogFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
