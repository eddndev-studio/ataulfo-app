import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_page_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Rect> pumpContainer(
    WidgetTester tester,
    Widget container,
  ) async {
    tester.view.physicalSize = const Size(436, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: container,
        ),
      ),
    );

    return tester.getRect(find.byKey(const Key('page-content')));
  }

  testWidgets('primary aplica el gutter semántico de 20 dp', (tester) async {
    final rect = await pumpContainer(
      tester,
      const AppPrimaryPageContainer(
        top: AppTokens.sp3,
        bottom: AppTokens.sp2,
        child: SizedBox(
          key: Key('page-content'),
          width: double.infinity,
          height: 40,
        ),
      ),
    );

    expect(AppPageGutters.primary, AppTokens.sp5);
    expect(rect.left, AppTokens.sp5);
    expect(rect.right, 436 - AppTokens.sp5);
    expect(rect.top, AppTokens.sp3);
  });

  testWidgets('detail aplica el gutter semántico de 24 dp', (tester) async {
    final rect = await pumpContainer(
      tester,
      const AppDetailPageContainer(
        top: AppTokens.sp4,
        bottom: AppTokens.sp3,
        child: SizedBox(
          key: Key('page-content'),
          width: double.infinity,
          height: 40,
        ),
      ),
    );

    expect(AppPageGutters.detail, AppTokens.sp6);
    expect(rect.left, AppTokens.sp6);
    expect(rect.right, 436 - AppTokens.sp6);
    expect(rect.top, AppTokens.sp4);
  });
}
