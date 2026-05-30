import 'package:ataulfo/features/profile/data/dto/profile_dto.dart';
import 'package:ataulfo/features/profile/data/mappers/profile_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProfileResp resp({
    String kind = 'DM',
    String? phone = '521555',
    String? photoUrl = 'https://cdn/p.jpg',
    String? mutedUntil,
  }) => ProfileResp(
    chatLid: 'lid-1',
    kind: kind,
    phone: phone,
    displayName: 'Alice',
    photoUrl: photoUrl,
    isArchived: false,
    isPinned: false,
    isMarkedUnread: false,
    mutedUntil: mutedUntil,
  );

  group('ProfileMapper.respToEntity', () {
    test('DM → isGroup false, campos mapeados', () {
      final p = ProfileMapper.respToEntity(resp());
      expect(p.isGroup, isFalse);
      expect(p.chatLid, 'lid-1');
      expect(p.phone, '521555');
      expect(p.displayName, 'Alice');
      expect(p.photoUrl, 'https://cdn/p.jpg');
    });

    test('GROUP → isGroup true', () {
      expect(ProfileMapper.respToEntity(resp(kind: 'GROUP')).isGroup, isTrue);
    });

    test('kind desconocido → FormatException (fail-loud)', () {
      expect(
        () => ProfileMapper.respToEntity(resp(kind: 'CHANNEL')),
        throwsA(isA<FormatException>()),
      );
    });

    test('muted_until → DateTime; null queda null', () {
      expect(ProfileMapper.respToEntity(resp()).mutedUntil, isNull);
      expect(
        ProfileMapper.respToEntity(
          resp(mutedUntil: '2026-06-01T12:00:00Z'),
        ).mutedUntil,
        DateTime.utc(2026, 6, 1, 12),
      );
    });

    test('muted_until malformado → FormatException', () {
      expect(
        () => ProfileMapper.respToEntity(resp(mutedUntil: 'no-fecha')),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
