import 'package:ataulfo/core/prefs/motion_settings_cubit.dart';
import 'package:ataulfo/core/storage/secure_kv_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemKv implements SecureKvStore {
  final Map<String, String> data = <String, String>{};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}

/// Store que falla al escribir: la preferencia es cosmética y un storage roto
/// jamás debe tirar la app ni revertir el estado ya emitido.
class _BrokenKv extends _MemKv {
  @override
  Future<void> write(String key, String value) async {
    throw Exception('storage roto');
  }
}

void main() {
  group('MotionSettingsCubit.load', () {
    test(
      'sin clave persistida arranca encendido (opt-out: default ON)',
      () async {
        final cubit = await MotionSettingsCubit.load(_MemKv());
        expect(cubit.state, isTrue);
        await cubit.close();
      },
    );

    test('con "false" persistido arranca apagado', () async {
      final kv = _MemKv();
      kv.data[MotionSettingsCubit.storageKey] = 'false';
      final cubit = await MotionSettingsCubit.load(kv);
      expect(cubit.state, isFalse);
      await cubit.close();
    });

    test('con basura persistida cae al default encendido', () async {
      final kv = _MemKv();
      kv.data[MotionSettingsCubit.storageKey] = '???';
      final cubit = await MotionSettingsCubit.load(kv);
      expect(cubit.state, isTrue);
      await cubit.close();
    });
  });

  group('MotionSettingsCubit.setEnabled', () {
    test('apagar emite false y persiste "false"', () async {
      final kv = _MemKv();
      final cubit = MotionSettingsCubit(kv);
      await cubit.setEnabled(false);
      expect(cubit.state, isFalse);
      expect(kv.data[MotionSettingsCubit.storageKey], 'false');
      await cubit.close();
    });

    test('re-encender emite true y persiste "true"', () async {
      final kv = _MemKv();
      kv.data[MotionSettingsCubit.storageKey] = 'false';
      final cubit = MotionSettingsCubit(kv, initial: false);
      await cubit.setEnabled(true);
      expect(cubit.state, isTrue);
      expect(kv.data[MotionSettingsCubit.storageKey], 'true');
      await cubit.close();
    });

    test('si el storage falla, el estado emitido se conserva (pref cosmética, '
        'nunca crashea)', () async {
      final cubit = MotionSettingsCubit(_BrokenKv());
      await cubit.setEnabled(false);
      expect(cubit.state, isFalse);
      await cubit.close();
    });
  });
}
