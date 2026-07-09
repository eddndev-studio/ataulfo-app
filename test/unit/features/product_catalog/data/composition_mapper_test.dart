import 'package:ataulfo/features/product_catalog/data/dto/composition_job_dto.dart';
import 'package:ataulfo/features/product_catalog/data/mappers/composition_mapper.dart';
import 'package:ataulfo/features/product_catalog/domain/entities/composition_job.dart';
import 'package:flutter_test/flutter_test.dart';

CompositionJobDto _dto({String status = 'DONE'}) => CompositionJobDto(
  id: 'j1',
  preset: 'marmol',
  model: '',
  status: status,
  resultMediaRef: 'tenant/org/media/out.png',
  errorNote: '',
  createdAt: '2026-07-08T10:00:00Z',
);

void main() {
  test('dtoToEntity mapea campos y parsea createdAt a UTC', () {
    final job = CompositionMapper.dtoToEntity(_dto());
    expect(job.id, 'j1');
    expect(job.preset, 'marmol');
    expect(job.model, '');
    expect(job.status, CompositionStatus.done);
    expect(job.resultMediaRef, 'tenant/org/media/out.png');
    expect(job.errorNote, '');
    expect(job.createdAt, DateTime.utc(2026, 7, 8, 10));
    expect(job.createdAt.isUtc, isTrue);
  });

  test('status del set cerrado del wire', () {
    expect(
      CompositionMapper.statusFromWire('QUEUED'),
      CompositionStatus.queued,
    );
    expect(
      CompositionMapper.statusFromWire('RUNNING'),
      CompositionStatus.running,
    );
    expect(CompositionMapper.statusFromWire('DONE'), CompositionStatus.done);
    expect(
      CompositionMapper.statusFromWire('FAILED'),
      CompositionStatus.failed,
    );
  });

  test('status fuera del set ⇒ FormatException (wire roto)', () {
    expect(
      () => CompositionMapper.statusFromWire('EXPLODED'),
      throwsFormatException,
    );
  });

  test('fecha malformada ⇒ FormatException', () {
    const dto = CompositionJobDto(
      id: 'j1',
      preset: 'marmol',
      model: '',
      status: 'DONE',
      resultMediaRef: '',
      errorNote: '',
      createdAt: 'ayer',
    );
    expect(() => CompositionMapper.dtoToEntity(dto), throwsFormatException);
  });

  test('isActive solo en QUEUED/RUNNING', () {
    expect(
      CompositionMapper.dtoToEntity(_dto(status: 'QUEUED')).isActive,
      isTrue,
    );
    expect(
      CompositionMapper.dtoToEntity(_dto(status: 'RUNNING')).isActive,
      isTrue,
    );
    expect(
      CompositionMapper.dtoToEntity(_dto(status: 'DONE')).isActive,
      isFalse,
    );
    expect(
      CompositionMapper.dtoToEntity(_dto(status: 'FAILED')).isActive,
      isFalse,
    );
  });
}
