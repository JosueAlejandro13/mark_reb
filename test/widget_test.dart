import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mark_v3/main.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App renders main screen with larger screen size', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    // Adelantar el tiempo para agotar el Timer de 5s del SplashScreen
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
