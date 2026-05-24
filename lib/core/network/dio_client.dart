import 'package:dio/dio.dart';

/// Construye la instancia de Dio que consumen los datasources.
///
/// `baseUrl` viaja desde la composición — sin globals. El interceptor de
/// Bearer + rotación de refresh entra en su slice (no es responsabilidad
/// del slice de login el resolver el bucle 401→/auth/refresh→401).
class DioClient {
  const DioClient._();

  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _receiveTimeout = Duration(seconds: 30);

  static Dio create({required String baseUrl}) => Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
      sendTimeout: _connectTimeout,
      responseType: ResponseType.json,
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
}
