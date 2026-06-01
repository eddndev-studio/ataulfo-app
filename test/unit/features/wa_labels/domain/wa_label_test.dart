import 'package:ataulfo/features/wa_labels/domain/entities/wa_chat_assoc.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label_mapping.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_msg_assoc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WaLabel value-equality', () {
    WaLabel make({
      String waLabelId = '1000',
      String name = 'VIP',
      int color = 3,
      bool deleted = false,
    }) => WaLabel(
      waLabelId: waLabelId,
      name: name,
      color: color,
      deleted: deleted,
    );

    test('iguales con los mismos campos', () {
      expect(make(), make());
      expect(make().hashCode, make().hashCode);
    });

    test('color 0 es un índice de paleta válido (no se confunde con null)', () {
      expect(make(color: 0).color, 0);
      expect(make(color: 0), isNot(make(color: 1)));
    });

    test('deleted distingue tombstone de activa', () {
      expect(make(deleted: true), isNot(make()));
      expect(make(deleted: true).deleted, isTrue);
    });

    test('copyWith reemplaza solo lo indicado', () {
      final base = make();
      expect(base.copyWith(name: 'Oro'), make(name: 'Oro'));
      expect(base.copyWith(deleted: true), make(deleted: true));
      expect(base.copyWith(color: 0).color, 0);
    });
  });

  group('WaChatAssoc / WaMsgAssoc / WaLabelMapping value-equality', () {
    test('WaChatAssoc iguala por campos; labeled:false != true', () {
      const a = WaChatAssoc(chatLid: 'c1', waLabelId: '1000', labeled: true);
      const b = WaChatAssoc(chatLid: 'c1', waLabelId: '1000', labeled: true);
      const c = WaChatAssoc(chatLid: 'c1', waLabelId: '1000', labeled: false);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('WaMsgAssoc iguala por campos incluyendo messageId', () {
      const a = WaMsgAssoc(
        chatLid: 'c1',
        messageId: 'wamid.1',
        waLabelId: '1000',
        labeled: true,
      );
      const b = WaMsgAssoc(
        chatLid: 'c1',
        messageId: 'wamid.1',
        waLabelId: '1000',
        labeled: true,
      );
      const d = WaMsgAssoc(
        chatLid: 'c1',
        messageId: 'wamid.2',
        waLabelId: '1000',
        labeled: true,
      );
      expect(a, b);
      expect(a, isNot(d));
    });

    test('WaLabelMapping iguala por (waLabelId, labelId)', () {
      const a = WaLabelMapping(waLabelId: '1000', labelId: 'uuid-vip');
      const b = WaLabelMapping(waLabelId: '1000', labelId: 'uuid-vip');
      const e = WaLabelMapping(waLabelId: '1000', labelId: 'uuid-otro');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(e));
    });
  });
}
