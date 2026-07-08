import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/entitlement_bloc.dart';

/// Proveedores elegibles según el entitlement de la superficie, o `null` si
/// aún no hay verdad utilizable — y `null` significa NO FILTRAR (el backend
/// valida de todas formas; bloquear a ciegas sería peor que mostrar de más).
///
/// El lookup es del tipo NULABLE a propósito: un `EntitlementBloc` puede no
/// estar montado (rutas sin repo de billing, hosts de test) y eso degrada
/// igual que un entitlement en carga o fallido, sin ProviderNotFound.
/// `watch` suscribe al widget: cuando el bloc pase a Loaded, el consumidor
/// se reconstruye y el filtro aparece solo.
Set<String>? watchEligibleProviders(BuildContext context) {
  final state = context.watch<EntitlementBloc?>()?.state;
  return state is EntitlementLoaded
      ? state.entitlement.eligibleProviders
      : null;
}
