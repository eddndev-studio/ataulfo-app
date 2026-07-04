import 'package:ataulfo/features/ai_log/domain/entities/ai_log_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiLogRole.fromWire', () {
    test('reconoce el set del backend, incluido system (aviso del motor)', () {
      expect(AiLogRole.fromWire('user'), AiLogRole.user);
      expect(AiLogRole.fromWire('assistant'), AiLogRole.assistant);
      expect(AiLogRole.fromWire('tool'), AiLogRole.tool);
      expect(AiLogRole.fromWire('system'), AiLogRole.system);
    });

    test('token desconocido degrada a unknown sin romper la carga', () {
      expect(AiLogRole.fromWire('developer'), AiLogRole.unknown);
      expect(AiLogRole.fromWire(''), AiLogRole.unknown);
    });
  });
}
