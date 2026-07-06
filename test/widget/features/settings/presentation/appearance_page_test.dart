import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_switch.dart';
import 'package:ataulfo/core/prefs/motion_settings_cubit.dart';
import 'package:ataulfo/core/storage/secure_kv_store.dart';
import 'package:ataulfo/features/settings/presentation/pages/appearance_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

void main() {
  Widget host(MotionSettingsCubit cubit) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<MotionSettingsCubit>.value(
      value: cubit,
      // En la app real, el router monta Scaffold+AppBar('Apariencia') y la
      // página es content-only, como toda subpágina.
      child: const Scaffold(body: AppearancePage()),
    ),
  );

  testWidgets('muestra el toggle de animaciones con el estado vivo (ON)', (
    tester,
  ) async {
    final cubit = MotionSettingsCubit(_MemKv());
    addTearDown(cubit.close);

    await tester.pumpWidget(host(cubit));

    expect(find.text('Animaciones'), findsOneWidget);
    final sw = tester.widget<AppSwitch>(
      find.byKey(const Key('appearance.animations')),
    );
    expect(sw.value, isTrue);
  });

  testWidgets('estado apagado pinta el switch apagado', (tester) async {
    final cubit = MotionSettingsCubit(_MemKv(), initial: false);
    addTearDown(cubit.close);

    await tester.pumpWidget(host(cubit));

    final sw = tester.widget<AppSwitch>(
      find.byKey(const Key('appearance.animations')),
    );
    expect(sw.value, isFalse);
  });

  testWidgets('apagar el toggle emite, persiste y NO hay botón Guardar '
      '(apply-inmediato)', (tester) async {
    final kv = _MemKv();
    final cubit = MotionSettingsCubit(kv);
    addTearDown(cubit.close);

    await tester.pumpWidget(host(cubit));
    await tester.tap(find.byKey(const Key('appearance.animations')));
    await tester.pumpAndSettle();

    expect(cubit.state, isFalse);
    expect(kv.data[MotionSettingsCubit.storageKey], 'false');
    // El switch refleja el estado nuevo sin pasar por ningún Guardar.
    final sw = tester.widget<AppSwitch>(
      find.byKey(const Key('appearance.animations')),
    );
    expect(sw.value, isFalse);
    expect(find.widgetWithText(AppButton, 'Guardar'), findsNothing);
  });
}
