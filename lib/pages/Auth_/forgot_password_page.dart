import 'package:flutter/material.dart';
import 'package:mark_v3/pages/Auth_/verify_code_page.dart';
import 'package:mark_v3/services/ConnectionAuth_/AuthCon_service.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';

// Autor: Josue Hernandez
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthConService _authService = AuthConService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    final emailText = _emailController.text.trim();

    setState(() => _isLoading = true);

    final result = await _authService.sendRecoveryCode(emailText);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      SnackbarTop.showSuccess(
        context,
        result['message'] ?? 'Código enviado exitosamente a tu correo.',
        title: 'Código Enviado',
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyCodePage(
            email: emailText,
          ),
        ),
      );
    } else {
      SnackbarTop.showError(
        context,
        result['message'] ?? 'Error al enviar código de recuperación.',
        title: 'Error de Envío',
      );
    }
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

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor: const Color(0xFFE8F4FD),
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // ── Cabecera superior con gradiente pastel y botón atrás ─────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: screenHeight * 0.20,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFE0F2FE),
                      Color(0xFFF0F9FF),
                      Colors.white,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, left: 18),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap:
                              _isLoading ? null : () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Color(0xFF0F172A),
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Tarjeta blanca inferior con curva asimétrica ─────────────
            Positioned(
              top: screenHeight * 0.12,
              left: 0,
              right: 0,
              bottom: 0,
              child: CustomPaint(
                painter: _WaveShadowPainter(),
                child: ClipPath(
                  clipper: _WaveClipper(),
                  child: Container(
                    color: Colors.white,
                    child: Stack(
                      children: [
                        // ── Decoración inferior de silueta urbana pastel ─
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 80,
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _BottomSkylinePainter(),
                            ),
                          ),
                        ),

                        // ── Contenido del formulario ─────────────────────
                        GestureDetector(
                          onTap: () => FocusScope.of(context).unfocus(),
                          behavior: HitTestBehavior.translucent,
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.only(
                              left: screenWidth * 0.075,
                              right: screenWidth * 0.075,
                              top: 36,
                              bottom: mediaQuery.viewInsets.bottom + 28,
                            ),
                            child: Form(
                              key: _formKey,
                              child: AbsorbPointer(
                                absorbing: _isLoading,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ── Badge de recuperación estilo Apple ───
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFFBAE6FD),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.shield_outlined,
                                            size: 14,
                                            color: Color(0xFF0284C7),
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Recuperación',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0284C7),
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    // ── Título principal ────────────────────
                                    const Text(
                                      '¿Olvidaste tu contraseña?',
                                      style: TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: -0.5,
                                        height: 1.15,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Ingresa tu correo para recibir las instrucciones de recuperación.',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),

                                    const SizedBox(height: 22),

                                    // ── Divisor decorativo ──────────────────
                                    const Row(
                                      children: [
                                        Expanded(
                                          child: Divider(
                                            color: Color(0xFFE2E8F0),
                                            thickness: 1,
                                          ),
                                        ),
                                        Expanded(
                                          child: Divider(
                                            color: Color(0xFFE2E8F0),
                                            thickness: 1,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 20),

                                    // ── Etiqueta Correo ─────────────────────
                                    const Text(
                                      'Correo electrónico',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // ── Campo Correo estilo Apple ───────────
                                    TextFormField(
                                      controller: _emailController,
                                      enabled: !_isLoading,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Por favor ingresa tu correo electrónico';
                                        }
                                        final emailRegex = RegExp(
                                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                        if (!emailRegex.hasMatch(val.trim())) {
                                          return 'Ingresa un formato de correo válido';
                                        }
                                        return null;
                                      },
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'ejemplo@correo.com',
                                        hintStyle: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.normal,
                                        ),
                                        filled: true,
                                        fillColor: _isLoading
                                            ? const Color(0xFFF1F5F9)
                                            : const Color(0xFFF8FAFC),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 15,
                                        ),
                                        isDense: true,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFE2E8F0),
                                              width: 1.2),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFE2E8F0),
                                              width: 1.2),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0284C7),
                                              width: 1.5),
                                        ),
                                        disabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFE2E8F0),
                                              width: 1.0),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFEF4444),
                                              width: 1.2),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFEF4444),
                                              width: 1.8),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 26),

                                    // ── Botón Enviar Instrucciones estilo Apple ──
                                    LoadingActionButton(
                                      text: 'Enviar Instrucciones',
                                      isLoading: _isLoading,
                                      icon: Icons.send_rounded,
                                      height: 52,
                                      borderRadius: 14,
                                      fontSize: 15,
                                      onPressed: _handleSubmit,
                                    ),

                                    const SizedBox(height: 14),
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
              ),
            ),
          ],
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
