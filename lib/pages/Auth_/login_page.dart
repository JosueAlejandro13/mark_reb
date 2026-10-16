import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/providers/Auth_/login_provider.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// Autor: Josue Hernandez
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
    SnackbarTop.showError(
      context,
      "No hay conexión a internet. Verifica tu red.",
      title: "Sin Conexión",
    );
  }

  void _showRestoredAlert() {
    if (!mounted) return;
    SnackbarTop.showSuccess(
      context,
      "Conexión a internet restaurada.",
      title: "Conexión Restaurada",
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
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final bool isTablet = screenWidth > 600;
    final loginState = ref.watch(loginProvider);

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F7FD),
        resizeToAvoidBottomInset: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFE0F2FE),
                Color(0xFFF0F9FF),
                Colors.white,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.35, 0.75],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isTablet ? 500 : double.infinity,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              children: [
                                // ── Top Header: Logo a la izquierda + Animación a la derecha ──
                                SizedBox(
                                  height: isTablet ? 215 : 190,
                                  width: double.infinity,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // ── Lottie Animation a la derecha (emergiendo detrás de la curva) ──
                                      Positioned(
                                        top: isTablet ? 24 : 20,
                                        right: isTablet ? 0 : -8,
                                        height: isTablet ? 260 : 240,
                                        width: screenWidth,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Transform.translate(
                                            offset: const Offset(0, 24),
                                            child: Lottie.asset(
                                              'assets/caleni_rutas_lottie.json',
                                              fit: BoxFit.contain,
                                              alignment: Alignment.centerRight,
                                              repeat: true,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // ── Logo y Branding (arriba a la izquierda) ──
                                      Positioned(
                                        top: isTablet ? 1 : 9,
                                        left: isTablet ? 36 : 24,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Image.asset(
                                              'assets/iconik.png',
                                              width: 36,
                                              height: 36,
                                              fit: BoxFit.contain,
                                            ),
                                            const SizedBox(width: 10),
                                            const Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'CALENI',
                                                  style: TextStyle(
                                                    fontSize: 16.5,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF0A1E34),
                                                    letterSpacing: 1.2,
                                                    height: 1.0,
                                                  ),
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  'TELEMATICS',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF0284C7),
                                                    letterSpacing: 1.8,
                                                    height: 1.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // ── Tarjeta Blanca inferior con curva asimétrica ─
                                Expanded(
                                  child: CustomPaint(
                                    painter: _WaveShadowPainter(),
                                    child: ClipPath(
                                      clipper: _WaveClipper(),
                                      child: Container(
                                        color: Colors.white,
                                        width: double.infinity,
                                        child: Stack(
                                          children: [
                                            // ── Decoración inferior de silueta urbana ─
                                            Positioned(
                                              left: 0,
                                              right: 0,
                                              bottom: 0,
                                              height: 75,
                                              child: IgnorePointer(
                                                child: CustomPaint(
                                                  painter:
                                                      _BottomSkylinePainter(),
                                                ),
                                              ),
                                            ),

                                            // ── Contenido del formulario ─────────────
                                            Padding(
                                              padding: EdgeInsets.only(
                                                left: isTablet
                                                    ? 36
                                                    : screenWidth * 0.075,
                                                right: isTablet
                                                    ? 36
                                                    : screenWidth * 0.075,
                                                top: 36,
                                                bottom: mediaQuery
                                                        .viewInsets.bottom +
                                                    20,
                                              ),
                                              child: Form(
                                                key: _formKey,
                                                child: AbsorbPointer(
                                                  absorbing:
                                                      loginState.isLoading,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      // ── Cápsula Bienvenido ─────────
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 10,
                                                          vertical: 4,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                              0xFFE0F2FE),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                          border: Border.all(
                                                            color: const Color(
                                                                0xFFBAE6FD),
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: const Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .wb_sunny_rounded,
                                                              size: 13,
                                                              color: Color(
                                                                  0xFF0284C7),
                                                            ),
                                                            SizedBox(width: 6),
                                                            Text(
                                                              'Bienvenido',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: Color(
                                                                    0xFF0284C7),
                                                                letterSpacing:
                                                                    0.2,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),

                                                      const SizedBox(
                                                          height: 10),

                                                      // ── Título principal ────────────
                                                      const Text(
                                                        'Iniciar Sesión',
                                                        style: TextStyle(
                                                          fontSize: 26,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color:
                                                              Color(0xFF0F172A),
                                                          letterSpacing: -0.5,
                                                          height: 1.15,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      const Text(
                                                        'Ingresa tus credenciales para continuar.',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color:
                                                              Color(0xFF64748B),
                                                          fontWeight:
                                                              FontWeight.w400,
                                                        ),
                                                      ),

                                                      const SizedBox(
                                                          height: 16),

                                                      // ── Divisor decorativo ──────────
                                                      const Row(
                                                        children: [
                                                          Expanded(
                                                            child: Divider(
                                                              color: Color(
                                                                  0xFFE2E8F0),
                                                              thickness: 1,
                                                            ),
                                                          ),
                                                          Padding(
                                                            padding: EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        12),
                                                            child: Text(
                                                              'Accede a tu cuenta',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: Color(
                                                                    0xFF94A3B8),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: Divider(
                                                              color: Color(
                                                                  0xFFE2E8F0),
                                                              thickness: 1,
                                                            ),
                                                          ),
                                                        ],
                                                      ),

                                                      const SizedBox(
                                                          height: 14),

                                                      // ── Etiqueta Usuario ─────────────
                                                      const Text(
                                                        'Usuario',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              Color(0xFF0F172A),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),

                                                      // ── Campo Usuario ────────────────
                                                      TextFormField(
                                                        controller:
                                                            _emailController,
                                                        enabled: !loginState
                                                            .isLoading,
                                                        keyboardType:
                                                            TextInputType
                                                                .emailAddress,
                                                        validator: (val) {
                                                          if (val == null ||
                                                              val
                                                                  .trim()
                                                                  .isEmpty) {
                                                            return 'Por favor ingresa tu usuario o correo';
                                                          }
                                                          return null;
                                                        },
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Color(0xFF0F172A),
                                                        ),
                                                        decoration:
                                                            InputDecoration(
                                                          hintText:
                                                              'ejemplo@correo.com',
                                                          hintStyle:
                                                              const TextStyle(
                                                            color: Color(
                                                                0xFF94A3B8),
                                                            fontSize: 13.5,
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                          ),
                                                          filled: true,
                                                          fillColor: loginState
                                                                  .isLoading
                                                              ? const Color(
                                                                  0xFFF1F5F9)
                                                              : const Color(
                                                                  0xFFF8FAFC),
                                                          contentPadding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 16,
                                                            vertical: 13,
                                                          ),
                                                          isDense: true,
                                                          border:
                                                              OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        14),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Color(
                                                                  0xFFE2E8F0),
                                                              width: 1.2,
                                                            ),
                                                          ),
                                                          enabledBorder:
                                                              OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        14),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Color(
                                                                  0xFFE2E8F0),
                                                              width: 1.2,
                                                            ),
                                                          ),
                                                          focusedBorder:
                                                              OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        14),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Color(
                                                                  0xFF0284C7),
                                                              width: 1.5,
                                                            ),
                                                          ),
                                                          disabledBorder:
                                                              OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        14),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Color(
                                                                  0xFFE2E8F0),
                                                              width: 1.0,
                                                            ),
                                                          ),
                                                          errorBorder:
                                                              OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        14),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Color(
                                                                  0xFFEF4444),
                                                              width: 1.2,
                                                            ),
                                                          ),
                                                          focusedErrorBorder:
                                                              OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        14),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Color(
                                                                  0xFFEF4444),
                                                              width: 1.8,
                                                            ),
                                                          ),
                                                        ),
                                                      ),

                                                      const SizedBox(
                                                          height: 12),

                                                      // ── Etiqueta Contraseña ─────────
                                                      const Text(
                                                        'Contraseña',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              Color(0xFF0F172A),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),

                                                      // ── Campo Contraseña ────────────
                                                      TextFormField(
                                                        controller:
                                                            _passwordController,
                                                        enabled: !loginState
                                                            .isLoading,
                                                        obscureText:
                                                            _obscurePassword,
                                                        validator: (val) {
                                                          if (val == null ||
                                                              val.isEmpty) {
                                                            return 'Por favor ingresa tu contraseña';
                                                          }
                                                          return null;
                                                        },
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Color(0xFF0F172A),
                                                        ),
                                                        decoration:
                                                            InputDecoration(
                                                          hintText:
                                                              'Ingresa tu contraseña',
                                                          hintStyle:
                                                              const TextStyle(
                                                            color: Color(
                                                                0xFF94A3B8),
                                                            fontSize: 13.5,
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                          ),
                                                          suffixIcon:
                                                              IconButton(
                                                            icon: Icon(
                                                              _obscurePassword
                                                                  ? Icons
                                                                      .visibility_off_outlined
                                                                  : Icons
                                                                      .visibility_outlined,
                                                              size: 20,
                                                              color: const Color(
                                                                  0xFF94A3B8),
                                                            ),
                                                            onPressed: () =>
                                                                setState(() =>
                                                                    _obscurePassword =
                                                                        !_obscurePassword),
                                                          ),
                                                          filled: true,
                                                          fillColor: loginState
                                                                  .isLoading
                                                              ? const Color(
                                                                  0xFFF1F5F9)
                                                              : const Color(
                                                                  0xFFF8FAFC),
                                                          contentPadding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 16,
                                                            vertical: 13,
                                                          ),
                                                          isDense: true,
                                                          border:
                                                              OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        14),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Color(
                                                                  0xFFE2E8F0),
                                                              width: 1.2,
                                                            ),
                                                          ),
                                                          enabledBorder:
                                                              OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        14),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Color(
                                                                  0xFFE2E8F0),
                                                              width: 1.2,
                                                            ),
                                                          ),
                                                          focusedBorder:
                                                              OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        14),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Color(
                                                                  0xFF0284C7),
                                                              width: 1.5,
                                                            ),
                                                          ),
                                                          disabledBorder:
                                                              OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        14),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Color(
                                                                  0xFFE2E8F0),
                                                              width: 1.0,
                                                            ),
                                                          ),
                                                          errorBorder:
                                                              OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        14),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Color(
                                                                  0xFFEF4444),
                                                              width: 1.2,
                                                            ),
                                                          ),
                                                          focusedErrorBorder:
                                                              OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        14),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Color(
                                                                  0xFFEF4444),
                                                              width: 1.8,
                                                            ),
                                                          ),
                                                        ),
                                                      ),

                                                      const SizedBox(
                                                          height: 12),

                                                      // ── Recordarme + ¿Olvidaste tu contraseña? ──
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          GestureDetector(
                                                            onTap: loginState
                                                                    .isLoading
                                                                ? null
                                                                : () => setState(() =>
                                                                    _rememberMe =
                                                                        !_rememberMe),
                                                            child: Row(
                                                              children: [
                                                                SizedBox(
                                                                  width: 20,
                                                                  height: 20,
                                                                  child:
                                                                      Checkbox(
                                                                    value:
                                                                        _rememberMe,
                                                                    activeColor:
                                                                        const Color(
                                                                            0xFF0284C7),
                                                                    checkColor:
                                                                        Colors
                                                                            .white,
                                                                    shape:
                                                                        RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              5),
                                                                    ),
                                                                    side:
                                                                        const BorderSide(
                                                                      color: Color(
                                                                          0xFF94A3B8),
                                                                      width:
                                                                          1.4,
                                                                    ),
                                                                    onChanged: loginState
                                                                            .isLoading
                                                                        ? null
                                                                        : (val) =>
                                                                            setState(() =>
                                                                                _rememberMe = val ?? false),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    width: 8),
                                                                const Text(
                                                                  'Recordarme',
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    color: Color(
                                                                        0xFF475569),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          GestureDetector(
                                                            onTap: loginState
                                                                    .isLoading
                                                                ? null
                                                                : () => Navigator
                                                                    .pushNamed(
                                                                        context,
                                                                        '/forgot-password'),
                                                            child: const Text(
                                                              '¿Olvidaste tu contraseña?',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                color: Color(
                                                                    0xFF0284C7),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),

                                                      const SizedBox(
                                                          height: 20),

                                                      // ── Botón Iniciar Sesión ─────────
                                                      LoadingActionButton(
                                                        text: 'Iniciar Sesión',
                                                        isLoading: loginState
                                                            .isLoading,
                                                        icon:
                                                            Icons.login_rounded,
                                                        height: 50,
                                                        borderRadius: 14,
                                                        fontSize: 15,
                                                        onPressed: () {
                                                          if (_formKey
                                                              .currentState!
                                                              .validate()) {
                                                            FocusScope.of(
                                                                    context)
                                                                .unfocus();
                                                            ref
                                                                .read(loginProvider
                                                                    .notifier)
                                                                .login(
                                                                  context,
                                                                  _emailController
                                                                      .text
                                                                      .trim(),
                                                                  _passwordController
                                                                      .text
                                                                      .trim(),
                                                                  _rememberMe,
                                                                );
                                                          }
                                                        },
                                                      ),

                                                      const SizedBox(
                                                          height: 20),

                                                      // ── Footer: Redes sociales ───────
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          _buildSocialIcon(
                                                            FontAwesomeIcons
                                                                .facebookF,
                                                            url:
                                                                'https://www.facebook.com/Caleni.mx',
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          _buildSocialIcon(
                                                            FontAwesomeIcons
                                                                .instagram,
                                                            url:
                                                                'https://www.instagram.com/caleni_mx/',
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          _buildSocialIcon(
                                                            FontAwesomeIcons
                                                                .globe,
                                                            url:
                                                                'https://www.caleni.com.mx/',
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          _buildSocialIcon(
                                                            FontAwesomeIcons
                                                                .linkedinIn,
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialIcon(dynamic icon, {bool isFilled = false, String? url}) {
    return GestureDetector(
      onTap: () async {
        if (url != null) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isFilled ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: isFilled
              ? null
              : Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        ),
        child: Center(
          child: FaIcon(
            icon,
            size: 14,
            color: isFilled ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

// ── Clipper: curva asimétrica elegante (alta a la izquierda, desciende suave a la derecha) ─
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    // Inicia en la parte superior izquierda a 22px
    path.moveTo(0, 24);
    // Curva cúbica suave que se mantiene alta a la izquierda y desciende hacia la derecha
    path.cubicTo(
      size.width * 0.22,
      6,
      size.width * 0.50,
      24,
      size.width * 0.70,
      52,
    );
    path.quadraticBezierTo(
      size.width * 0.88,
      66,
      size.width,
      52,
    );
    // Cierre rectangular hacia abajo
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveClipper old) => false;
}

// ── Painter: sombra difuminada detrás de la curva ────────────────────────────
class _WaveShadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x180284C7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    final path = Path();
    path.moveTo(0, 24);
    path.cubicTo(
      size.width * 0.22,
      6,
      size.width * 0.50,
      24,
      size.width * 0.70,
      52,
    );
    path.quadraticBezierTo(
      size.width * 0.88,
      66,
      size.width,
      52,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WaveShadowPainter old) => false;
}

// ── Painter: silueta urbana y detalle vegetal en tonos pastel al fondo ────────
class _BottomSkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final buildingPaint = Paint()
      ..color = const Color(0xFFE0F2FE).withOpacity(0.75)
      ..style = PaintingStyle.fill;

    final windowPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final leafPaint = Paint()
      ..color = const Color(0xFFBAE6FD).withOpacity(0.85)
      ..style = PaintingStyle.fill;

    // Suave loma o suelo ondulado
    final groundPath = Path();
    groundPath.moveTo(0, size.height);
    groundPath.lineTo(0, size.height - 18);
    groundPath.quadraticBezierTo(
      size.width * 0.35,
      size.height - 35,
      size.width * 0.65,
      size.height - 16,
    );
    groundPath.quadraticBezierTo(
      size.width * 0.85,
      size.height - 8,
      size.width,
      size.height - 14,
    );
    groundPath.lineTo(size.width, size.height);
    groundPath.close();

    final groundPaint = Paint()
      ..color = const Color(0xFFF0F9FF).withOpacity(0.95)
      ..style = PaintingStyle.fill;
    canvas.drawPath(groundPath, groundPaint);

    // Silueta de edificios en el cuadrante inferior derecho
    final startX = size.width * 0.62;

    // Edificio 1
    final b1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(startX, size.height - 52, 24, 42),
      const Radius.circular(3),
    );
    canvas.drawRRect(b1, buildingPaint);
    canvas.drawRect(
        Rect.fromLTWH(startX + 4, size.height - 44, 5, 7), windowPaint);
    canvas.drawRect(
        Rect.fromLTWH(startX + 13, size.height - 44, 5, 7), windowPaint);

    // Edificio 2 (más bajo)
    final b2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(startX + 28, size.height - 40, 20, 30),
      const Radius.circular(3),
    );
    canvas.drawRRect(b2, buildingPaint);
    canvas.drawRect(
        Rect.fromLTWH(startX + 34, size.height - 34, 4, 6), windowPaint);

    // Edificio 3 (más alto)
    final b3 = RRect.fromRectAndRadius(
      Rect.fromLTWH(startX + 52, size.height - 62, 26, 52),
      const Radius.circular(3),
    );
    canvas.drawRRect(b3, buildingPaint);
    canvas.drawRect(
        Rect.fromLTWH(startX + 57, size.height - 54, 5, 7), windowPaint);
    canvas.drawRect(
        Rect.fromLTWH(startX + 67, size.height - 54, 5, 7), windowPaint);

    // Hoja estilizada a la extrema derecha
    final leafPath = Path();
    leafPath.moveTo(size.width - 12, size.height);
    leafPath.quadraticBezierTo(
      size.width + 12,
      size.height - 45,
      size.width - 22,
      size.height - 55,
    );
    leafPath.quadraticBezierTo(
      size.width - 4,
      size.height - 30,
      size.width - 4,
      size.height,
    );
    canvas.drawPath(leafPath, leafPaint);
  }

  @override
  bool shouldRepaint(_BottomSkylinePainter old) => false;
}
