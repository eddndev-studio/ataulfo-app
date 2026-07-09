import 'package:ataulfo/features/product_catalog/domain/entities/composition_job.dart';
import 'package:ataulfo/features/product_catalog/domain/failures/composition_failure.dart';
import 'package:ataulfo/features/product_catalog/domain/repositories/composition_repository.dart';
import 'package:ataulfo/features/product_catalog/presentation/bloc/composition_cubit.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

CompositionJob _job(String id, CompositionStatus status) => CompositionJob(
  id: id,
  preset: 'estudio-blanco',
  model: '',
  status: status,
  resultMediaRef: status == CompositionStatus.done ? 'ref/out.png' : '',
  errorNote: '',
  createdAt: DateTime.utc(2026, 7, 8, 10),
);

/// Repo guionizado: cada listJobs consume el siguiente paso del guion (una
/// lista de jobs o un failure a lanzar); el último paso se repite. Las
/// mutaciones responden con el failure configurado o éxito.
class _FakeRepo implements CompositionRepository {
  _FakeRepo(this.script);

  final List<Object> script;
  int listCalls = 0;

  String? composedPreset;
  bool? composedPremium;
  CompositionFailure? composeFailure;

  final List<String> accepted = <String>[];
  CompositionFailure? acceptFailure;

  final List<String> discarded = <String>[];
  CompositionFailure? discardFailure;

  @override
  Future<List<CompositionJob>> listJobs(String productId) async {
    final step = script[listCalls.clamp(0, script.length - 1)];
    listCalls++;
    if (step is CompositionFailure) throw step;
    return (step as List<CompositionJob>);
  }

  @override
  Future<String> compose({
    required String productId,
    required String preset,
    bool premium = false,
  }) async {
    final f = composeFailure;
    if (f != null) throw f;
    composedPreset = preset;
    composedPremium = premium;
    return 'j-nuevo';
  }

  @override
  Future<void> accept(String jobId) async {
    final f = acceptFailure;
    if (f != null) throw f;
    accepted.add(jobId);
  }

  @override
  Future<void> discard(String jobId) async {
    final f = discardFailure;
    if (f != null) throw f;
    discarded.add(jobId);
  }
}

