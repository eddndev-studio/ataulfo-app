/// Failures expuestos por la capa de datos del catálogo de productos.
///
/// Son `Exception` (no `Error`): los cubits las atrapan y traducen a estados
/// de UI. La jerarquía es sellada para forzar a los switches a cubrir todos
/// los casos: un failure nuevo rompe el build, no se cuela silencioso.
///
/// 401 NO aparece aquí: lo absorbe el AuthInterceptor (refresh transparente o
/// purga + Unauthenticated).
sealed class ProductCatalogFailure implements Exception {
  const ProductCatalogFailure();
}

/// Sin conexión, DNS, TLS, connection error. Reintentable.
final class ProductCatalogNetworkFailure extends ProductCatalogFailure {
  const ProductCatalogNetworkFailure();
}

/// Timeout específico (connect/send/receive). Distinto de red para permitir
/// un copy de reintento diferenciado.
final class ProductCatalogTimeoutFailure extends ProductCatalogFailure {
  const ProductCatalogTimeoutFailure();
}

/// 403: el rol no alcanza (crear/editar productos es ADMIN+). El gate de la
/// UI es cosmético; la autoridad es este 403 del servidor.
final class ProductCatalogForbiddenFailure extends ProductCatalogFailure {
  const ProductCatalogForbiddenFailure();
}

/// 404: el producto no existe en la org del operador.
final class ProductCatalogNotFoundFailure extends ProductCatalogFailure {
  const ProductCatalogNotFoundFailure();
}

/// 422: el producto es inválido según el dominio del backend (datos fuera de
/// invariantes, imagen que ya no está en la galería). El backend manda un
/// código estable que el datasource traduce a copy es-MX en [message]; null
/// si el código no se conoce (la UI cae a su copy genérico).
final class ProductCatalogValidationFailure extends ProductCatalogFailure {
  const ProductCatalogValidationFailure([this.message]);

  /// Mensaje explicando por qué se rechazó, o null si el código no se conoce.
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is ProductCatalogValidationFailure && other.message == message;

  @override
  int get hashCode => Object.hash(ProductCatalogValidationFailure, message);
}

/// 5xx del backend. Distinto de red: el servidor respondió, pero rompió.
final class ProductCatalogServerFailure extends ProductCatalogFailure {
  const ProductCatalogServerFailure();
}

/// Cualquier otro caso (status no contemplado, body malformado, type error al
/// castear). El cliente lo expone como error genérico sin filtrar el status.
final class UnknownProductCatalogFailure extends ProductCatalogFailure {
  const UnknownProductCatalogFailure();
}
