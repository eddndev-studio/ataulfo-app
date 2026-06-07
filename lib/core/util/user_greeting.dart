/// Deriva un saludo y una inicial de avatar a partir del email del usuario.
///
/// La sesión solo expone `email` (no hay nombre de display), así que el nombre
/// se toma de la parte local del email, capitalizada. Función pura: el llamador
/// lee el email de la sesión y compone con esto sin estado.
///
/// `greeting` usa "Bienvenido" (masculino por defecto: no hay dato de género en
/// la sesión); el copy es fácil de cambiar a una forma neutral si se decide.
({String greeting, String initial}) userGreeting(String email) {
  final local = email.contains('@') ? email.split('@').first : email;
  final trimmed = local.trim();
  if (trimmed.isEmpty) {
    return (greeting: 'Te damos la bienvenida', initial: '?');
  }
  final name = trimmed[0].toUpperCase() + trimmed.substring(1);
  return (greeting: 'Bienvenido, $name', initial: name[0].toUpperCase());
}
