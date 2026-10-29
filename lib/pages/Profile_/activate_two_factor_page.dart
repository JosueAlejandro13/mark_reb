import 'package:flutter/material.dart';
import 'package:mark_v3/pages/Profile_/two_factor_verify_code_page.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

/// Pantalla completa para activar la Verificación en 2 Pasos (2FA)
/// Reemplaza el anterior modal por una experiencia de pantalla completa
class ActivateTwoFactorPage extends StatefulWidget {
  final String usuario;
  final String? currentEmail;

  const ActivateTwoFactorPage({
    super.key,
    required this.usuario,
    this.currentEmail,
  });

  @override
  State<ActivateTwoFactorPage> createState() => _ActivateTwoFactorPageState();
}

class _ActivateTwoFactorPageState extends State<ActivateTwoFactorPage> {
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _primary = Color(0xFF0284C7);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _fieldBg = Color(0xFFF8FAFC);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _green = Color(0xFF10B981);
  static const Color _red = Color(0xFFEF4444);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _passCtrl;
  late final TextEditingController _emailCtrl;
  bool _passObscured = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _passCtrl = TextEditingController();
    _emailCtrl = TextEditingController(text: widget.currentEmail ?? '');
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    if (_formKey.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final email = _emailCtrl.text.trim();
      final res = await MarkApiClient.instance.dosPasosActivar(
        password: _passCtrl.text,
        correo: email,
      );

      final desafio = (res['desafio'] ?? '').toString();
      if (desafio.isEmpty) {
        throw Exception(res['error'] ?? 'No se recibió desafío del servidor.');
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Navegar a la pantalla completa de verificación de código de 6 dígitos
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => TwoFactorVerifyCodePage(
            desafio: desafio,
            email: email,
            isActivation: true,
            title: 'Confirma el código enviado',
            subtitle:
                'Enviamos un código de 6 dígitos a $email. Escríbelo para completar la activación:',
          ),
        ),
      );

      if (verified == true && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final err = e.toString().replaceAll('Exception: ', '');
        SnackbarTop.showError(
          context,
          'No se pudo activar: $err',
          title: 'Error de Activación',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 360;

    return Scaffold(
      backgroundColor: _bg,
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
              absorbing: _isLoading,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Encabezado institucional de Mark
                    _buildHeader(context),
                    const SizedBox(height: 16),

                    // 2. Tarjeta principal del formulario
                    _buildAppleGroupContainer(
                      children: [
                        Center(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Emblema Hero
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFE0F2FE),
                                      Color(0xFFBAE6FD),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(color: Colors.white, width: 3.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _primary.withOpacity(0.20),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.lock_person_rounded,
                                    color: _primary,
                                    size: 34,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Título y descripción
                              const Text(
                                'Activar Verificación en 2 Pasos',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _textPrimary,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Ingresa tu contraseña actual y el correo donde recibirás los códigos de acceso de 6 dígitos al iniciar sesión.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: _textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Campo 1: Contraseña de la cuenta
                              _buildMarkInput(
                                controller: _passCtrl,
                                label: 'CONTRASEÑA DE LA CUENTA',
                                hintText: 'Ingresa tu contraseña actual',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _passObscured,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _passObscured
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: _textMuted,
                                    size: 19,
                                  ),
                                  onPressed: () =>
                                      setState(() => _passObscured = !_passObscured),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Ingresa tu contraseña actual'
                                        : null,
                              ),
                              const SizedBox(height: 16),

                              // Campo 2: Correo electrónico para códigos
                              _buildMarkInput(
                                controller: _emailCtrl,
                                label: 'CORREO ELECTRÓNICO PARA CÓDIGOS',
                                hintText: 'ejemplo@empresa.com',
                                icon: Icons.alternate_email_rounded,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Ingresa un correo electrónico';
                                  }
                                  if (!v.contains('@') || !v.contains('.')) {
                                    return 'Correo electrónico no válido';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),

                              // Banner de protección y cifrado
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFBBF7D0)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.verified_user_rounded,
                                      color: _green,
                                      size: 18,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Tus credenciales están protegidas con cifrado. El correo se utilizará únicamente para enviarte códigos de seguridad.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF166534),
                                          height: 1.35,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Botón Continuar
                              LoadingActionButton(
                                text: 'Continuar',
                                isLoading: _isLoading,
                                icon: Icons.arrow_forward_rounded,
                                height: 50,
                                borderRadius: 16,
                                onPressed: _handleContinue,
                              ),
                              const SizedBox(height: 8),

                              // Botón Cancelar
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text(
                                  'Cancelar',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: _textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isLoading ? null : () => Navigator.pop(context, false),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: _textPrimary.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _textPrimary,
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
                'Activar Verificación',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Protección adicional de seguridad para tu cuenta',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: _textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppleGroupContainer({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: _textPrimary.withOpacity(0.03),
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

  Widget _buildMarkInput({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 5),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
              letterSpacing: -0.1,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          cursorColor: _primary,
          validator: validator,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText,
            hintStyle: const TextStyle(
              fontSize: 12.5,
              color: _textMuted,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              icon,
              size: 17,
              color: _primary,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: _fieldBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: _primary, width: 1.5),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: _red, width: 1.2),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: _red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
