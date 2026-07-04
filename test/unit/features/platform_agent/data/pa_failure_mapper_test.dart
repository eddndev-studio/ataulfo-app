import 'package:ataulfo/features/platform_agent/data/datasources/pa_failure_mapper.dart';
import 'package:ataulfo/features/platform_agent/domain/failures/pa_failure.dart';
import 'package:ataulfo/features/platform_agent/presentation/widgets/pa_failure_copy.dart';
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
  group('mapPlatformAgentDioException — adjuntos', () {
    test('413 ⇒ PaAttachmentTooLargeFailure', () {
      expect(
        mapPlatformAgentDioException(_badResponse(413)),
        isA<PaAttachmentTooLargeFailure>(),
      );
    });

    test('415 ⇒ PaAttachmentUnsupportedFailure', () {
      expect(
        mapPlatformAgentDioException(_badResponse(415)),
        isA<PaAttachmentUnsupportedFailure>(),
      );
    });
  });

  group('platformAgentFailureCopy — adjuntos', () {
    test('peso: menciona el límite de 25 MB', () {
      final copy = platformAgentFailureCopy(
        const PaAttachmentTooLargeFailure(),
      );
      expect(copy.toLowerCase(), contains('25'));
    });

    test('tipo no soportado: menciona los formatos aceptados', () {
      final copy = platformAgentFailureCopy(
        const PaAttachmentUnsupportedFailure(),
      );
      expect(copy.toLowerCase(), contains('pdf'));
    });

    test('tope de adjuntos: menciona el máximo de 5', () {
      final copy = platformAgentFailureCopy(const PaAttachmentLimitFailure());
      expect(copy, contains('5'));
    });
  });
}