void main() {
  const poll = Duration(seconds: 4);

  CompositionCubit cubit(_FakeRepo repo) =>
      CompositionCubit(repo, productId: 'p1', pollInterval: poll);

  test('load carga los jobs; sin activos NO agenda poll', () {
    fakeAsync((async) {
      final repo = _FakeRepo(<Object>[
        <CompositionJob>[_job('j1', CompositionStatus.done)],
      ]);
      final c = cubit(repo);
      c.load();
      async.flushMicrotasks();
      expect(c.state.status, CompositionListStatus.loaded);
      expect(c.state.jobs.single.id, 'j1');
      async.elapse(poll * 3);
      expect(repo.listCalls, 1, reason: 'sin jobs activos no hay poll');
      c.close();
    });
  });

  test('poll cada intervalo mientras haya QUEUED/RUNNING y para al '
      'asentarse', () {
    fakeAsync((async) {
      final repo = _FakeRepo(<Object>[
        <CompositionJob>[_job('j1', CompositionStatus.queued)],
        <CompositionJob>[_job('j1', CompositionStatus.running)],
        <CompositionJob>[_job('j1', CompositionStatus.done)],
      ]);
      final c = cubit(repo);
      c.load();
      async.flushMicrotasks();
      expect(repo.listCalls, 1);
      async.elapse(poll);
      expect(repo.listCalls, 2);
      expect(c.state.jobs.single.status, CompositionStatus.running);
      async.elapse(poll);
      expect(repo.listCalls, 3);
      expect(c.state.jobs.single.status, CompositionStatus.done);
      async.elapse(poll * 4);
      expect(repo.listCalls, 3, reason: 'terminado el job, el poll se apaga');
      c.close();
    });
  });

  test('close cancela el timer pendiente (sin fugas)', () {
    fakeAsync((async) {
      final repo = _FakeRepo(<Object>[
        <CompositionJob>[_job('j1', CompositionStatus.queued)],
      ]);
      final c = cubit(repo);
      c.load();
      async.flushMicrotasks();
      c.close();
      async.elapse(poll * 3);
      expect(repo.listCalls, 1, reason: 'cerrado el cubit no quedan timers');
    });
  });

  test('un error del poll con jobs activos conserva la lista y reintenta', () {
    fakeAsync((async) {
      final repo = _FakeRepo(<Object>[
        <CompositionJob>[_job('j1', CompositionStatus.queued)],
        const CompositionNetworkFailure(),
        <CompositionJob>[_job('j1', CompositionStatus.done)],
      ]);
      final c = cubit(repo);
      c.load();
      async.flushMicrotasks();
      async.elapse(poll);
      expect(repo.listCalls, 2);
      expect(c.state.status, CompositionListStatus.loaded);
      expect(c.state.jobs, isNotEmpty, reason: 'el error transitorio no borra');
      async.elapse(poll);
      expect(repo.listCalls, 3);
      expect(c.state.jobs.single.status, CompositionStatus.done);
      c.close();
    });
  });

  test('error en la carga inicial ⇒ estado error (con retry manual)', () {
    fakeAsync((async) {
      final repo = _FakeRepo(<Object>[
        const CompositionServerFailure(),
        <CompositionJob>[],
      ]);
      final c = cubit(repo);
      c.load();
      async.flushMicrotasks();
      expect(c.state.status, CompositionListStatus.error);
      expect(c.state.failure, const CompositionServerFailure());
      async.elapse(poll * 2);
      expect(repo.listCalls, 1, reason: 'el error inicial no agenda poll');
      c.load();
      async.flushMicrotasks();
      expect(c.state.status, CompositionListStatus.loaded);
      c.close();
    });
  });

  test('compose OK ⇒ manda preset/premium, recarga y devuelve null', () {
    fakeAsync((async) {
      final repo = _FakeRepo(<Object>[
        <CompositionJob>[],
        <CompositionJob>[_job('j-nuevo', CompositionStatus.queued)],
      ]);
      final c = cubit(repo);
      c.load();
      async.flushMicrotasks();
      CompositionFailure? result = const UnknownCompositionFailure();
      c.compose(preset: 'marmol', premium: true).then((f) => result = f);
      async.flushMicrotasks();
      expect(result, isNull);
      expect(repo.composedPreset, 'marmol');
      expect(repo.composedPremium, isTrue);
      expect(repo.listCalls, 2, reason: 'el compose recarga la lista');
      expect(c.state.jobs.single.status, CompositionStatus.queued);
      async.elapse(poll);
      expect(repo.listCalls, 3, reason: 'el job nuevo activa el poll');
      c.close();
    });
  });

  test('compose rechazado ⇒ devuelve el failure y no recarga', () {
    fakeAsync((async) {
      final repo = _FakeRepo(<Object>[<CompositionJob>[]])
        ..composeFailure = const CompositionRejectedFailure('cuota');
      final c = cubit(repo);
      c.load();
      async.flushMicrotasks();
      CompositionFailure? result;
      c.compose(preset: 'marmol').then((f) => result = f);
      async.flushMicrotasks();
      expect(result, const CompositionRejectedFailure('cuota'));
      expect(repo.listCalls, 1);
      expect(c.state.mutating, isFalse);
      c.close();
    });
  });

  test('accept OK recarga y devuelve null; el conflicto se devuelve', () {
    fakeAsync((async) {
      final repo = _FakeRepo(<Object>[
        <CompositionJob>[_job('j1', CompositionStatus.done)],
      ]);
      final c = cubit(repo);
      c.load();
      async.flushMicrotasks();
      CompositionFailure? result = const UnknownCompositionFailure();
      c.accept('j1').then((f) => result = f);
      async.flushMicrotasks();
      expect(result, isNull);
      expect(repo.accepted, <String>['j1']);
      expect(repo.listCalls, 2);

      repo.acceptFailure = const CompositionConflictFailure('no está lista');
      CompositionFailure? conflict;
      c.accept('j1').then((f) => conflict = f);
      async.flushMicrotasks();
      expect(conflict, const CompositionConflictFailure('no está lista'));
      c.close();
    });
  });

  test('discard OK recarga; el conflicto se devuelve', () {
    fakeAsync((async) {
      final repo = _FakeRepo(<Object>[
        <CompositionJob>[_job('j1', CompositionStatus.done)],
        <CompositionJob>[],
      ]);
      final c = cubit(repo);
      c.load();
      async.flushMicrotasks();
      CompositionFailure? result = const UnknownCompositionFailure();
      c.discard('j1').then((f) => result = f);
      async.flushMicrotasks();
      expect(result, isNull);
      expect(repo.discarded, <String>['j1']);
      expect(c.state.jobs, isEmpty);

      repo.discardFailure = const CompositionConflictFailure('en uso');
      CompositionFailure? conflict;
      c.discard('j2').then((f) => conflict = f);
      async.flushMicrotasks();
      expect(conflict, const CompositionConflictFailure('en uso'));
      c.close();
    });
  });
}
