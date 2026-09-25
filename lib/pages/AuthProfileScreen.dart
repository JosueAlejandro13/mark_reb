import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AuthProfileScreen extends StatefulWidget {
  const AuthProfileScreen({super.key});

  @override
  _AuthProfileScreenState createState() => _AuthProfileScreenState();
}

class _AuthProfileScreenState extends State<AuthProfileScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Autentica tu perfil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _phoneController,
                decoration:
                    const InputDecoration(labelText: 'Número de teléfono'),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa tu número de teléfono';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _authenticateUser,
                      child: const Text('Enviar Código'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _authenticateUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      String phone = _phoneController.text;
      await enviarOTPSMS(phone);

      setState(() {
        _isLoading = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationScreen(phone: phone),
        ),
      );
    }
  }

  Future<void> enviarOTPSMS(String telefono) async {
    debugPrint('Enviando OTP al número $telefono');

    const serviceSid = String.fromEnvironment('TWILIO_SERVICE_SID', defaultValue: 'YOUR_TWILIO_SERVICE_SID');
    const accountSid = String.fromEnvironment('TWILIO_ACCOUNT_SID', defaultValue: 'YOUR_TWILIO_ACCOUNT_SID');
    const authToken = String.fromEnvironment('TWILIO_AUTH_TOKEN', defaultValue: 'YOUR_TWILIO_AUTH_TOKEN');

    final response = await http.post(
      Uri.parse(
          'https://verify.twilio.com/v2/Services/$serviceSid/Verifications'),
      headers: {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'To': telefono,
        'Channel': 'sms',
      },
    );

    if (response.statusCode == 200) {
      debugPrint('OTP enviado correctamente al número $telefono');
    } else {
      debugPrint('Error al enviar el SMS: ${response.body}');
    }
  }
}

class VerificationScreen extends StatelessWidget {
  final String phone;
  final TextEditingController _codeController = TextEditingController();

  VerificationScreen({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verificación de OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Código OTP'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _verifyCode(context),
              child: const Text('Verificar Código'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyCode(BuildContext context) async {
    String code = _codeController.text;

    const serviceSid = String.fromEnvironment('TWILIO_SERVICE_SID', defaultValue: 'YOUR_TWILIO_SERVICE_SID');
    const accountSid = String.fromEnvironment('TWILIO_ACCOUNT_SID', defaultValue: 'YOUR_TWILIO_ACCOUNT_SID');
    const authToken = String.fromEnvironment('TWILIO_AUTH_TOKEN', defaultValue: 'YOUR_TWILIO_AUTH_TOKEN');

    final response = await http.post(
      Uri.parse(
          'https://verify.twilio.com/v2/Services/$serviceSid/VerificationCheck'),
      headers: {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'To': phone,
        'Code': code,
      },
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      if (responseBody['valid']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código verificado correctamente')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Código inválido: ${responseBody['message']}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al verificar el código: ${response.body}')),
      );
    }
  }
}
