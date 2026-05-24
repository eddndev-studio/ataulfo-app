import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/dio_client.dart';
import 'core/router/app_router.dart';
import 'core/storage/secure_kv_store.dart';
import 'features/auth/data/datasources/auth_datasource.dart';
import 'features/auth/data/repositories/token_storage.dart';

/// Punto de entrada. Composición manual de dependencias — sin DI framework
/// hasta que un slice futuro lo justifique.
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
  final dio = DioClient.create(baseUrl: baseUrl);
  final ds = DioAuthDatasource(dio);
  final router = AppRouter(authDatasource: ds, tokenStorage: storage);

  runApp(AgenticApp(router: router));
}
