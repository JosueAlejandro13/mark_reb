import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/providers/login_provider.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _rememberMe = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isFirstCheck = true;
  bool _hasShownNoInternet = false;

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
  }

  void _checkInternetConnection() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      bool hasInternet =
          !result.contains(ConnectivityResult.none) && result.isNotEmpty;

      if (_isFirstCheck) {
        _isFirstCheck = false;
        // Si arranca sin internet, lo mostramos, si arranca con internet no hacemos ruido.
        if (!hasInternet) {
          _showNoInternetAlert();
          _hasShownNoInternet = true;
        }
        return;
      }

      if (!hasInternet) {
        if (!_hasShownNoInternet) {
          _showNoInternetAlert();
          _hasShownNoInternet = true;
        }
      } else {
        if (_hasShownNoInternet) {
          _showRestoredAlert();
          _hasShownNoInternet = false;
        }
      }
    });
  }

  void _showNoInternetAlert() {
    if (!mounted) return;
    showTopSnackBar(
      Overlay.of(context),
      const CustomSnackBar.error(
        message: "No hay conexión a internet. Verifica tu red.",
        icon: Icon(Icons.wifi_off, color: Color(0x15000000), size: 120),
      ),
      displayDuration: const Duration(seconds: 4),
    );
  }

  void _showRestoredAlert() {
    if (!mounted) return;
    showTopSnackBar(
      Overlay.of(context),
      const CustomSnackBar.success(
        message: "Conexión a internet restaurada.",
        icon: Icon(Icons.wifi, color: Color(0x15000000), size: 120),
      ),
      displayDuration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final loginState = ref.watch(loginProvider);

    return Scaffold(
      backgroundColor: const Color(
          0xFFE5E7EB), // Fondo base gris claro por si la imagen es transparente
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ==========================================
          // MITAD SUPERIOR: Imagen cargps.png
          // ==========================================
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight *
                0.55, // Un poco más de la mitad para que la tarjeta la cubra bien
            child: Image.asset(
              'assets/cargps.png',
              fit: BoxFit
                  .cover, // Para que llene todo el espacio como en tu foto
              alignment: Alignment.center,
            ),
          ),

          // ==========================================
          // MITAD INFERIOR: Contenedor Blanco (Formulario)
          // ==========================================
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: screenHeight * 0.65, // Ocupa el 65% inferior
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 40,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 30,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Títulos alineados a la izquierda
                        Text(
                          'Iniciar Sesión',
                          style: TextStyle(
                            fontSize: screenWidth * 0.070,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ingresa tus datos para acceder al sistema.',
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Etiqueta Usuario
                        Text(
                          'Usuario',
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            fontWeight: FontWeight.bold,
                            color: const Color(
                                0xFF1E293B), // Color oscuro para la etiqueta
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Campo Correo
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(
                              fontSize: screenWidth * 0.038,
                              fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'ejemplo@correo.com',
                            hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w400),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 18, horizontal: 16),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.grey.shade300, width: 1)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.grey.shade300, width: 1)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Color(0xFF005999), width: 1.5)),
                          ),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Requerido'
                              : null,
                        ),

                        const SizedBox(height: 20),

                        // Etiqueta Contraseña & Olvidó Contraseña
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Contraseña',
                              style: TextStyle(
                                fontSize: screenWidth * 0.035,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                  context, '/forgot-password'),
                              child: Text(
                                '¿Olvidó la contraseña?',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.033,
                                  color: const Color(0xFF005999),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Campo Contraseña
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(
                              fontSize: screenWidth * 0.038,
                              fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Ingresa tu contraseña',
                            hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w400),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 18, horizontal: 16),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.grey.shade300, width: 1)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.grey.shade300, width: 1)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Color(0xFF005999), width: 1.5)),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: IconButton(
                                icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.grey.shade400,
                                    size: 22),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Requerido'
                              : null,
                        ),

                        const SizedBox(height: 20),

                        // Recordarme
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _rememberMe,
                                activeColor: const Color(0xFF005999),
                                checkColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        4)), // Cuadrado redondeado
                                side: BorderSide(
                                    color: Colors.grey.shade400, width: 1.5),
                                onChanged: (val) =>
                                    setState(() => _rememberMe = val ?? false),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Recordarme',
                              style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),

                        const SizedBox(height: 35),

                        // Botón de Inicio de Sesión
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: loginState.isLoading
                                ? null
                                : () {
                                    if (_formKey.currentState!.validate()) {
                                      FocusScope.of(context).unfocus();
                                      ref.read(loginProvider.notifier).login(
                                          context,
                                          _emailController.text.trim(),
                                          _passwordController.text.trim(),
                                          _rememberMe);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF005999),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              'Iniciar Sesión',
                              style: TextStyle(
                                  fontSize: screenWidth * 0.038,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ==========================================
          // Capa de Carga Global
          // ==========================================
          if (loginState.isLoading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Lottie.asset(
                    'assets/loading.json',
                    width: screenWidth * 0.2,
                    repeat: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
