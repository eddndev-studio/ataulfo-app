import 'package:ataulfo/features/stickers/domain/entities/sticker_job.dart';
import 'package:ataulfo/features/stickers/domain/failures/sticker_failure.dart';
import 'package:ataulfo/features/stickers/domain/repositories/sticker_repository.dart';
import 'package:ataulfo/features/stickers/presentation/bloc/sticker_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements StickerRepository {
  List<StickerJob> listResult = const [];
  StickerFailure? listFailure;
  StickerFailure? generateFailure;
  String? lastMotif;
  int listCalls = 0;

  @override
  Future<List<StickerJob>> list() async {
    listCalls++;
    if (listFailure != null) throw listFailure!;
    return listResult;
  }

  @override
  Future<String> generate(String motif) async {
    lastMotif = motif;
    if (generateFailure != null) throw generateFailure!;
    return 'job-new';
  }
}

StickerJob _job(String id, StickerStatus status, {String ref = ''}) =>
    StickerJob(
      id: id,
      motif: 'gracias',
      status: status,
      resultMediaRef: ref,
      errorNote: '',
      createdAt: DateTime.utc(2026, 7, 8),
    );

void main() {
  // Poll largo: los tests no dependen del timer (cierran el cubit al terminar).
  StickerCubit build(_FakeRepo repo) =>
      StickerCubit(repo, pollInterval: const Duration(hours: 1));

  group('load', () {
    test('éxito ⇒ loaded; ready filtra los DONE con ref', () async {
      final repo = _FakeRepo()
        ..listResult = [
          _job('s1', StickerStatus.done, ref: 'tenant/o/media/s1.webp'),
          _job('s2', StickerStatus.queued),
          _job('s3', StickerStatus.done), // DONE sin ref: no usable
        ];
      final cubit = build(repo);
      await cubit.load();
      expect(cubit.state.status, StickerListStatus.loaded);
      expect(cubit.state.jobs, hasLength(3));
      expect(cubit.state.ready.map((j) => j.id), ['s1']);
      expect(cubit.state.hasActiveJobs, isTrue);
      await cubit.close();
    });

    test('falla inicial ⇒ error con failure', () async {
      final repo = _FakeRepo()..listFailure = const StickerNetworkFailure();
      final cubit = build(repo);
      await cubit.load();
      expect(cubit.state.status, StickerListStatus.error);
      expect(cubit.state.failure, const StickerNetworkFailure());
      await cubit.close();
    });
  });

  group('generate', () {
    test('éxito ⇒ envía el motivo y recarga', () async {
      final repo = _FakeRepo()..listResult = const [];
      final cubit = build(repo);
      await cubit.load(); // listCalls = 1
      final failure = await cubit.generate('oferta');
      expect(failure, isNull);
      expect(repo.lastMotif, 'oferta');
      expect(repo.listCalls, 2); // recargó tras generar
      expect(cubit.state.generating, isFalse);
      await cubit.close();
    });

    test(
      'falla ⇒ devuelve la falla, generating apagado, sin recargar',
      () async {
        final repo = _FakeRepo()
          ..listResult = const []
          ..generateFailure = const StickerRejectedFailure('cuota');
        final cubit = build(repo);
        await cubit.load(); // listCalls = 1
        final failure = await cubit.generate('oferta');
        expect(failure, const StickerRejectedFailure('cuota'));
        expect(cubit.state.generating, isFalse);
        expect(repo.listCalls, 1); // no recargó en fallo
        await cubit.close();
      },
    );
  });
}
