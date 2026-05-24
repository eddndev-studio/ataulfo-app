import 'package:agentic/core/storage/secure_kv_store.dart';
import 'package:agentic/features/auth/data/repositories/token_storage.dart';
import 'package:agentic/features/auth/domain/entities/auth_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake en memoria del puerto. Suficiente para verificar el contrato del
/// `TokenStorage`; no necesita conocimiento de Keystore.
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
  late _MemKv kv;
  late TokenStorage storage;

  setUp(() {
    kv = _MemKv();
    storage = TokenStorage(kv);
  });

  const sample = AuthTokens(
    accessToken: 'a.b.c',
    refreshToken: 'r-32',
    tokenType: 'Bearer',
    expiresInSeconds: 900,
  );

  test('read sin save previo devuelve null', () async {
    expect(await storage.read(), isNull);
  });

  test('save + read devuelve los mismos tokens', () async {
    await storage.save(sample);

    final got = await storage.read();
    expect(got, sample);
  });

  test('save sobreescribe los tokens previos', () async {
    await storage.save(sample);
    const next = AuthTokens(
      accessToken: 'a2',
      refreshToken: 'r2',
      tokenType: 'Bearer',
      expiresInSeconds: 60,
    );

    await storage.save(next);

    expect(await storage.read(), next);
  });

  test('clear elimina los tokens', () async {
    await storage.save(sample);

    await storage.clear();

    expect(await storage.read(), isNull);
  });

  test('read tolera payload corrupto devolviendo null', () async {
    await kv.write('auth.tokens.v1', 'no-es-json-valido');

    expect(await storage.read(), isNull);
  });
}
