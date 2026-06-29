import 'package:ataulfo/features/org_ai_config/data/datasources/org_ai_config_datasource.dart';
import 'package:ataulfo/features/org_ai_config/domain/entities/org_ai_config.dart';
import 'package:ataulfo/features/org_ai_config/domain/failures/org_ai_config_failure.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _resp(int status, Map<String, dynamic> body) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: '/org/ai-config'),
      statusCode: status,
      data: body,
    );

DioException _bad(int status) => DioException(
  requestOptions: RequestOptions(path: '/org/ai-config'),
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    requestOptions: RequestOptions(path: '/org/ai-config'),
    statusCode: status,
  ),
);

Map<String, dynamic> _body({Map<String, dynamic>? hosts}) => <String, dynamic>{
  'hosts': hosts ?? <String, dynamic>{'MiniMax-M3': 'FIREWORKS'},
  'defaults': <String, dynamic>{
    'enabled': false,
    'provider': 'GEMINI',
    'model': 'gemini-3.1-pro-preview',
    'temperature': 0.7,
    'thinking_level': 'LOW',
    'system_prompt': '',
    'context_messages': 20,
  },
};

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(<String, dynamic>{});
  });

  late _MockDio dio;
  late DioOrgAiConfigDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioOrgAiConfigDatasource(dio);
  });

  group('get', () {
    test('200 → entidad con hosts + defaults', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/org/ai-config'),
      ).thenAnswer((_) async => _resp(200, _body()));

      final cfg = await ds.get();
      expect(cfg.hostFor('MiniMax-M3'), 'FIREWORKS');
      expect(cfg.defaults.provider, AIProvider.gemini);
    });

    test('403 → OrgAiConfigForbiddenFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/org/ai-config'),
      ).thenThrow(_bad(403));
      await expectLater(
        ds.get(),
        throwsA(isA<OrgAiConfigForbiddenFailure>()),
      );
    });
  });

  group('update', () {
    test('200 → serializa hosts + defaults snake_case y devuelve la guardada',
        () async {
      Map<String, dynamic>? captured;
      when(
        () => dio.put<Map<String, dynamic>>(
          '/org/ai-config',
          data: any(named: 'data'),
        ),
      ).thenAnswer((invocation) async {
        captured = invocation.namedArguments[#data] as Map<String, dynamic>;
        return _resp(200, _body());
      });

      const input = OrgAiConfig(
        hosts: <String, String>{'deepseek-v4-pro': 'DEEPSEEK'},
        defaults: AIConfig(
          enabled: true,
          provider: AIProvider.minimax,
          model: 'MiniMax-M3',
          temperature: 0.9,
          thinkingLevel: ThinkingLevel.high,
          systemPrompt: 'X',
          contextMessages: 15,
        ),
      );
      await ds.update(input);

      expect(captured, isNotNull);
      expect(captured!['hosts'], <String, String>{'deepseek-v4-pro': 'DEEPSEEK'});
      final defaults = captured!['defaults'] as Map<String, dynamic>;
      expect(defaults['provider'], 'MINIMAX');
      expect(defaults['model'], 'MiniMax-M3');
      expect(defaults['thinking_level'], 'HIGH');
      expect(defaults['context_messages'], 15);
    });

    test('422 → OrgAiConfigInvalidFailure (host rechazado / defaults inválidos)',
        () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          '/org/ai-config',
          data: any(named: 'data'),
        ),
      ).thenThrow(_bad(422));
      await expectLater(
        ds.update(
          const OrgAiConfig(
            hosts: <String, String>{},
            defaults: AIConfig(
              enabled: false,
              provider: AIProvider.gemini,
              model: 'gemini-3.1-pro-preview',
              temperature: 0.7,
              thinkingLevel: ThinkingLevel.low,
              systemPrompt: '',
              contextMessages: 20,
            ),
          ),
        ),
        throwsA(isA<OrgAiConfigInvalidFailure>()),
      );
    });
  });
}
