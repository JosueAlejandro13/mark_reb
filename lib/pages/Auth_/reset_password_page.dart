import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/providers/Auth_/reset_password_provider.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';

// Autor: Josue Hernandez
class ResetPasswordPage extends ConsumerStatefulWidget {
  final String? email;
  final String? code;

  const ResetPasswordPage({
    super.key,
    this.email,
    this.code,
  });

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _newPasswordController.addListener(() {
      ref
          .read(resetPasswordProvider.notifier)
          .checkPasswordStrength(_newPasswordController.text);
      ref.read(resetPasswordProvider.notifier).checkPasswordsMatch(
            _newPasswordController.text,
            _confirmPasswordController.text,
          );
    });

    _confirmPasswordController.addListener(() {
      ref.read(resetPasswordProvider.notifier).checkPasswordsMatch(
            _newPasswordController.text,
            _confirmPasswordController.text,
          );
    });
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- SUBMIT CON RIVERPOD Y DIÁLOGO LOTTIE/APPLE ---
  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();

    final state = ref.read(resetPasswordProvider);
    if (state.isLoading) return;

    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (newPass.isEmpty) {
      SnackbarTop.showInfo(
        context,
        "Por favor ingresa tu nueva contraseña.",
        title: "Campo Requerido",
      );
      return;
    }

    if (newPass.length < 8 || state.passwordStrength < 0.4) {
      SnackbarTop.showInfo(
        context,
        "La contraseña es débil. Asegúrate de incluir al menos 8 caracteres y variedad de caracteres.",
        title: "Contraseña Débil",
      );
      return;
    }

    if (confirmPass.isEmpty) {
      SnackbarTop.showInfo(
        context,
        "Por favor confirma tu nueva contraseña.",
        title: "Campo Requerido",
      );
      return;
    }

    if (newPass != confirmPass) {
      SnackbarTop.showError(
        context,
        "Las contraseñas no coinciden. Verifica los datos.",
        title: "Error de Coincidencia",
      );
      return;
    }

    final res =
        await ref.read(resetPasswordProvider.notifier).submitResetPassword(
              email: widget.email ?? '',
              code: widget.code ?? '',
              newPassword: newPass,
            );

    if (!mounted) return;

