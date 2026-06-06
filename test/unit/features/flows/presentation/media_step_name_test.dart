import 'package:ataulfo/features/flows/presentation/media_step_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mediaFilenameFromMetadata', () {
    test('devuelve el media_filename cuando está presente', () {
      expect(
        mediaFilenameFromMetadata('{"media_filename":"Contrato 2026.pdf"}'),
        'Contrato 2026.pdf',
      );
    });

    test('metadata vacío / {} ⇒ null', () {
      expect(mediaFilenameFromMetadata('{}'), isNull);
      expect(mediaFilenameFromMetadata(''), isNull);
      expect(mediaFilenameFromMetadata('   '), isNull);
    });

    test('media_filename vacío o en blanco ⇒ null', () {
      expect(mediaFilenameFromMetadata('{"media_filename":""}'), isNull);
      expect(mediaFilenameFromMetadata('{"media_filename":"   "}'), isNull);
    });

    test('metadata corrupto ⇒ null (no lanza)', () {
      expect(mediaFilenameFromMetadata('{not json'), isNull);
    });

    test('convive con otras claves del metadata', () {
      expect(
        mediaFilenameFromMetadata(
          '{"media_content_type":"image/png","media_filename":"foto.png"}',
        ),
        'foto.png',
      );
    });
  });

  group('shortMediaRef', () {
    test('devuelve el último segmento del path del ref BARE', () {
      expect(shortMediaRef('tenant/org1/media/zzz999.png'), 'zzz999.png');
    });

    test('ref sin slash ⇒ se devuelve completo', () {
      expect(shortMediaRef('zzz999.png'), 'zzz999.png');
    });

    test('ref con slash final ⇒ se devuelve completo', () {
      expect(shortMediaRef('tenant/org1/media/'), 'tenant/org1/media/');
    });

    test('funciona también sobre refs con forma de URL', () {
      expect(shortMediaRef('https://example.com/x.png'), 'x.png');
    });
  });

  group('mediaStepDisplay', () {
    test('con media_filename ⇒ (nombre del archivo, mono=false)', () {
      final (text, mono) = mediaStepDisplay(
        mediaRef: 'tenant/org1/media/abc123.pdf',
        metadataJson: '{"media_filename":"Contrato 2026.pdf"}',
      );
      expect(text, 'Contrato 2026.pdf');
      expect(mono, isFalse);
    });

    test('sin media_filename ⇒ (cola corta del ref, mono=true)', () {
      final (text, mono) = mediaStepDisplay(
        mediaRef: 'tenant/org1/media/zzz999.png',
        metadataJson: '{}',
      );
      expect(text, 'zzz999.png');
      expect(mono, isTrue);
    });

    test('metadata corrupto ⇒ cae a la cola corta del ref (mono)', () {
      final (text, mono) = mediaStepDisplay(
        mediaRef: 'tenant/org1/media/zzz999.png',
        metadataJson: '{broken',
      );
      expect(text, 'zzz999.png');
      expect(mono, isTrue);
    });
  });
}
