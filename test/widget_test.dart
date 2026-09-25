import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mark_v3/main.dart';

void main() {
  testWidgets('App renders main screen with larger screen size', (WidgetTester tester) async {
    // Simula una pantalla más grande (ej. 1080x1920)
    tester.binding.window.physicalSizeTestValue = const Size(1080, 1920);
    tester.binding.window.devicePixelRatioTestValue = 1.0;

    await tester.pumpWidget(const MyApp());

    // Espera a que la pantalla se estabilice
    await tester.pumpAndSettle();

    // Verifica que el widget principal esté presente
    expect(find.byType(MaterialApp), findsOneWidget);

    // Limpia los valores de prueba para que no afecten otros tests
    addTearDown(() {
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });
  });
}
