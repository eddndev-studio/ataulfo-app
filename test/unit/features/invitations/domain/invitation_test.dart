import 'package:ataulfo/features/invitations/domain/entities/invitation.dart';
import 'package:flutter_test/flutter_test.dart';

Invitation _inv({
  String id = 'i1',
  String email = 'a@x.com',
  String role = 'WORKER',
  String status = 'PENDING',
  DateTime? expiresAt,
  DateTime? createdAt,
  List<String> botIds = const <String>['b1'],
}) => Invitation(
  id: id,
  email: email,
  role: role,
  status: status,
  botIds: botIds,
  expiresAt: expiresAt ?? DateTime.utc(2026, 1, 2),
  createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
);

void main() {
  group('Invitation', () {
    test('expone los campos del contrato', () {
      final inv = _inv();
      expect(inv.id, 'i1');
      expect(inv.email, 'a@x.com');
      expect(inv.role, 'WORKER');
      expect(inv.status, 'PENDING');
      expect(inv.botIds, <String>['b1']);
      expect(inv.expiresAt, DateTime.utc(2026, 1, 2));
      expect(inv.createdAt, DateTime.utc(2026, 1, 1));
    });

    test('dos Invitation con misma data son iguales (value-type)', () {
      expect(_inv(), _inv());
      expect(_inv().hashCode, _inv().hashCode);
    });

    test('difieren si cambia un campo', () {
      expect(_inv(), isNot(_inv(status: 'CANCELED')));
      expect(_inv(), isNot(_inv(email: 'b@x.com')));
      expect(_inv(), isNot(_inv(botIds: const <String>['b2'])));
    });
  });

  group('Invitation.isExpired', () {
    final expiry = DateTime.utc(2026, 6, 1, 12);

    test('PENDING y now después de expiresAt → expirada', () {
      final inv = _inv(status: 'PENDING', expiresAt: expiry);
      expect(inv.isExpired(DateTime.utc(2026, 6, 1, 13)), isTrue);
    });

    test('PENDING y now antes de expiresAt → no expirada', () {
      final inv = _inv(status: 'PENDING', expiresAt: expiry);
      expect(inv.isExpired(DateTime.utc(2026, 6, 1, 11)), isFalse);
    });

    test('ACCEPTED nunca cuenta como expirada (aunque pasó la fecha)', () {
      final inv = _inv(status: 'ACCEPTED', expiresAt: expiry);
      expect(inv.isExpired(DateTime.utc(2026, 6, 1, 13)), isFalse);
    });

    test('CANCELED nunca cuenta como expirada', () {
      final inv = _inv(status: 'CANCELED', expiresAt: expiry);
      expect(inv.isExpired(DateTime.utc(2026, 6, 1, 13)), isFalse);
    });

    test('compara instantes aunque now sea local y expiresAt UTC', () {
      // expiresAt viene UTC del wire (sufijo Z); isAfter compara instantes.
      final inv = _inv(status: 'PENDING', expiresAt: DateTime.utc(2026, 6, 1));
      expect(inv.isExpired(DateTime.utc(2026, 6, 2).toLocal()), isTrue);
    });
  });
}
