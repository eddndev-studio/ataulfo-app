import 'package:ataulfo/features/messages/domain/attachment_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('messageTypeForFilename', () {
    test('imágenes por extensión ⇒ image', () {
      for (final name in <String>[
        'foto.jpg',
        'FOTO.JPG',
        'a.jpeg',
        'b.png',
        'c.gif',
        'd.webp',
        'e.heic',
      ]) {
        expect(messageTypeForFilename(name), 'image', reason: name);
      }
    });

    test('videos por extensión ⇒ video', () {
      for (final name in <String>[
        'clip.mp4',
        'clip.MOV',
        'x.mkv',
        'y.webm',
        'z.3gp',
      ]) {
        expect(messageTypeForFilename(name), 'video', reason: name);
      }
    });

    test('audios por extensión ⇒ audio', () {
      for (final name in <String>[
        'nota.mp3',
        'a.ogg',
        'b.opus',
        'c.m4a',
        'd.wav',
        'e.aac',
      ]) {
        expect(messageTypeForFilename(name), 'audio', reason: name);
      }
    });

    test('cualquier otra extensión ⇒ document', () {
      for (final name in <String>[
        'contrato.pdf',
        'hoja.xlsx',
        'texto.txt',
        'datos.csv',
        'archivo.zip',
      ]) {
        expect(messageTypeForFilename(name), 'document', reason: name);
      }
    });

    test('sin extensión ⇒ document', () {
      expect(messageTypeForFilename('LEEME'), 'document');
      expect(messageTypeForFilename(''), 'document');
    });

    test('un punto final sin extensión ⇒ document', () {
      expect(messageTypeForFilename('archivo.'), 'document');
    });

    test('rutas con puntos: sólo cuenta la última extensión', () {
      expect(messageTypeForFilename('backup.tar.gz'), 'document');
      expect(messageTypeForFilename('mi.foto.final.png'), 'image');
    });
  });
}
