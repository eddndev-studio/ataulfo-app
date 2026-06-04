/// Extrae el token de un correo de acción (reset de contraseña, verificación
/// de email) de lo que el operador pega: o bien el enlace completo que recibió
/// (`…?token=…`), o bien el token crudo si lo copió suelto.
///
/// Estos correos abren el SERVIDOR, no la app; no hay deep-link que rellene el
/// campo. Por eso el operador pega texto a mano y esta función tolera las dos
/// formas: si el texto parsea como URL con un parámetro `token`, devuelve ese
/// valor (el parser de `Uri` ya lo decodifica una vez, así que un token
/// percent-encoded sale con sus caracteres literales); si no, trata el texto
/// recortado como el token mismo. Una cadena en blanco devuelve vacío para que
/// el llamador la rechace como entrada inválida.
String extractPastedToken(String pasted) {
  final trimmed = pasted.trim();
  if (trimmed.isEmpty) return '';
  final uri = Uri.tryParse(trimmed);
  final token = uri?.queryParameters['token'];
  if (token != null && token.isNotEmpty) return token;
  return trimmed;
}
