import 'package:ataulfo/features/bots/data/dto/connect_token_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectTokenResp.fromJson', () {
    test('parsea token + expiresAt (RFC3339 del backend)', () {
      final dto = ConnectTokenResp.fromJson(<String, dynamic>{
        'token': 'raw-secret-abc',
        'expiresAt': '2026-05-29T12:30:00Z',
      });

      expect(dto.token, 'raw-secret-abc');
      expect(dto.expiresAt, DateTime.utc(2026, 5, 29, 12, 30, 0));
    });
  });
}
