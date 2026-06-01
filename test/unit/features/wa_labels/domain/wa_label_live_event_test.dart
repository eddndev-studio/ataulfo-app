import 'package:ataulfo/features/wa_labels/domain/entities/wa_label_live_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WaLabelLiveEvent value-equality', () {
    test('WaLabelCatalogChanged iguala por campos; removed distingue', () {
      const a = WaLabelCatalogChanged(
        waLabelId: '1000',
        name: 'VIP',
        color: 3,
        removed: false,
      );
      const b = WaLabelCatalogChanged(
        waLabelId: '1000',
        name: 'VIP',
        color: 3,
        removed: false,
      );
      const tomb = WaLabelCatalogChanged(
        waLabelId: '1000',
        name: 'VIP',
        color: 3,
        removed: true,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(tomb));
    });

    test('WaChatLabelChanged iguala por campos; labeled distingue', () {
      const a = WaChatLabelChanged(
        waLabelId: '1000',
        chatLid: 'c1',
        color: 3,
        labeled: true,
      );
      const off = WaChatLabelChanged(
        waLabelId: '1000',
        chatLid: 'c1',
        color: 3,
        labeled: false,
      );
      expect(
        a,
        const WaChatLabelChanged(
          waLabelId: '1000',
          chatLid: 'c1',
          color: 3,
          labeled: true,
        ),
      );
      expect(a, isNot(off));
    });

    test('WaMessageLabelChanged iguala incluyendo messageId', () {
      const a = WaMessageLabelChanged(
        waLabelId: '1000',
        chatLid: 'c1',
        messageId: 'wamid.1',
        color: 3,
        labeled: true,
      );
      const other = WaMessageLabelChanged(
        waLabelId: '1000',
        chatLid: 'c1',
        messageId: 'wamid.2',
        color: 3,
        labeled: true,
      );
      expect(a, isNot(other));
    });

    test('WaLabelReconnected es un marcador singular', () {
      expect(const WaLabelReconnected(), const WaLabelReconnected());
      expect(
        const WaLabelReconnected().hashCode,
        const WaLabelReconnected().hashCode,
      );
    });

    test('variantes distintas no son iguales entre sí', () {
      const cat = WaLabelCatalogChanged(
        waLabelId: '1000',
        name: 'VIP',
        color: 3,
        removed: false,
      );
      const chat = WaChatLabelChanged(
        waLabelId: '1000',
        chatLid: 'c1',
        color: 3,
        labeled: true,
      );
      expect(cat, isNot(chat));
    });
  });
}
