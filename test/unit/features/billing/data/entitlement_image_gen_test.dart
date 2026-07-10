import 'package:ataulfo/features/billing/data/dto/entitlement_dto.dart';
import 'package:ataulfo/features/billing/data/mappers/entitlement_mapper.dart';
import 'package:ataulfo/features/billing/domain/entities/entitlement.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _body({Object? used, Object? cap}) => <String, dynamic>{
  'plan_code': 'pro',
  'status': 'active',
  'trial_expired': false,
  'credits_used': 12,
  'credit_cap': 10000,
  'within_quota': true,
  'quota_exceeded': false,
  'storage_used_mb': 100,
  'storage_quota_mb': 512,
  'eligible_providers': const <dynamic>['MINIMAX'],
  'features': const <dynamic>['media_gallery'],
  'image_gen_used': ?used,
  'image_gen_cap': ?cap,
};

void main() {
  group('image_gen_used/cap en el DTO (campos ADITIVOS, snake_case plano)', () {
    test('ausentes ⇒ null (backend viejo no rompe)', () {
      final dto = EntitlementDto.fromJson(_body());
      expect(dto.imageGen, isNull);
    });

    test('presentes ⇒ used/cap parseados', () {
      final dto = EntitlementDto.fromJson(_body(used: 3, cap: 150));
      expect(dto.imageGen?.used, 3);
      expect(dto.imageGen?.cap, 150);
    });

    test('a medias o con tipo inválido ⇒ FormatException (wire roto)', () {
      // El backend emite AMBOS o ninguno: uno solo es un wire roto.
      expect(
        () => EntitlementDto.fromJson(_body(used: 3)),
        throwsFormatException,
      );
      expect(
        () => EntitlementDto.fromJson(_body(cap: 150)),
        throwsFormatException,
      );
      expect(
        () => EntitlementDto.fromJson(_body(used: '3', cap: 150)),
        throwsFormatException,
      );
      expect(
        () => EntitlementDto.fromJson(_body(used: 3, cap: 'muchas')),
        throwsFormatException,
      );
    });
  });

  group('image_gen mapper + entidad', () {
    test('el mapper proyecta los campos a la entidad (y su ausencia)', () {
      final con = EntitlementMapper.dtoToEntity(
        EntitlementDto.fromJson(_body(used: 3, cap: 150)),
      );
      expect(con.imageGen, const ImageGenUsage(used: 3, cap: 150));

      final sin = EntitlementMapper.dtoToEntity(
        EntitlementDto.fromJson(_body()),
      );
      expect(sin.imageGen, isNull);
    });

    test('la igualdad de Entitlement distingue el consumo de imágenes', () {
      final a = EntitlementMapper.dtoToEntity(
        EntitlementDto.fromJson(_body(used: 3, cap: 150)),
      );
      final b = EntitlementMapper.dtoToEntity(
        EntitlementDto.fromJson(_body(used: 4, cap: 150)),
      );
      final c = EntitlementMapper.dtoToEntity(EntitlementDto.fromJson(_body()));
      expect(a, isNot(b));
      expect(a, isNot(c));
      expect(
        a,
        EntitlementMapper.dtoToEntity(
          EntitlementDto.fromJson(_body(used: 3, cap: 150)),
        ),
      );
    });
  });
}
