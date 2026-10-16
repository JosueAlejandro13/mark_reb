import 'package:flutter/material.dart';
import 'package:mark_v3/services/ConnectionProfile_/ProfileCon_service.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Autor: Josue Hernandez
class ChangePasswordPage extends StatefulWidget {
  final String userId;
  final String usuario;
  final String idMainAccount;

  const ChangePasswordPage({
    super.key,
    required this.userId,
    required this.usuario,
    required this.idMainAccount,
  });

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _passwordStrengthMessage = '';
  Color _passwordStrengthColor = const Color(0xFF94A3B8);
  bool _passwordsMatch = false;
  double _passwordStrength = 0.0;
  bool _isSaving = false;

  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(() {
      _checkPasswordStrength(_newPasswordController.text);
      _checkPasswordsMatch();
    });

    _confirmPasswordController.addListener(() {
      _checkPasswordsMatch();
    });
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Comprueba la fuerza de la nueva contraseña
  void _checkPasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0.0;
        _passwordStrengthMessage = '';
        _passwordStrengthColor = const Color(0xFF94A3B8);
      });
      return;
    }

    double strength = 0;
    if (password.length >= 6) strength += 0.25;
    if (password.length >= 8) strength += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.15;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.15;

    setState(() {
      _passwordStrength = (strength >= 1.0) ? 1.0 : strength.clamp(0.0, 1.0);

      if (_passwordStrength >= 0.75) {
        _passwordStrengthMessage = 'Contraseña Segura';
        _passwordStrengthColor = const Color(0xFF10B981);
      } else if (_passwordStrength >= 0.4) {
        _passwordStrengthMessage = 'Contraseña Moderada';
        _passwordStrengthColor = const Color(0xFFF59E0B);
      } else {
        _passwordStrengthMessage = 'Contraseña Débil';
        _passwordStrengthColor = const Color(0xFFEF4444);
      }
    });
  }

  // Verifica si las contraseñas coinciden
  void _checkPasswordsMatch() {
    setState(() {
      _passwordsMatch = _confirmPasswordController.text.isNotEmpty &&
          _confirmPasswordController.text == _newPasswordController.text;
    });
  }

  // Función para cambiar la contraseña usando ProfileConService
  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    bool isSuccess = false;
    String? errorMessage;

    try {
      final result = await ProfileconService().updatePassword(
        usuario: widget.usuario,
        userId: widget.userId,
        idMainAccount: widget.idMainAccount,
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (result) {
        isSuccess = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isBiometricEnabled', false);
        await prefs.setString('password', _newPasswordController.text);
        await prefs.setBool('isPasswordSet', true);
      } else {
        errorMessage = "La contraseña actual es incorrecta.";
      }
    } catch (e) {
      errorMessage = "Error al guardar cambios. Intenta nuevamente más tarde.";
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }

    if (!mounted) return;

    if (isSuccess) {
      SnackbarTop.showSuccess(
        context,
        "Contraseña actualizada con éxito.",
      );
      Navigator.pop(context);
    } else {
      SnackbarTop.showError(
        context,
        errorMessage ?? "Error inesperado al actualizar la contraseña.",
      );
    }
  }

  // Validación previa al envío
  void _handleSubmit() {
    FocusScope.of(context).unfocus();

    if (_isSaving) return;

    if (_currentPasswordController.text.trim().isEmpty) {
      SnackbarTop.showInfo(
        context,
        "Ingresa tu contraseña actual.",
      );
      return;
    }

    if (_newPasswordController.text.trim().length < 8 ||
        _passwordStrength < 0.4) {
      SnackbarTop.showInfo(
        context,
        "La contraseña es débil. Asegúrate de incluir al menos 8 caracteres y variedad de caracteres.",
      );
      return;
    }

    if (!_passwordsMatch) {
      SnackbarTop.showError(
        context,
        "Las contraseñas no coinciden.",
      );
      return;
    }

    _changePassword();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isSmallScreen = mediaQuery.size.width < 360;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        // Fondo gris suave estilo iOS System Grouped Background
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 14.0 : 18.0,
                vertical: 10.0,
              ),
              child: AbsorbPointer(
                absorbing: _isSaving,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 1. Encabezado Apple ─────────────────────────────
                      _buildAnimatedItem(_buildAppleHeader(context), 0),
                      const SizedBox(height: 16),

                      // ── 2. Sección: Contraseña Actual ───────────────────
                      _buildAnimatedItem(
                        _buildSectionTitle('CONTRASEÑA VIGENTE'),
                        1,
                      ),
                      _buildAnimatedItem(
                        _buildAppleGroupContainer(
                          children: [
                            _buildPasswordField(
                              controller: _currentPasswordController,
                              label: 'Contraseña Actual',
                              hintText: 'Ingresa tu clave actual',
                              icon: Icons.key_rounded,
                              isVisible: _isCurrentPasswordVisible,
                              enabled: !_isSaving,
                              onToggleVisibility: () {
                                setState(() {
                                  _isCurrentPasswordVisible =
                                      !_isCurrentPasswordVisible;
                                });
                              },
                            ),
                          ],
                        ),
                        2,
                      ),
                      const SizedBox(height: 18),

                      // ── 3. Sección: Nueva Contraseña ────────────────────
                      _buildAnimatedItem(
                        _buildSectionTitle('NUEVA CONTRASEÑA'),
                        3,
                      ),
                      _buildAnimatedItem(
                        _buildAppleGroupContainer(
                          children: [
                            // Campo Nueva Contraseña
                            _buildPasswordField(
                              controller: _newPasswordController,
                              label: 'Nueva Contraseña',
                              hintText: 'Mínimo 8 caracteres',
                              icon: Icons.lock_reset_rounded,
                              isVisible: _isNewPasswordVisible,
                              enabled: !_isSaving,
                              onToggleVisibility: () {
                                setState(() {
                                  _isNewPasswordVisible =
                                      !_isNewPasswordVisible;
                                });
                              },
                            ),

                            // Medidor de fuerza estilo Apple
                            if (_newPasswordController.text.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildStrengthMeter(),
                            ],

                            const SizedBox(height: 14),

                            // Campo Confirmar Nueva Contraseña
                            _buildPasswordField(
                              controller: _confirmPasswordController,
                              label: 'Confirmar Nueva Contraseña',
                              hintText: 'Repite tu nueva contraseña',
                              icon: Icons.verified_user_outlined,
                              isVisible: _isConfirmPasswordVisible,
                              enabled: !_isSaving,
                              onToggleVisibility: () {
                                setState(() {
                                  _isConfirmPasswordVisible =
                                      !_isConfirmPasswordVisible;
                                });
                              },
                            ),

                            // Indicador de Coincidencia estilo Apple
                            if (_confirmPasswordController.text.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _buildMatchIndicator(),
                            ],

                            const SizedBox(height: 14),

                            // Guía de requisitos con chips estilo Apple
                            _buildRequirementsList(),
                          ],
                        ),
                        4,
                      ),
                      const SizedBox(height: 24),

                      // ── 4. Botón de Acción con Loading integrado ────────
                      _buildAnimatedItem(
                        LoadingActionButton(
                          text: 'Actualizar Contraseña',
                          isLoading: _isSaving,
                          icon: Icons.check_circle_rounded,
                          height: 50,
                          borderRadius: 16,
                          onPressed: _handleSubmit,
                        ),
                        5,
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── ENCABEZADO APPLE (HEADER) ───────────────────────────────────────────────
  Widget _buildAppleHeader(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isSaving ? null : () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF0F172A),
                  size: 15,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cambiar Contraseña',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Actualiza tu clave de acceso a la cuenta',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }



  // ── TÍTULO DE SECCIÓN INSET GROUPED ─────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ── CONTENEDOR INSET GROUPED ESTILO APPLE ───────────────────────────────────
  Widget _buildAppleGroupContainer({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // ── CAMPO DE CONTRASEÑA ESTILO APPLE ───────────────────────────────────────
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? const Color(0xFF475569)
                      : const Color(0xFF94A3B8),
                  letterSpacing: -0.1,
                ),
              ),
              if (!enabled)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 11,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Bloqueado',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          enabled: enabled,
          readOnly: !enabled,
          obscureText: !isVisible,
          cursorColor: const Color(0xFF0284C7),
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: enabled ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText,
            hintStyle: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              icon,
              size: 17,
              color: enabled
                  ? const Color(0xFF0284C7)
                  : const Color(0xFF94A3B8),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF94A3B8),
                size: 19,
              ),
              onPressed: enabled ? onToggleVisibility : null,
              splashRadius: 18,
            ),
            filled: true,
            fillColor:
                enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.04)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF0284C7), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
          ),
        ),
      ],
    );
  }

  // ── MEDIDOR DE FUERZA DE CONTRASEÑA ─────────────────────────────────────────
  Widget _buildStrengthMeter() {
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
              _passwordStrengthMessage,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _passwordStrengthColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _passwordStrength,
            backgroundColor: const Color(0xFFF1F5F9),
            color: _passwordStrengthColor,
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  // ── INDICADOR DE COINCIDENCIA DE CONTRASEÑAS ────────────────────────────────
  Widget _buildMatchIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _passwordsMatch
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: _passwordsMatch
              ? const Color(0xFF86EFAC)
              : const Color(0xFFFCA5A5),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _passwordsMatch
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            size: 14,
            color: _passwordsMatch
                ? const Color(0xFF16A34A)
                : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 6),
          Text(
            _passwordsMatch
                ? 'Las contraseñas coinciden'
                : 'Las contraseñas no coinciden',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _passwordsMatch
                  ? const Color(0xFF15803D)
                  : const Color(0xFFB91C1C),
            ),
          ),
        ],
      ),
    );
  }

  // ── LISTA DE REQUISITOS ESTILO APPLE CHIPS ──────────────────────────────────
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
            size: 11,
            color: isMet ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isMet ? FontWeight.w700 : FontWeight.w500,
              color: isMet ? const Color(0xFF065F46) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ── ANIMACIÓN SUAVE STAGGERED ESTILO APPLE ──────────────────────────────────
  Widget _buildAnimatedItem(Widget child, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 260 + (index * 35)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (1.0 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
