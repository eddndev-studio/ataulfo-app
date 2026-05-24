import 'package:dio/dio.dart';

import '../datasources/auth_datasource.dart';
import '../repositories/token_storage.dart';

/// Interceptor de autenticación para el Dio principal de la app.
///
/// `onRequest` inyecta `Authorization: Bearer <access>` si hay tokens
/// persistidos; en caso contrario deja pasar el request crudo (el
/// interceptor no decide qué ruta exige auth).
///
/// `refreshDatasource` se construye sobre un Dio SEPARADO sin interceptor
/// (rompe el bucle 401→/auth/refresh→401 por construcción, no por
/// inspección de URL).
///
/// `onUnrecoverable` es una señal: el interceptor purga el storage por su
/// cuenta y luego invoca el callback para que el exterior reaccione
/// (p. ej. navegar a /login). Mantener purga e invocación en el
/// interceptor evita doble-borrado y desinforma menos a slices superiores.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio retryDio,
    required TokenStorage storage,
    required AuthDatasource refreshDatasource,
    required Future<void> Function() onUnrecoverable,
  })  : _retryDio = retryDio,
        _storage = storage,
        _refreshDs = refreshDatasource,
        _onUnrecoverable = onUnrecoverable;

  final Dio _retryDio;
  final TokenStorage _storage;
  final AuthDatasource _refreshDs;
  // ignore: unused_field
  final Future<void> Function() _onUnrecoverable;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final tokens = await _storage.read();
    if (tokens != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }
    final tokens = await _storage.read();
    if (tokens == null) {
      handler.next(err);
      return;
    }

    final fresh = await _refreshDs.refresh(tokens.refreshToken);
    await _storage.save(fresh);

    // Limpiar el header viejo: onRequest del retry leerá el storage fresco
    // y reinyectará el Authorization con el access nuevo. Mantiene una sola
    // fuente de verdad del shape del header.
    err.requestOptions.headers.remove('Authorization');
    final retryRes = await _retryDio.fetch<dynamic>(err.requestOptions);
    handler.resolve(retryRes);
  }
}
