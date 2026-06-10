import 'package:ataulfo/core/i18n/role_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('roleLabel traduce los 4 roles del contrato', () {
    expect(roleLabel('OWNER'), 'Propietario');
    expect(roleLabel('ADMIN'), 'Administrador');
    expect(roleLabel('SUPERVISOR'), 'Supervisor');
    expect(roleLabel('WORKER'), 'Agente');
  });

  test('roleLabel cae al crudo ante drift de contrato', () {
    expect(roleLabel('AUDITOR'), 'AUDITOR');
  });

  test('invitationStatusLabel traduce los estados conocidos', () {
    expect(invitationStatusLabel('PENDING'), 'Pendiente');
    expect(invitationStatusLabel('ACCEPTED'), 'Aceptada');
    expect(invitationStatusLabel('CANCELED'), 'Cancelada');
    expect(invitationStatusLabel('EXPIRED'), 'EXPIRED');
  });
}
