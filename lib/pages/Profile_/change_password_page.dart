import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/services/ConnectionProfile_/ProfileCon_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

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
  Color _passwordStrengthColor = Colors.grey;
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
        _passwordStrengthColor = Colors.grey;
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

  // Función para cambiar la contraseña
  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/loading.json',
                  height: 44,
                  width: 44,
                  repeat: true,
                ),
                const SizedBox(width: 14),
                const Text(
                  "Guardando cambios...",
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    bool isSuccess = false;
    String? errorMessage;

    try {
      final result = await ProfileconService().updatePassword(
        usuario: widget.usuario,
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
        errorMessage = "Error. La contraseña actual es incorrecta.";
      }
    } catch (e) {
      errorMessage = "Error al guardar cambios. Intente nuevamente más tarde.";
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Cierra el modal de carga
        setState(() {
          _isSaving = false;
        });
      }
    }

    if (!mounted) return;

    if (isSuccess) {
      showTopSnackBar(
        Overlay.of(context),
        Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Contraseña actualizada con éxito.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      Navigator.pop(context);
    } else {
      showTopSnackBar(
        Overlay.of(context),
        Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    errorMessage ?? "Error inesperado al guardar.",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // Validación y diálogo de confirmación
  void _handleSubmit() {
    if (_currentPasswordController.text.trim().isEmpty) {
      showTopSnackBar(
        Overlay.of(context),
        Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0886B5),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "La contraseña actual no puede estar vacía.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    if (_newPasswordController.text.trim().length < 8 ||
        _passwordStrength < 0.4) {
      showTopSnackBar(
        Overlay.of(context),
        Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "La contraseña es débil. Asegúrate de incluir al menos 8 caracteres.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    if (!_passwordsMatch) {
      showTopSnackBar(
        Overlay.of(context),
        Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Las contraseñas no coinciden.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    _showConfirmChangeDialog();
  }

  Future<void> _showConfirmChangeDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock_reset_rounded,
                    color: Color(0xFF0886B5),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Confirmar Cambio',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '¿Estás seguro de que deseas cambiar tu contraseña de acceso?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0886B5),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text(
                        'Confirmar',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true) {
      _changePassword();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 250, 250, 250),
            Color.fromARGB(255, 205, 240, 255),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header superior
                    _buildHeader(context),
                    const SizedBox(height: 12),

                    // CARD 1: CONTRASEÑA ACTUAL
                    _buildSectionCard(
                      icon: Icons.lock_outline_rounded,
                      iconColor: const Color(0xFF0886B5),
                      iconBg: const Color(0xFFE0F2FE),
                      title: 'Contraseña Actual',
                      subtitle: 'Ingresa tu clave de acceso vigente',
                      children: [
                        _buildPasswordField(
                          controller: _currentPasswordController,
                          label: 'Contraseña Actual',
                          icon: Icons.key_rounded,
                          isVisible: _isCurrentPasswordVisible,
                          onToggleVisibility: () {
                            setState(() {
                              _isCurrentPasswordVisible =
                                  !_isCurrentPasswordVisible;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),

                    // CARD 2: NUEVA CONTRASEÑA
                    _buildSectionCard(
                      icon: Icons.shield_outlined,
                      iconColor: const Color(0xFF7C3AED),
                      iconBg: const Color(0xFFF3E8FF),
                      title: 'Nueva Contraseña',
                      subtitle: 'Define y confirma tu nueva clave de seguridad',
                      children: [
                        // Guía rápida de requisitos
                        _buildRequirementsBadge(),
                        const SizedBox(height: 12),

                        // Campo nueva contraseña
                        _buildPasswordField(
                          controller: _newPasswordController,
                          label: 'Nueva Contraseña',
                          icon: Icons.lock_reset_rounded,
                          isVisible: _isNewPasswordVisible,
                          onToggleVisibility: () {
                            setState(() {
                              _isNewPasswordVisible = !_isNewPasswordVisible;
                            });
                          },
                        ),
                        const SizedBox(height: 8),

                        // Indicador de fuerza de contraseña
                        if (_newPasswordController.text.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _passwordStrength,
                              backgroundColor: Colors.grey[200],
                              color: _passwordStrengthColor,
                              minHeight: 5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Nivel de seguridad:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
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
                          const SizedBox(height: 10),
                        ],

                        // Campo confirmar nueva contraseña
                        _buildPasswordField(
                          controller: _confirmPasswordController,
                          label: 'Confirmar Nueva Contraseña',
                          icon: Icons.verified_user_outlined,
                          isVisible: _isConfirmPasswordVisible,
                          onToggleVisibility: () {
                            setState(() {
                              _isConfirmPasswordVisible =
                                  !_isConfirmPasswordVisible;
                            });
                          },
                        ),

                        // Indicador de coincidencia
                        if (_confirmPasswordController.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _passwordsMatch
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _passwordsMatch
                                      ? Icons.check_circle_rounded
                                      : Icons.error_rounded,
                                  size: 13,
                                  color: _passwordsMatch
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 5),
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
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Botón para actualizar contraseña
                    _buildSaveButton(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- HEADER SUPERIOR ---
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.04)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
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
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cambiar Contraseña',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Actualiza tu clave de acceso a la plataforma',
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

  // --- CONTENEDOR DE SECCIÓN (CARD) ---
  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 17),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // --- BADGE DE REQUISITOS ---
  Widget _buildRequirementsBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: Color(0xFF0886B5),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Debe tener al menos 8 caracteres, incluir una letra mayúscula, un número y un carácter especial.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CAMPO DE CONTRASEÑA ESTILIZADO ---
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          icon,
          size: 17,
          color: const Color(0xFF0886B5),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: Colors.grey[500],
            size: 18,
          ),
          onPressed: onToggleVisibility,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0886B5), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
      ),
    );
  }

  // --- BOTÓN ACTUALIZAR CONTRASEÑA ---
  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 46,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0886B5),
            Color(0xFF0284C7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0886B5).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _isSaving ? null : _handleSubmit,
          child: Center(
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_reset_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Actualizar Contraseña',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
