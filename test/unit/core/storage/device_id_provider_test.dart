import 'package:agentic/core/storage/device_id_provider.dart';
import 'package:agentic/core/storage/secure_kv_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemKv implements SecureKvStore {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

void main() {
  test('genera UUID en primer arranque y lo persiste', () async {
    final kv = _MemKv();
    final provider = DeviceIdProvider(kv);

    final first = await provider.getOrCreate();

    expect(first, isNotEmpty);
    expect(await kv.read('device.id.v1'), first);
  });

  test('devuelve el mismo UUID en arranques sucesivos', () async {
    final kv = _MemKv();
    final provider = DeviceIdProvider(kv);

    final first = await provider.getOrCreate();
    final second = await provider.getOrCreate();

    expect(second, first);
  });

  test('respeta el UUID ya persistido por una instancia previa', () async {
    final kv = _MemKv();
    await kv.write('device.id.v1', 'pre-existente-uuid');
    final provider = DeviceIdProvider(kv);

    final id = await provider.getOrCreate();

    expect(id, 'pre-existente-uuid');
  });
}
