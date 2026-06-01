import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/failures/labels_failure.dart';
import 'package:ataulfo/features/labels/domain/repositories/labels_repository.dart';
import 'package:ataulfo/features/labels/presentation/bloc/labels_admin_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements LabelsRepository {}

Label _lbl(String id, String name, {String color = '#7c3aed'}) =>
    Label(id: id, name: name, color: color, description: '');

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  LabelsAdminBloc build() => LabelsAdminBloc(repo: repo);

  test('estado inicial es LabelsAdminLoading', () {
    expect(build().state, const LabelsAdminLoading());
  });

  group('carga', () {
    blocTest<LabelsAdminBloc, LabelsAdminState>(
      'LoadRequested → Loaded con el catálogo',
      setUp: () =>
          when(repo.listLabels).thenAnswer((_) async => [_lbl('1', 'VIP')]),
      build: build,
      act: (b) => b.add(const LabelsAdminLoadRequested()),
      expect: () => [
        LabelsAdminLoaded(labels: [_lbl('1', 'VIP')], isRefreshing: false),
      ],
    );

    blocTest<LabelsAdminBloc, LabelsAdminState>(
      'LoadRequested con fallo → Failed',
      setUp: () =>
          when(repo.listLabels).thenThrow(const LabelsNetworkFailure()),
      build: build,
      act: (b) => b.add(const LabelsAdminLoadRequested()),
      expect: () => [const LabelsAdminFailed(LabelsNetworkFailure())],
    );

    blocTest<LabelsAdminBloc, LabelsAdminState>(
      'RefreshRequested desde Loaded: refrescando→Loaded nuevo',
      setUp: () =>
          when(repo.listLabels).thenAnswer((_) async => [_lbl('1', 'B')]),
      build: build,
      seed: () =>
          LabelsAdminLoaded(labels: [_lbl('1', 'A')], isRefreshing: false),
      act: (b) => b.add(const LabelsAdminRefreshRequested()),
      expect: () => [
        LabelsAdminLoaded(labels: [_lbl('1', 'A')], isRefreshing: true),
        LabelsAdminLoaded(labels: [_lbl('1', 'B')], isRefreshing: false),
      ],
    );
  });

  group('crear', () {
    blocTest<LabelsAdminBloc, LabelsAdminState>(
      'CreateRequested ok → Mutating, Loaded con la nueva añadida',
      setUp: () => when(
        () => repo.createLabel(
          name: any(named: 'name'),
          color: any(named: 'color'),
          description: any(named: 'description'),
        ),
      ).thenAnswer((_) async => _lbl('2', 'Nuevo')),
      build: build,
      seed: () =>
          LabelsAdminLoaded(labels: [_lbl('1', 'VIP')], isRefreshing: false),
      act: (b) => b.add(
        const LabelsAdminCreateRequested(
          name: 'Nuevo',
          color: '#7c3aed',
          description: '',
        ),
      ),
      expect: () => [
        LabelsAdminMutating([_lbl('1', 'VIP')]),
        LabelsAdminLoaded(
          labels: [_lbl('1', 'VIP'), _lbl('2', 'Nuevo')],
          isRefreshing: false,
        ),
      ],
    );

    blocTest<LabelsAdminBloc, LabelsAdminState>(
      'CreateRequested con nombre duplicado → MutationFailed conserva snapshot',
      setUp: () => when(
        () => repo.createLabel(
          name: any(named: 'name'),
          color: any(named: 'color'),
          description: any(named: 'description'),
        ),
      ).thenThrow(const LabelsDuplicateNameFailure()),
      build: build,
      seed: () =>
          LabelsAdminLoaded(labels: [_lbl('1', 'VIP')], isRefreshing: false),
      act: (b) => b.add(
        const LabelsAdminCreateRequested(
          name: 'VIP',
          color: '#7c3aed',
          description: '',
        ),
      ),
      expect: () => [
        LabelsAdminMutating([_lbl('1', 'VIP')]),
        LabelsAdminMutationFailed([
          _lbl('1', 'VIP'),
        ], const LabelsDuplicateNameFailure()),
      ],
    );

    blocTest<LabelsAdminBloc, LabelsAdminState>(
      'nueva mutación desde MutationFailed reusa el snapshot',
      setUp: () => when(
        () => repo.createLabel(
          name: any(named: 'name'),
          color: any(named: 'color'),
          description: any(named: 'description'),
        ),
      ).thenAnswer((_) async => _lbl('2', 'Nuevo')),
      build: build,
      seed: () => LabelsAdminMutationFailed([
        _lbl('1', 'VIP'),
      ], const LabelsDuplicateNameFailure()),
      act: (b) => b.add(
        const LabelsAdminCreateRequested(
          name: 'Nuevo',
          color: '#7c3aed',
          description: '',
        ),
      ),
      expect: () => [
        LabelsAdminMutating([_lbl('1', 'VIP')]),
        LabelsAdminLoaded(
          labels: [_lbl('1', 'VIP'), _lbl('2', 'Nuevo')],
          isRefreshing: false,
        ),
      ],
    );
  });

  group('editar', () {
    blocTest<LabelsAdminBloc, LabelsAdminState>(
      'UpdateRequested ok → reemplaza por id',
      setUp: () => when(
        () => repo.updateLabel(
          id: any(named: 'id'),
          name: any(named: 'name'),
          color: any(named: 'color'),
          description: any(named: 'description'),
        ),
      ).thenAnswer((_) async => _lbl('1', 'VIP+', color: '#ff0000')),
      build: build,
      seed: () =>
          LabelsAdminLoaded(labels: [_lbl('1', 'VIP')], isRefreshing: false),
      act: (b) => b.add(
        const LabelsAdminUpdateRequested(
          id: '1',
          name: 'VIP+',
          color: '#ff0000',
          description: '',
        ),
      ),
      expect: () => [
        LabelsAdminMutating([_lbl('1', 'VIP')]),
        LabelsAdminLoaded(
          labels: [_lbl('1', 'VIP+', color: '#ff0000')],
          isRefreshing: false,
        ),
      ],
    );
  });

  group('borrar', () {
    blocTest<LabelsAdminBloc, LabelsAdminState>(
      'DeleteRequested ok → quita por id',
      setUp: () => when(
        () => repo.deleteLabel(id: any(named: 'id')),
      ).thenAnswer((_) async {}),
      build: build,
      seed: () => LabelsAdminLoaded(
        labels: [_lbl('1', 'A'), _lbl('2', 'B')],
        isRefreshing: false,
      ),
      act: (b) => b.add(const LabelsAdminDeleteRequested(id: '1')),
      expect: () => [
        LabelsAdminMutating([_lbl('1', 'A'), _lbl('2', 'B')]),
        LabelsAdminLoaded(labels: [_lbl('2', 'B')], isRefreshing: false),
      ],
    );

    blocTest<LabelsAdminBloc, LabelsAdminState>(
      'DeleteRequested con fallo → MutationFailed conserva la lista',
      setUp: () => when(
        () => repo.deleteLabel(id: any(named: 'id')),
      ).thenThrow(const LabelsServerFailure()),
      build: build,
      seed: () =>
          LabelsAdminLoaded(labels: [_lbl('1', 'A')], isRefreshing: false),
      act: (b) => b.add(const LabelsAdminDeleteRequested(id: '1')),
      expect: () => [
        LabelsAdminMutating([_lbl('1', 'A')]),
        LabelsAdminMutationFailed([
          _lbl('1', 'A'),
        ], const LabelsServerFailure()),
      ],
    );
  });
}
