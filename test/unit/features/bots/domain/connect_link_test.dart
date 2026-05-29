import 'package:ataulfo/features/bots/domain/entities/connect_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectLink', () {
    final at = DateTime.utc(2026, 5, 29, 12, 0, 0);

    test('igualdad por valor (url + expiresAt)', () {
      expect(
        ConnectLink(url: 'https://h/connect?token=x', expiresAt: at),
        ConnectLink(url: 'https://h/connect?token=x', expiresAt: at),
      );
    });

    test('desigualdad cuando la url difiere', () {
      expect(
        ConnectLink(url: 'https://h/connect?token=x', expiresAt: at),
        isNot(ConnectLink(url: 'https://h/connect?token=y', expiresAt: at)),
      );
    });
  });
}
