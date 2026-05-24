import 'dart:async';

import 'package:dio/dio.dart';

import '../../domain/entities/auth_tokens.dart';
import '../../domain/failures/auth_failure.dart';
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
  }) : _retryDio = retryDio,
       _storage = storage,
       _refreshDs = refreshDatasource,
       _onUnrecoverable = onUnrecoverable;

  final Dio _retryDio;
  final TokenStorage _storage;
  final AuthDatasource _refreshDs;
  final Future<void> Function() _onUnrecoverable;

  /// Serializa refreshes concurrentes. El primero en llegar (leader) ejecuta
  /// el canje contra `/auth/refresh`; el resto (followers) esperan al mismo
  /// Completer. Sin esto, N 401 simultáneos dispararían N refreshes — y el
  /// backend rota la familia por cada uno, así que el segundo en llegar
  /// invalidaría al primero y el cliente quedaría con un par muerto.
  Completer<AuthTokens>? _inFlight;

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

    final isLeader = _inFlight == null;
    final completer = _inFlight ??= Completer<AuthTokens>();
    if (isLeader) {
      try {
        final fresh = await _refreshDs.refresh(tokens.refreshToken);
        await _storage.save(fresh);
        completer.complete(fresh);
      } on AuthFailure catch (e) {
        // Sólo el leader purga y señala: si lo hicieran también los
        // followers, onUnrecoverable se invocaría N veces y el storage
        // sufriría writes redundantes.
        await _storage.clear();
        await _onUnrecoverable();
        completer.completeError(e);
      } finally {
        _inFlight = null;
      }
    }

    try {
      await completer.future;
      // Limpiar el header viejo: onRequest del retry leerá el storage fresco
      // y reinyectará el Authorization con el access nuevo. Mantiene una sola
      // fuente de verdad del shape del header.
      err.requestOptions.headers.remove('Authorization');
      final retryRes = await _retryDio.fetch<dynamic>(err.requestOptions);
      handler.resolve(retryRes);
    } on AuthFailure {
      handler.next(err);
    }
  }
}
