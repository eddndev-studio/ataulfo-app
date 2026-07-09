import 'package:ataulfo/features/public_catalog/domain/entities/catalog_appearance.dart';
import 'package:ataulfo/features/public_catalog/domain/entities/public_catalog_settings.dart';
import 'package:ataulfo/features/public_catalog/domain/failures/public_catalog_failure.dart';
import 'package:ataulfo/features/public_catalog/domain/repositories/public_catalog_repository.dart';
import 'package:ataulfo/features/public_catalog/presentation/bloc/public_catalog_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements PublicCatalogRepository {
  _FakeRepo();

  PublicCatalogSettings? getResult;
  PublicCatalogFailure? getFailure;
  PublicCatalogSettings? updateResult;
  PublicCatalogFailure? updateFailure;
  ({bool enabled, String slug, CatalogDesign design, CatalogAccent accent})?
  lastUpdate;

  @override
  Future<PublicCatalogSettings> get() async {
    if (getFailure != null) throw getFailure!;
    return getResult!;
  }

  @override
  Future<PublicCatalogSettings> update({
    required bool enabled,
    required String slug,
    required CatalogDesign design,
    required CatalogAccent accent,
  }) async {
    lastUpdate = (enabled: enabled, slug: slug, design: design, accent: accent);
    if (updateFailure != null) throw updateFailure!;
    return updateResult!;
  }
}

void main() {
  const loaded = PublicCatalogSettings(
    enabled: false,
    slug: null,
    url: null,
    design: CatalogDesign.carta,
    accent: CatalogAccent.mango,
  );

  group('load', () {
    test('éxito ⇒ loaded con settings', () async {
      final repo = _FakeRepo()..getResult = loaded;
      final cubit = PublicCatalogCubit(repo);
      await cubit.load();
      expect(cubit.state.status, PublicCatalogStatus.loaded);
      expect(cubit.state.settings, loaded);
    });

    test('falla ⇒ error con loadFailure', () async {
      final repo = _FakeRepo()
        ..getFailure = const PublicCatalogNetworkFailure();
      final cubit = PublicCatalogCubit(repo);
      await cubit.load();
      expect(cubit.state.status, PublicCatalogStatus.error);
      expect(cubit.state.loadFailure, const PublicCatalogNetworkFailure());
    });
  });

  group('save', () {
    test(
      'éxito ⇒ settings del backend, saving apagado, sin saveFailure',
      () async {
        const after = PublicCatalogSettings(
          enabled: true,
          slug: 'mi-tienda',
          url: 'https://ataulfo.app/c/mi-tienda',
          design: CatalogDesign.membrete,
          accent: CatalogAccent.petroleo,
        );
        final repo = _FakeRepo()
          ..getResult = loaded
          ..updateResult = after;
        final cubit = PublicCatalogCubit(repo);
        await cubit.load();
        await cubit.save(
          enabled: true,
          slug: 'mi-tienda',
          design: CatalogDesign.membrete,
          accent: CatalogAccent.petroleo,
        );
        expect(repo.lastUpdate, (
          enabled: true,
          slug: 'mi-tienda',
          design: CatalogDesign.membrete,
          accent: CatalogAccent.petroleo,
        ));
        expect(cubit.state.settings, after);
        expect(cubit.state.saving, false);
        expect(cubit.state.saveFailure, isNull);
      },
    );

    test(
      'falla ⇒ saveFailure, saving apagado, settings previos intactos',
      () async {
        final repo = _FakeRepo()
          ..getResult = loaded
          ..updateFailure = const PublicCatalogSlugTakenFailure();
        final cubit = PublicCatalogCubit(repo);
        await cubit.load();
        await cubit.save(
          enabled: true,
          slug: 'ocupado',
          design: CatalogDesign.carta,
          accent: CatalogAccent.mango,
        );
        expect(cubit.state.saveFailure, const PublicCatalogSlugTakenFailure());
        expect(cubit.state.saving, false);
        expect(cubit.state.settings, loaded);
      },
    );
  });
}
