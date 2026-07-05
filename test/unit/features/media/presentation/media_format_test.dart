import 'package:ataulfo/features/media/presentation/media_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatBytes', () {
    test('bytes crudos por debajo de 1 KiB', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1023), '1023 B');
    });

    test('KiB con un decimal', () {
      expect(formatBytes(1024), '1.0 KB');
      expect(formatBytes(1536), '1.5 KB');
    });

    test('MiB y GiB con un decimal', () {
      expect(formatBytes(1024 * 1024), '1.0 MB');
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
      expect(formatBytes(1024 * 1024 * 1024), '1.0 GB');
    });

    test('negativo (defensivo) ⇒ 0 B', () {
      expect(formatBytes(-1), '0 B');
    });
  });

  group('formatDuration', () {
    test('menos de un minuto ⇒ m:ss', () {
      expect(formatDuration(5000), '0:05');
      expect(formatDuration(59000), '0:59');
    });

    test('minutos:segundos con padding de segundos', () {
      expect(formatDuration(65000), '1:05');
      expect(formatDuration(600000), '10:00');
    });

    test('una hora o más ⇒ h:mm:ss', () {
      expect(formatDuration(3600000), '1:00:00');
      expect(formatDuration(3661000), '1:01:01');
    });

    test('trunca milisegundos al segundo inferior', () {
      expect(formatDuration(3900), '0:03');
    });

    test('cero o negativo (defensivo) ⇒ 0:00', () {
      expect(formatDuration(0), '0:00');
      expect(formatDuration(-1), '0:00');
    });
  });

  group('formatDate', () {
    test('dd/MM/yyyy HH:mm con padding de dos dígitos', () {
      // Formatea los campos del DateTime dado tal cual (el call-site decide si
      // pasa UTC o local); así el test es determinista sin depender del TZ.
      expect(formatDate(DateTime(2026, 6, 5, 14, 30)), '05/06/2026 14:30');
      expect(formatDate(DateTime(2026, 12, 31, 9, 5)), '31/12/2026 09:05');
      expect(formatDate(DateTime(2026, 1, 1, 0, 0)), '01/01/2026 00:00');
    });
  });

  group('mediaTypeIcon', () {
    test('ícono por familia de contentType', () {
      expect(mediaTypeIcon('image/png'), Icons.image_outlined);
      expect(mediaTypeIcon('video/mp4'), Icons.movie_outlined);
      expect(mediaTypeIcon('audio/ogg'), Icons.audiotrack_outlined);
      expect(mediaTypeIcon('application/pdf'), Icons.picture_as_pdf_outlined);
    });

    test('tipo no catalogado cae al genérico de archivo', () {
      expect(
        mediaTypeIcon('application/zip'),
        Icons.insert_drive_file_outlined,
      );
      expect(mediaTypeIcon(''), Icons.insert_drive_file_outlined);
    });
  });
}
