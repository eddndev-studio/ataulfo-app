/// Saneado y validación local del teléfono para pair-phone (vinculación por
/// código). Espejo de las reglas de whatsmeow y de la web (misma copy): el
/// wire exige formato internacional en dígitos pelados, sin `+` ni ceros
/// iniciales. La validación previene el 400 (vacío) y las dos causas locales
/// del 422 (corto / cero inicial); el resto del cajón 422 sólo lo conoce el
/// backend.
library;

/// Deja solo los dígitos: pela `+`, espacios, guiones, paréntesis y cualquier
/// otra decoración. Lo que viaja al wire es SIEMPRE este saneado.
String saneaTelefono(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');

/// `null` si el teléfono es válido; si no, la copy del error para mostrar en
/// sitio. Valida sobre el saneado, así el call site puede pasar el texto
/// crudo del campo. El largo se revisa ANTES que el cero inicial.
String? validaTelefono(String telefono) {
  final digitos = saneaTelefono(telefono);
  if (digitos.length < 7) {
    return 'Escribe el número completo con lada.';
  }
  if (digitos.startsWith('0')) {
    return 'Quita el 0 inicial: formato internacional.';
  }
  return null;
}
