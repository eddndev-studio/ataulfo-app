import 'package:ataulfo/features/product_catalog/data/dto/composition_job_dto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json() => <String, dynamic>{
  'id': 'j1',
  'preset': 'estudio-blanco',
  'model': 'gemini-3-pro-image',
  'status': 'DONE',
  'resultMediaRef': 'tenant/org/media/compuesta.png',
  'errorNote': '',
  'createdAt': '2026-07-08T10:00:00Z',
};

void main() {
  test('json completo ⇒ DTO con los valores del wire', () {
    final dto = CompositionJobDto.fromJson(_json());
    expect(dto.id, 'j1');
    expect(dto.preset, 'estudio-blanco');
    expect(dto.model, 'gemini-3-pro-image');
    expect(dto.status, 'DONE');
    expect(dto.resultMediaRef, 'tenant/org/media/compuesta.png');
    expect(dto.errorNote, '');
    expect(dto.createdAt, '2026-07-08T10:00:00Z');
  });

  test('strings vacíos del wire se conservan (modelo estándar, job sin '
      'resultado ni error)', () {
    final json = _json()
      ..['model'] = ''
      ..['status'] = 'QUEUED'
      ..['resultMediaRef'] = ''
      ..['errorNote'] = '';
    final dto = CompositionJobDto.fromJson(json);
    expect(dto.model, '');
    expect(dto.resultMediaRef, '');
    expect(dto.errorNote, '');
  });

  test('clave ausente ⇒ FormatException (wire roto, no caso a tolerar)', () {
    for (final key in _json().keys) {
      final json = _json()..remove(key);
      expect(
        () => CompositionJobDto.fromJson(json),
        throwsFormatException,
        reason: 'sin $key',
      );
    }
  });

  test('tipo inválido ⇒ FormatException', () {
    expect(
      () => CompositionJobDto.fromJson(_json()..['status'] = 3),
      throwsFormatException,
    );
    expect(
      () => CompositionJobDto.fromJson(_json()..['createdAt'] = 123),
      throwsFormatException,
    );
  });
}