    if (res['success'] == true) {
      _showSuccessDialog();
    } else {
      SnackbarTop.showError(
        context,
        res['message'] ?? 'Error al actualizar contraseña.',
        title: "Error de Actualización",
      );
    }
  }

  // --- DIÁLOGO DE ÉXITO EJECUTIVO ESTILO APPLE ---
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 38,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '¡Contraseña Actualizada!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tu contraseña ha sido restablecida con éxito. Ya puedes iniciar sesión con tus nuevas credenciales.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0284C7),
                      Color(0xFF0369A1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withOpacity(0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).popUntil(
                      (route) =>
                          route.isFirst || route.settings.name == '/login',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Iniciar Sesión',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      letterSpacing: 0.2,
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

  // --- GUÍA DE REQUISITOS CON CHIPS ESTILO APPLE ---
  Widget _buildRequirementsList() {
    final pwd = _newPasswordController.text;
    final hasLength = pwd.length >= 8;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(pwd);
    final hasNumber = RegExp(r'[0-9]').hasMatch(pwd);
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pwd);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Requisitos recomendados:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildRequirementChip('8+ Caracteres', hasLength),
              _buildRequirementChip('Mayúscula', hasUpper),
              _buildRequirementChip('Número', hasNumber),
              _buildRequirementChip('Símbolo (!@#)', hasSpecial),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementChip(String label, bool isMet) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMet ? const Color(0xFFECFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMet ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
          width: 0.9,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 13,
            color: isMet ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isMet ? FontWeight.w700 : FontWeight.w500,
              color: isMet ? const Color(0xFF065F46) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // --- MEDIDOR DE FUERZA ESTILO APPLE ---
  Widget _buildStrengthMeter(ResetPasswordState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Seguridad de la clave',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              state.passwordStrengthMessage,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: state.passwordStrengthColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: state.passwordStrength,
            backgroundColor: const Color(0xFFF1F5F9),
            color: state.passwordStrengthColor,
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  // --- INDICADOR DE COINCIDENCIA ESTILO APPLE ---
  Widget _buildMatchIndicator(bool matches) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: matches ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: matches ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            matches ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 14,
            color: matches ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 6),
          Text(
            matches
                ? 'Las contraseñas coinciden'
                : 'Las contraseñas no coinciden',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: matches ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
            ),
          ),
        ],
      ),
    );
  }

  // --- CAMPO DE CONTRASEÑA ESTILO APPLE ---
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: !isVisible,
          enabled: enabled,
          readOnly: !enabled,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: 'Ingresa tu contraseña',
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13.5,
              fontWeight: FontWeight.normal,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF94A3B8),
                size: 20,
              ),
              onPressed: enabled ? onToggleVisibility : null,
            ),
            filled: true,
            fillColor:
                enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFF0284C7), width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.2),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resetPasswordProvider);
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
                          onTap: state.isLoading
                              ? null
                              : () => Navigator.pop(context),
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
                                  color: const Color(0xFF0F172A)
                                      .withOpacity(0.04),
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
                                absorbing: state.isLoading,
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
                                            Icons.lock_reset_rounded,
                                            size: 14,
                                            color: Color(0xFF0284C7),
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Nueva Contraseña',
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
                                      'Restablecer Contraseña',
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
                                      'Crea una contraseña segura con al menos 8 caracteres.',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),

                                    const SizedBox(height: 20),

                                    // ── Divisor decorativo ──────────────────
                                    const Row(
                                      children: [
                                        Expanded(
                                          child: Divider(
                                            color: Color(0xFFE2E8F0),
                                            thickness: 1,
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 12),
                                          child: Text(
                                            'Seguridad de tu cuenta',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF94A3B8),
                                              fontWeight: FontWeight.w500,
                                            ),
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

                                    const SizedBox(height: 18),

                                    // ── Guía de requisitos interactiva Apple ─
                                    _buildRequirementsList(),

                                    const SizedBox(height: 18),

                                    // ── Campo Nueva Contraseña ──────────────
                                    _buildPasswordField(
                                      controller: _newPasswordController,
                                      label: 'Nueva Contraseña',
                                      isVisible: state.isNewPasswordVisible,
                                      enabled: !state.isLoading,
                                      onToggleVisibility: () {
                                        ref
                                            .read(
                                                resetPasswordProvider.notifier)
                                            .toggleNewPasswordVisibility();
                                      },
                                    ),

                                    // ── Indicador dinámico de fuerza Apple ──
                                    if (_newPasswordController
                                        .text.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      _buildStrengthMeter(state),
                                    ],

                                    const SizedBox(height: 16),

                                    // ── Campo Confirmar Nueva Contraseña ────
                                    _buildPasswordField(
                                      controller: _confirmPasswordController,
                                      label: 'Confirmar Nueva Contraseña',
                                      isVisible: state.isConfirmPasswordVisible,
                                      enabled: !state.isLoading,
                                      onToggleVisibility: () {
                                        ref
                                            .read(
                                                resetPasswordProvider.notifier)
                                            .toggleConfirmPasswordVisibility();
                                      },
                                    ),

                                    // ── Indicador en vivo de coincidencia Apple ─
                                    if (_confirmPasswordController
                                        .text.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      _buildMatchIndicator(
                                          state.passwordsMatch),
                                    ],

                                    const SizedBox(height: 26),

                                    // ── Botón Restablecer estilo Apple ──────
                                    LoadingActionButton(
                                      text: 'Restablecer Contraseña',
                                      isLoading: state.isLoading,
                                      icon: Icons.check_circle_outline_rounded,
                                      height: 52,
                                      borderRadius: 14,
                                      fontSize: 15,
                                      onPressed: _handleSubmit,
                                    ),

                                    const SizedBox(height: 16),
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

// ── Clipper: curva asimétrica elegante ───────────────────────────────────────
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

    final startX = size.width * 0.62;

    final b1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(startX, size.height - 52, 24, 42),
      const Radius.circular(3),
    );
    canvas.drawRRect(b1, buildingPaint);
    canvas.drawRect(
        Rect.fromLTWH(startX + 4, size.height - 44, 5, 7), windowPaint);
    canvas.drawRect(
        Rect.fromLTWH(startX + 13, size.height - 44, 5, 7), windowPaint);

    final b2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(startX + 28, size.height - 40, 20, 30),
      const Radius.circular(3),
    );
    canvas.drawRRect(b2, buildingPaint);
    canvas.drawRect(
        Rect.fromLTWH(startX + 34, size.height - 34, 4, 6), windowPaint);

    final b3 = RRect.fromRectAndRadius(
      Rect.fromLTWH(startX + 52, size.height - 62, 26, 52),
      const Radius.circular(3),
    );
    canvas.drawRRect(b3, buildingPaint);
    canvas.drawRect(
        Rect.fromLTWH(startX + 57, size.height - 54, 5, 7), windowPaint);
    canvas.drawRect(
        Rect.fromLTWH(startX + 67, size.height - 54, 5, 7), windowPaint);

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
