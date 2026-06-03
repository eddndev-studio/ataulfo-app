/// Muestra una notificación local del sistema. Abstrae el plugin de
/// notificaciones para que la lógica de presentación de push en foreground se
/// pueda probar sin canales de plataforma.
abstract interface class LocalNotifier {
  Future<void> show({String? title, String? body});
}
