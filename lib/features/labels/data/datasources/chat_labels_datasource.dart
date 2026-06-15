import 'package:dio/dio.dart';

import '../../domain/entities/label.dart';
import '../../domain/failures/labels_failure.dart';
import '../dto/label_dto.dart';
import '../mappers/labels_mapper.dart';
import 'labels_dio_errors.dart';

/// Puerto de datos de SOLO LECTURA de los Labels internos puestos a UN chat
/// (S10). Distinto del catálogo (`LabelsDatasource`, `/labels`): aquí el scope
/// es el chat (`/sessions/{botId}/{chatLid}/labels`). El AuthInterceptor inyecta
/// el Bearer. Lanza `LabelsFailure` tipadas.
abstract interface class ChatLabelsDatasource {
  /// `GET /sessions/{botId}/{chatLid}/labels`. Labels internos aplicados a este
  /// chat. Vacía es válida. 404 si el bot no es de la org.
  Future<List<Label>> listForChat(String botId, String chatLid);
}

class DioChatLabelsDatasource implements ChatLabelsDatasource {
  DioChatLabelsDatasource(this._dio);

  final Dio _dio;

  @override
  Future<List<Label>> listForChat(String botId, String chatLid) async {
    try {
      // El chatLid se percent-encodea: los grupos llevan `@` (`...@g.us`),
      // inválido crudo en un segmento de path. Mismo criterio que el resto de
      // rutas por chat.
      final res = await _dio.get<Map<String, dynamic>>(
        '/sessions/$botId/${Uri.encodeComponent(chatLid)}/labels',
      );
      final body = res.data;
      if (body == null) {
        throw const LabelsUnknownFailure();
      }
      return LabelsMapper.listToLabels(LabelListResp.fromJson(body));
    } on LabelsFailure {
      rethrow;
    } on DioException catch (e) {
      throw mapLabelsDioException(e);
    } on FormatException {
      throw const LabelsUnknownFailure();
    } on TypeError {
      throw const LabelsUnknownFailure();
    }
  }
}
