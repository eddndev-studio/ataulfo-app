import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/dio_client.dart';
import 'core/router/app_router.dart';
import 'core/storage/device_id_provider.dart';
import 'core/storage/secure_kv_store.dart';
import 'features/auth/data/datasources/auth_datasource.dart';
import 'features/auth/data/interceptors/auth_interceptor.dart';
import 'features/auth/data/repositories/token_storage.dart';

/// Punto de entrada. Composición manual de dependencias — sin DI framework
/// hasta que un slice futuro lo justifique.
///
/// Dos instancias de Dio:
/// - `refreshDio`: SIN interceptor. Lo usa el AuthInterceptor para canjear
///   contra `/auth/refresh`. Romper el bucle 401→refresh→401 por
///   CONSTRUCCIÓN (instancia separada) es más fuerte que detectarlo por
///   URL — un cambio futuro de path no rompe la garantía.
/// - `mainDio`: con interceptor. Todos los endpoints de negocio salen por
///   aquí; Bearer + retry transparente del 401 son responsabilidad del
///   interceptor, no de los datasources.
///
/// `baseUrl` debe apuntar al `agentic-go` real. En desarrollo se usa el
/// localhost del emulador Android (`10.0.2.2`). Para producción se configura
/// en su slice (env por flavor, build-time arg, o pantalla de settings).
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const baseUrl = String.fromEnvironment(
    'AGENTIC_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  final kv = FlutterSecureKvStore();
  final storage = TokenStorage(kv);

  final refreshDio = DioClient.create(baseUrl: baseUrl);
  final refreshDs = DioAuthDatasource(refreshDio);

  final mainDio = DioClient.create(baseUrl: baseUrl);

  // `late` difiere la captura: la closure de onUnrecoverable se construye
  // antes que `router`, pero solo se ejecuta en runtime, cuando `router`
  // ya está asignada.
  late final AppRouter router;

  mainDio.interceptors.add(
    AuthInterceptor(
      retryDio: mainDio,
      storage: storage,
      refreshDatasource: refreshDs,
      onUnrecoverable: () async {
        router.router.go('/login');
      },
    ),
  );

  final loginDs = DioAuthDatasource(mainDio);
  router = AppRouter(authDatasource: loginDs, tokenStorage: storage);

  // Fire-and-forget: el device_id queda persistido en cuanto pueda. Los
  // consumidores reales (refresh family, registro FCM) ocurren post-login —
  // hay tiempo de sobra para que el primer `getOrCreate` termine antes que
  // alguien lo lea. Nacer estable hoy evita rotar familias el día que
  // aterrice el slice de push.
  unawaited(DeviceIdProvider(kv).getOrCreate());

  runApp(AgenticApp(router: router));
}
