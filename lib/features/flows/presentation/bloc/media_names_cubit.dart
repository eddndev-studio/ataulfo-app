import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../media/domain/failures/media_failure.dart';
import '../../../media/domain/repositories/media_repository.dart';

/// Resolutor de nombres del catálogo de media para la lista de pasos de un
/// flujo. Un paso multimedia persiste sólo el `ref` BARE del recurso; este
/// cubit carga el catálogo de la org y expone un mapa ref→`displayName` (alias
/// o filename) para que la lista muestre el nombre legible —y EN VIVO— en vez
/// del ref opaco. Read-only: no muta el catálogo.
class MediaNamesState {
  const MediaNamesState({
    this.namesByRef = const <String, String>{},
    this.loaded = false,
  });

  /// Mapa ref BARE → `displayName` del asset (alias si existe, si no filename).
  final Map<String, String> namesByRef;

  /// True una vez que la carga terminó (con o sin éxito). Mientras es false la
  /// lista no puede afirmar ausencia: un ref sin entrada está "aún cargando",
  /// no "borrado".
  final bool loaded;

  /// `displayName` resuelto para [ref], o null si no está en el catálogo
  /// (aún no cargado, o asset borrado).
  String? nameFor(String ref) => namesByRef[ref];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MediaNamesState || other.loaded != loaded) return false;
    if (other.namesByRef.length != namesByRef.length) return false;
    for (final entry in namesByRef.entries) {
      if (other.namesByRef[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    loaded,
    Object.hashAllUnordered(
      namesByRef.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

class MediaNamesCubit extends Cubit<MediaNamesState> {
  MediaNamesCubit({required MediaRepository repo})
    : _repo = repo,
      super(const MediaNamesState());

  final MediaRepository _repo;

  /// Tope de páginas a recorrer: un catálogo enorme no debe colgar la apertura
  /// del flujo. Lo no recorrido cae al respaldo (filename/cola corta del ref).
  static const int _maxPages = 50;

  /// Carga el catálogo completo (todas las páginas) y construye el mapa
  /// ref→displayName. Un fallo de red/server NO es fatal: se emite lo que se
  /// haya acumulado con `loaded:true` y la lista usa su respaldo por paso.
  Future<void> load() async {
    final names = <String, String>{};
    String? cursor;
    var pages = 0;
    try {
      while (pages < _maxPages) {
        final page = await _repo.listAssets(cursor: cursor);
        for (final asset in page.assets) {
          names[asset.ref] = asset.displayName;
        }
        pages++;
        if (page.nextCursor.isEmpty) break;
        cursor = page.nextCursor;
      }
    } on MediaFailure {
      // Catálogo no disponible: la lista cae al respaldo por paso.
    }
    if (isClosed) return;
    emit(MediaNamesState(namesByRef: names, loaded: true));
  }
}
