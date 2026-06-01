import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/wa_labels/data/datasources/wa_assoc_datasource.dart';
import 'package:ataulfo/features/wa_labels/data/datasources/wa_catalog_datasource.dart';
import 'package:ataulfo/features/wa_labels/data/datasources/wa_label_events_datasource.dart';
import 'package:ataulfo/features/wa_labels/data/datasources/wa_mapping_datasource.dart';
import 'package:ataulfo/features/wa_labels/data/repositories/wa_labels_repository_impl.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label_live_event.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label_mapping.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCatalog extends Mock implements WaCatalogDatasource {}

class _MockAssoc extends Mock implements WaAssocDatasource {}

class _MockMapping extends Mock implements WaMappingDatasource {}

class _MockEvents extends Mock implements WaLabelEventsDatasource {}

void main() {
  late _MockCatalog catalog;
  late _MockAssoc assoc;
  late _MockMapping mapping;
  late _MockEvents events;
  late WaLabelsRepositoryImpl repo;

  setUp(() {
    catalog = _MockCatalog();
    assoc = _MockAssoc();
    mapping = _MockMapping();
    events = _MockEvents();
    repo = WaLabelsRepositoryImpl(
      catalog: catalog,
      assoc: assoc,
      mapping: mapping,
      events: events,
    );
  });

  test('listCatalog delega en el datasource de catálogo', () async {
    const label = WaLabel(
      waLabelId: '1000',
      name: 'VIP',
      color: 3,
      deleted: false,
    );
    when(
      () => catalog.listCatalog('b1'),
    ).thenAnswer((_) async => <WaLabel>[label]);
    expect(await repo.listCatalog('b1'), <WaLabel>[label]);
    verify(() => catalog.listCatalog('b1')).called(1);
  });

  test('createLabel pasa name/color al datasource', () async {
    const label = WaLabel(
      waLabelId: '1000',
      name: 'VIP',
      color: 3,
      deleted: false,
    );
    when(
      () => catalog.createLabel(botId: 'b1', name: 'VIP', color: 3),
    ).thenAnswer((_) async => label);
    expect(await repo.createLabel(botId: 'b1', name: 'VIP', color: 3), label);
    verify(
      () => catalog.createLabel(botId: 'b1', name: 'VIP', color: 3),
    ).called(1);
  });

  test('deleteLabel delega', () async {
    when(
      () => catalog.deleteLabel(botId: 'b1', waLabelId: '1000'),
    ).thenAnswer((_) async {});
    await repo.deleteLabel(botId: 'b1', waLabelId: '1000');
    verify(() => catalog.deleteLabel(botId: 'b1', waLabelId: '1000')).called(1);
  });

  test('liveEvents delega en el datasource de eventos', () {
    final stream = Stream<WaLabelLiveEvent>.value(const WaLabelReconnected());
    when(() => events.liveEvents('b1')).thenAnswer((_) => stream);
    expect(repo.liveEvents('b1'), same(stream));
    verify(() => events.liveEvents('b1')).called(1);
  });

  test('labelChat pasa todos los argumentos', () async {
    when(
      () => assoc.labelChat(
        botId: 'b1',
        waLabelId: '1000',
        chatLid: 'c1',
        kind: ConversationKind.group,
        labeled: true,
      ),
    ).thenAnswer((_) async {});
    await repo.labelChat(
      botId: 'b1',
      waLabelId: '1000',
      chatLid: 'c1',
      kind: ConversationKind.group,
      labeled: true,
    );
    verify(
      () => assoc.labelChat(
        botId: 'b1',
        waLabelId: '1000',
        chatLid: 'c1',
        kind: ConversationKind.group,
        labeled: true,
      ),
    ).called(1);
  });

  test('setMapping delega y devuelve el mapeo', () async {
    const m = WaLabelMapping(waLabelId: '1000', labelId: 'uuid-vip');
    when(
      () => mapping.setMapping(
        botId: 'b1',
        waLabelId: '1000',
        labelId: 'uuid-vip',
      ),
    ).thenAnswer((_) async => m);
    expect(
      await repo.setMapping(
        botId: 'b1',
        waLabelId: '1000',
        labelId: 'uuid-vip',
      ),
      m,
    );
    verify(
      () => mapping.setMapping(
        botId: 'b1',
        waLabelId: '1000',
        labelId: 'uuid-vip',
      ),
    ).called(1);
  });

  test('listMappings delega', () async {
    when(
      () => mapping.listMappings('b1'),
    ).thenAnswer((_) async => const <WaLabelMapping>[]);
    expect(await repo.listMappings('b1'), isEmpty);
    verify(() => mapping.listMappings('b1')).called(1);
  });
}
