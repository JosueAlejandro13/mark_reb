import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mark_v3/pages/Profile_/activate_two_factor_page.dart';
import 'package:mark_v3/pages/Profile_/deactivate_two_factor_page.dart';
import 'package:mark_v3/pages/Profile_/two_factor_verify_code_page.dart';

void main() {
  group('Pruebas de Verificación en 2 Pasos (Pantallas Completas)', () {
    testWidgets('ActivateTwoFactorPage se renderiza en pantalla completa con sus campos',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ActivateTwoFactorPage(
            usuario: 'chofer_test',
            currentEmail: 'test@empresa.com',
          ),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Activar Verificación'), findsOneWidget);
      expect(find.text('CONTRASEÑA DE LA CUENTA'), findsOneWidget);
      expect(find.text('CORREO ELECTRÓNICO PARA CÓDIGOS'), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);

      // Probar validación de campos vacíos
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa tu contraseña actual'), findsNWidgets(2));
    });

    testWidgets('DeactivateTwoFactorPage se renderiza en pantalla completa con sus campos',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DeactivateTwoFactorPage(
            usuario: 'chofer_test',
            correo: 'test@empresa.com',
          ),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Desactivar Verificación'), findsOneWidget);
      expect(find.text('CONTRASEÑA DE LA CUENTA'), findsOneWidget);
      expect(find.text('Continuar con Desactivación'), findsOneWidget);

      // Probar validación de contraseña vacía
      await tester.tap(find.text('Continuar con Desactivación'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa tu contraseña actual'), findsNWidgets(2));
    });

    testWidgets(
        'TwoFactorVerifyCodePage renderiza los 6 cuadros de código y soporta autocompletado',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TwoFactorVerifyCodePage(
            desafio: 'desafio_test_123',
            email: 'test@empresa.com',
            isActivation: true,
            title: 'Confirma el código enviado',
            subtitle: 'Enviamos un código de 6 dígitos a test@empresa.com',
          ),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Confirma el código enviado'), findsOneWidget);
      expect(find.text('Confirmar Código'), findsOneWidget);

      // Debe haber exactamente 6 cuadros TextFormField para los dígitos
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(6));

      // Ingresar los 6 dígitos uno a uno
      await tester.enterText(textFields.at(0), '1');
      await tester.pump();
      await tester.enterText(textFields.at(1), '2');
      await tester.pump();
      await tester.enterText(textFields.at(2), '3');
      await tester.pump();
      await tester.enterText(textFields.at(3), '4');
      await tester.pump();
      await tester.enterText(textFields.at(4), '5');
      await tester.pump();
      await tester.enterText(textFields.at(5), '6');
      await tester.pump();

      // Al completar los 6 dígitos, se dispara automáticamente el auto-envío (150ms delay)
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'TwoFactorVerifyCodePage distribuye el código pegado o autocompletado en los 6 cuadros',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TwoFactorVerifyCodePage(
            desafio: 'desafio_test_123',
            email: 'test@empresa.com',
            isActivation: false,
            title: 'Autorizar desactivación',
            subtitle: 'Escribe el código de 6 dígitos enviado a tu correo',
          ),
        ),
      );

      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(6));

      // Simular pegado de código o autofill de 6 dígitos en el primer cuadro
      await tester.enterText(textFields.at(0), '654321');
      await tester.pump();

      // Verificar que los cuadros recibieron los dígitos individuales
      expect(find.text('6'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Verificar que el temporizador de auto-envío avanza
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
    });
  });
}
