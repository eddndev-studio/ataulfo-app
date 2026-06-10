/// Muestra una notificación local del sistema. Abstrae el plugin de
/// notificaciones para que la lógica de presentación de push en foreground se
/// pueda probar sin canales de plataforma.
abstract interface class LocalNotifier {
  /// [payload] viaja opaco con la notificación y vuelve al tocarla — es el
  /// `data` del push serializado, con el que se resuelve la navegación.
  Future<void> show({String? title, String? body, String? payload});
}
