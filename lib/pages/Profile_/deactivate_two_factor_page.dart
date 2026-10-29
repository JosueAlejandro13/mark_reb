import 'package:flutter/material.dart';
import 'package:mark_v3/pages/Profile_/two_factor_verify_code_page.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

/// Pantalla completa para desactivar la Verificación en 2 Pasos (2FA)
/// Reemplaza el anterior modal por una experiencia de pantalla completa
class DeactivateTwoFactorPage extends StatefulWidget {
  final String usuario;
  final String? correo;

  const DeactivateTwoFactorPage({
    super.key,
    required this.usuario,
    this.correo,
  });

  @override
  State<DeactivateTwoFactorPage> createState() => _DeactivateTwoFactorPageState();
}

class _DeactivateTwoFactorPageState extends State<DeactivateTwoFactorPage> {
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _fieldBg = Color(0xFFF8FAFC);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _red = Color(0xFFEF4444);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _passCtrl;
  bool _passObscured = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _passCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    if (_formKey.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final res = await MarkApiClient.instance.dosPasosApagar(
        password: _passCtrl.text,
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
            email: widget.correo,
            isActivation: false,
            title: 'Autorizar desactivación',
            subtitle:
                'Escribe el código de 6 dígitos enviado a tu correo registrado para confirmar la desactivación:',
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
          'No se pudo desactivar: $err',
          title: 'Error de Desactivación',
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
                                      Color(0xFFFEE2E2),
                                      Color(0xFFFECACA),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(color: Colors.white, width: 3.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _red.withOpacity(0.20),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.shield_outlined,
                                    color: _red,
                                    size: 34,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Título y descripción
                              const Text(
                                'Desactivar Verificación en 2 Pasos',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFDC2626),
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Por seguridad, confirma tu contraseña actual. Te mandaremos un código de autorización a tu correo para autorizar la desactivación.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: _textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Campo: Contraseña de la cuenta
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
                              const SizedBox(height: 18),

                              // Banner de advertencia de seguridad
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFFDE68A)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Color(0xFFD97706),
                                      size: 18,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Al desactivar la verificación en dos pasos, tu cuenta solo estará protegida por tu contraseña y será más vulnerable en accesos nuevos.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF92400E),
                                          height: 1.35,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Botón Continuar con Desactivación
                              LoadingActionButton(
                                text: 'Continuar con Desactivación',
                                isLoading: _isLoading,
                                icon: Icons.power_settings_new_rounded,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                ),
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
                'Desactivar Verificación',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Confirmación de seguridad requerida',
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
          cursorColor: _red,
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
              color: _red,
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
              borderSide: BorderSide(color: _red, width: 1.5),
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
