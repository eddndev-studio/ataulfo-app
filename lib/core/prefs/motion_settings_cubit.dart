import 'package:flutter_bloc/flutter_bloc.dart';

import '../storage/secure_kv_store.dart';

/// Preferencia global de animaciones de la interfaz (opt-out: default ON).
///
/// Estado = `true` cuando la app anima. Persiste en el [SecureKvStore] de la
/// app (el mismo del device_id): sobrevive al logout — es una preferencia del
/// dispositivo, no de la cuenta — y a diferencia de la DB local no se purga
/// entre sesiones.
///
/// El design system NO lee este cubit: la composición lo proyecta como
/// `AppMotion` (InheritedWidget) sobre el navigator, y el kit consulta esa
/// señal ambiental.
class MotionSettingsCubit extends Cubit<bool> {
  MotionSettingsCubit(this._store, {bool initial = true}) : super(initial);

  static const String storageKey = 'ui.animations_enabled';

  final SecureKvStore _store;

  /// Lee la preferencia persistida antes del primer frame. Solo el literal
  /// `'false'` apaga: clave ausente o corrupta caen al default encendido.
  static Future<MotionSettingsCubit> load(SecureKvStore store) async {
    final raw = await store.read(storageKey);
    return MotionSettingsCubit(store, initial: raw != 'false');
  }

  /// Emite primero (la UI responde al instante) y persiste después. Un storage
  /// roto no revierte ni crashea: la preferencia es cosmética — peor caso, no
  /// sobrevive al reinicio.
  Future<void> setEnabled(bool value) async {
    emit(value);
    try {
      await _store.write(storageKey, value ? 'true' : 'false');
    } catch (_) {
      // Best-effort: sin storage la preferencia vive lo que viva el proceso.
    }
  }
}
