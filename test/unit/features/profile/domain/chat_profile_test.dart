import 'package:ataulfo/features/profile/domain/entities/chat_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ChatProfile make({
    String chatLid = 'lid-1',
    bool isGroup = false,
    String? phone = '521555',
    String? displayName = 'Alice',
    String? photoUrl,
    bool isArchived = false,
    bool isPinned = false,
    bool isMarkedUnread = false,
    DateTime? mutedUntil,
  }) => ChatProfile(
    chatLid: chatLid,
    isGroup: isGroup,
    phone: phone,
    displayName: displayName,
    photoUrl: photoUrl,
    isArchived: isArchived,
    isPinned: isPinned,
    isMarkedUnread: isMarkedUnread,
    mutedUntil: mutedUntil,
  );

  group('ChatProfile value-equality', () {
    test('iguales con los mismos campos', () {
      expect(make(), make());
      expect(make().hashCode, make().hashCode);
    });

    test('difieren si cambia un campo', () {
      expect(make(), isNot(make(displayName: 'Bob')));
      expect(make(), isNot(make(isGroup: true)));
      expect(make(), isNot(make(photoUrl: 'https://x')));
      expect(make(), isNot(make(isPinned: true)));
    });
  });
}
