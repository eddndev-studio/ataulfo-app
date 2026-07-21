import 'package:ataulfo/core/auth/role_privilege.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isSupervisorOrAbove', () {
    test('OWNER, ADMIN y SUPERVISOR tienen herramientas globales', () {
      expect(isSupervisorOrAbove('OWNER'), isTrue);
      expect(isSupervisorOrAbove('ADMIN'), isTrue);
      expect(isSupervisorOrAbove('SUPERVISOR'), isTrue);
    });

    test('WORKER y roles desconocidos fallan cerrado', () {
      expect(isSupervisorOrAbove('WORKER'), isFalse);
      expect(isSupervisorOrAbove('ROOT'), isFalse);
      expect(isSupervisorOrAbove('supervisor'), isFalse);
      expect(isSupervisorOrAbove(''), isFalse);
    });
  });

  group('isAdminOrAbove', () {
    // El gateo de cliente debe espejar el guard `adminOnly` del backend
    // (`RequireRole(RoleAdmin)` = `AtLeast(RoleAdmin)`). Con la jerarquía
    // OWNER > ADMIN > SUPERVISOR > WORKER, "Admin o superior" = {ADMIN, OWNER}.
    // SUPERVISOR queda por DEBAJO de ADMIN: el backend lo rechaza con 403 en
    // toda mutación/op de sesión, así que el cliente NO debe mostrarle esos
    // controles. Mostrar un botón que siempre 403ea es peor UX que ocultarlo.
    test('OWNER → true', () {
      expect(isAdminOrAbove('OWNER'), isTrue);
    });

    test('ADMIN → true', () {
      expect(isAdminOrAbove('ADMIN'), isTrue);
    });

    test('SUPERVISOR → false (por debajo de ADMIN: el backend lo 403ea)', () {
      expect(isAdminOrAbove('SUPERVISOR'), isFalse);
    });

    test('WORKER → false', () {
      expect(isAdminOrAbove('WORKER'), isFalse);
    });

    test('string desconocido → false (fail-closed)', () {
      expect(isAdminOrAbove('PLATFORM_GOD'), isFalse);
    });

    test('casing distinto al del wire → false (fail-closed)', () {
      // El rol viaja UPPERCASE en el claim (set cerrado del backend). Un
      // token con casing distinto es drift; fail-closed evita conceder
      // privilegios por una coincidencia laxa.
      expect(isAdminOrAbove('admin'), isFalse);
      expect(isAdminOrAbove('Owner'), isFalse);
    });

    test('vacío → false (fail-closed)', () {
      expect(isAdminOrAbove(''), isFalse);
    });
  });
}
