import 'package:ataulfo/features/trainer/data/datasources/failure_mapper.dart';
import 'package:ataulfo/features/trainer/domain/failures/trainer_failure.dart';
import 'package:ataulfo/features/trainer/presentation/pages/trainer_chat_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _badResponse(int status) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  response: Response<dynamic>(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: status,
  ),
  type: DioExceptionType.badResponse,
);

void main() {
  group('mapTrainerDioException — adjuntos', () {
    test('413 ⇒ TrainerAttachmentTooLargeFailure', () {
      expect(
        mapTrainerDioException(_badResponse(413)),
        isA<TrainerAttachmentTooLargeFailure>(),
      );
    });

    test('415 ⇒ TrainerAttachmentUnsupportedFailure', () {
      expect(
        mapTrainerDioException(_badResponse(415)),
        isA<TrainerAttachmentUnsupportedFailure>(),
      );
    });
  });

  group('trainerFailureCopy — adjuntos', () {
    test('peso: menciona el límite de 25 MB', () {
      final copy = trainerFailureCopy(const TrainerAttachmentTooLargeFailure());
      expect(copy.toLowerCase(), contains('25'));
    });

    test('tipo no soportado: menciona los formatos aceptados', () {
      final copy = trainerFailureCopy(
        const TrainerAttachmentUnsupportedFailure(),
      );
      expect(copy.toLowerCase(), contains('pdf'));
    });

    test('tope de adjuntos: menciona el máximo de 5', () {
      final copy = trainerFailureCopy(const TrainerAttachmentLimitFailure());
      expect(copy, contains('5'));
    });
  });
}
