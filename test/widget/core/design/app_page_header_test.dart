import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(body: child),
  );

  testWidgets('usa chrome neutro con divisor en lugar de una card destacada', (
    tester,
  ) async {
    await tester.pumpWidget(host(const AppPageHeader(title: 'Agenda')));

    final surface = tester.widget<Material>(
      find.byKey(const Key('app_page_header.surface')),
    );
    final divider = tester.widget<ColoredBox>(
      find.byKey(const Key('app_page_header.divider')),
    );

    expect(surface.color, AppTokens.surface1);
    expect(divider.color, AppTokens.divider);
    expect(find.text('Agenda'), findsOneWidget);
  });

  testWidgets('conserva contenido secundario y acceso al perfil', (
    tester,
  ) async {
    var profileTaps = 0;
    await tester.pumpWidget(
      host(
        AppPageHeader(
          title: 'Asistentes',
          avatarInitial: 'O',
          onAvatarTap: () => profileTaps++,
          content: const Text('Controles de sección'),
        ),
      ),
    );

    expect(find.text('Controles de sección'), findsOneWidget);
    await tester.tap(find.byKey(const Key('app_page_header.avatar')));
    expect(profileTaps, 1);
  });
}
