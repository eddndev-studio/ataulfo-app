import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/dio_client.dart';
import 'core/router/app_router.dart';
import 'core/storage/device_id_provider.dart';
import 'core/storage/secure_kv_store.dart';
import 'features/auth/data/datasources/auth_datasource.dart';
import 'features/auth/data/interceptors/auth_interceptor.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/data/repositories/token_storage.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/bots/data/datasources/bots_datasource.dart';
import 'features/bots/data/repositories/bots_repository_impl.dart';
import 'features/memberships/data/datasources/memberships_datasource.dart';
import 'features/memberships/data/repositories/memberships_repository_impl.dart';
import 'features/templates/data/datasources/templates_datasource.dart';
import 'features/templates/data/repositories/templates_repository_impl.dart';

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

  // `late` difiere la captura del bloc: la closure de onUnrecoverable se
  // construye antes que `authBloc`, pero solo se ejecuta en runtime.
  late final AuthBloc authBloc;

  mainDio.interceptors.add(
    AuthInterceptor(
      retryDio: mainDio,
      storage: storage,
      refreshDatasource: refreshDs,
      onUnrecoverable: () async {
        // El interceptor ya purgó el storage; re-disparamos el check
        // para que el bloc colapse a Unauthenticated y el redirect
        // navegue a /login. Una sola entrada al cambio de estado.
        authBloc.add(const AuthCheckRequested());
      },
    ),
  );

  final mainDs = DioAuthDatasource(mainDio);
  final authRepository = AuthRepositoryImpl(
    datasource: mainDs,
    storage: storage,
  );
  authBloc = AuthBloc(authRepository);

  final botsRepository = BotsRepositoryImpl(
    datasource: DioBotsDatasource(mainDio),
  );

  final templatesRepository = TemplatesRepositoryImpl(
    datasource: DioTemplatesDatasource(mainDio),
  );

  final membershipsRepository = MembershipsRepositoryImpl(
    datasource: DioMembershipsDatasource(mainDio),
  );

  final router = AppRouter(
    authBloc: authBloc,
    authRepository: authRepository,
    botsRepository: botsRepository,
    templatesRepository: templatesRepository,
    membershipsRepository: membershipsRepository,
  );

  // Dispara el check inicial: lee storage, si hay tokens valida con
  // /auth/me, emite Authenticated o Unauthenticated. El Splash se queda
  // hasta que el primer estado no-Initial llegue.
  authBloc.add(const AuthCheckRequested());

  // Fire-and-forget: el device_id queda persistido en cuanto pueda. Los
  // consumidores reales (refresh family, registro FCM) ocurren post-login —
  // hay tiempo de sobra para que el primer `getOrCreate` termine antes que
  // alguien lo lea. Nacer estable hoy evita rotar familias el día que
  // aterrice el slice de push.
  unawaited(DeviceIdProvider(kv).getOrCreate());

  runApp(AgenticApp(router: router, authBloc: authBloc));
}
