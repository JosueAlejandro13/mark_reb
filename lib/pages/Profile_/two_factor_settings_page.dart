import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mark_v3/pages/Profile_/activate_two_factor_page.dart';
import 'package:mark_v3/pages/Profile_/deactivate_two_factor_page.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';

export 'package:mark_v3/pages/Profile_/activate_two_factor_page.dart';
export 'package:mark_v3/pages/Profile_/deactivate_two_factor_page.dart';
export 'package:mark_v3/pages/Profile_/two_factor_verify_code_page.dart';

/// Configuración de Verificación en 2 Pasos (2FA) integrada con el diseño de Mark
/// (Consistente con EditProfilePage y ChangePasswordPage: Inset Grouped, Sky/Cyan 600,
/// encabezado ejecutivo y modales amplios).
class TwoFactorSettingsPage extends StatefulWidget {
  final String usuario;

  const TwoFactorSettingsPage({
    super.key,
    required this.usuario,
  });

  @override
  State<TwoFactorSettingsPage> createState() => _TwoFactorSettingsPageState();
}

class _TwoFactorSettingsPageState extends State<TwoFactorSettingsPage> {
  // Paleta oficial de Mark App (EditProfilePage & ChangePasswordPage)
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _primary = Color(0xFF0284C7);
  static const Color _primaryDark = Color(0xFF0369A1);
  static const Color _cardBg = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _fieldBg = Color(0xFFF8FAFC);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _green = Color(0xFF10B981);
  static const Color _red = Color(0xFFEF4444);

  bool _isLoading = true;
  final bool _isActionLoading = false;
  bool _activo = false;
  String _correo = '';
  bool _soloSms = false;
  bool _exigido = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await MarkApiClient.instance.getDosPasosEstado();
      if (mounted) {
        setState(() {
          _activo = res['activo'] == true;
          _correo = (res['correo'] ?? '').toString();
          _soloSms = res['soloSms'] == true;
          _exigido = res['exigido'] == true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // Animación de entrada escalonada idéntica a ChangePasswordPage
  Widget _buildAnimatedItem(Widget child, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 250 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, animChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: animChild,
          ),
        );
      },
      child: child,
    );
  }

  // =========================================================================
  // FLUJO 1: ACTIVAR 2 PASOS (PANTALLA COMPLETA)
  // =========================================================================
  Future<void> _startActivation() async {
    HapticFeedback.lightImpact();
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ActivateTwoFactorPage(
          usuario: widget.usuario,
          currentEmail: _correo,
        ),
      ),
    );

    if (verified == true && mounted) {
      _loadStatus();
    }
  }

  // =========================================================================
  // FLUJO 2: DESACTIVAR 2 PASOS (PANTALLA COMPLETA)
  // =========================================================================
  Future<void> _startDeactivation() async {
    HapticFeedback.lightImpact();
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DeactivateTwoFactorPage(
          usuario: widget.usuario,
          correo: _correo,
        ),
      ),
    );

    if (verified == true && mounted) {
      _loadStatus();
    }
  }

  // =========================================================================
  // PANTALLA PRINCIPAL: CONSISTENTE CON EDITPROFILEPAGE Y CHANGEPASSWORDPAGE
  // =========================================================================
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
        backgroundColor: _bg,
        body: SafeArea(
          child: _isLoading
              ? _buildSkeleton(context, isSmallScreen)
              : RefreshIndicator(
                  onRefresh: _loadStatus,
                  color: _primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 14.0 : 18.0,
                      vertical: 10.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Encabezado institucional de Mark (idéntico a EditProfilePage y ChangePasswordPage)
                        _buildAnimatedItem(_buildMarkHeader(context), 0),
                        const SizedBox(height: 16),

                        // 2. Tarjeta principal de Estado (Inset Grouped)
                        _buildAnimatedItem(_buildSectionTitle('ESTADO DE LA CUENTA'), 1),
                        _buildAnimatedItem(
                          _buildAppleGroupContainer(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: _activo
                                            ? const [Color(0xFFDCFCE7), Color(0xFFBBF7D0)]
                                            : const [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: Border.all(
                                        color: _activo ? const Color(0xFF86EFAC) : const Color(0xFF7DD3FC),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        _activo ? Icons.verified_user_rounded : Icons.shield_outlined,
                                        color: _activo ? _green : _primary,
                                        size: 27,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Badge con punto de color
                                        Row(
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: _activo ? _green : _textMuted,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              _activo ? 'PROTECCIÓN ACTIVA' : 'DESACTIVADA',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: _activo ? _green : _textSecondary,
                                                letterSpacing: 0.6,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _activo ? 'Verificación Activada' : 'Sin Configurar',
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: _textPrimary,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _activo
                                              ? 'Tu cuenta exige un código de 6 dígitos al iniciar en un nuevo dispositivo.'
                                              : 'Protección adicional no configurada en este momento.',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: _textSecondary,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // Detalle de correo vinculado si está activo
                              if (_activo && _correo.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _fieldBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _border),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.mail_outline_rounded,
                                          color: _primary,
                                          size: 17,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Correo para recibir códigos:',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: _textSecondary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              _correo,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: _textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Alerta de política corporativa
                              if (_exigido) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        color: Color(0xFFD97706),
                                        size: 17,
                                      ),
                                      SizedBox(width: 9),
                                      Expanded(
                                        child: Text(
                                          'La empresa exige la verificación en 2 pasos para tu cuenta; no puede ser desactivada.',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF92400E),
                                            fontWeight: FontWeight.w600,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          2,
                        ),
                        const SizedBox(height: 18),

                        // 3. Sección informativa: CÓMO FUNCIONA
                        _buildAnimatedItem(_buildSectionTitle('¿CÓMO FUNCIONA?'), 3),
                        _buildAnimatedItem(
                          _buildAppleGroupContainer(
                            children: [
                              _buildFeatureRow(
                                icon: Icons.mark_email_read_rounded,
                                iconBg: const Color(0xFFEFF6FF),
                                iconColor: _primary,
                                title: 'Código de seguridad',
                                subtitle: 'Cada vez que inicies sesión en un nuevo dispositivo, se te enviará un código de seguridad de 6 dígitos a tu correo.',
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(height: 1, color: _border),
                              ),
                              _buildFeatureRow(
                                icon: Icons.phonelink_lock_rounded,
                                iconBg: const Color(0xFFF0FDF4),
                                iconColor: _green,
                                title: 'Recordar dispositivo (90 días)',
                                subtitle: 'Si marcas "Recordar este dispositivo", el teléfono mantendrá una confianza de 90 días sin volver a pedirte el código.',
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(height: 1, color: _border),
                              ),
                              _buildFeatureRow(
                                icon: Icons.lock_reset_rounded,
                                iconBg: const Color(0xFFFAF5FF),
                                iconColor: const Color(0xFF9333EA),
                                title: 'Protección ante cambios',
                                subtitle: 'Si cambias tu contraseña, la verificación volverá a exigirse inmediatamente en todos los accesos.',
                              ),
                            ],
                          ),
                          4,
                        ),
                        const SizedBox(height: 24),

                        // 4. Botón de Acción Principal (LoadingActionButton)
                        _buildAnimatedItem(
                          !_activo
                              ? LoadingActionButton(
                                  text: 'Activar Verificación en 2 Pasos',
                                  isLoading: _isActionLoading,
                                  icon: Icons.shield_rounded,
                                  height: 50,
                                  borderRadius: 16,
                                  onPressed: _startActivation,
                                )
                              : (!_exigido
                                  ? LoadingActionButton(
                                      text: 'Desactivar Verificación en 2 Pasos',
                                      isLoading: _isActionLoading,
                                      icon: Icons.power_settings_new_rounded,
                                      height: 50,
                                      borderRadius: 16,
                                      backgroundColor: const Color(0xFFDC2626),
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      onPressed: _startDeactivation,
                                    )
                                  : const SizedBox.shrink()),
                          5,
                        ),
                        const SizedBox(height: 26),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context, bool isSmallScreen) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 14.0 : 18.0,
        vertical: 10.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMarkHeader(context, isDisabled: true),
          const SizedBox(height: 16),

          // Título de Estado Shimmer
          const AppShimmerBox.text(width: 140, height: 11),
          const SizedBox(height: 8),

          // Tarjeta Principal de Estado Shimmer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                const AppShimmerBox(width: 52, height: 52, shape: BoxShape.circle),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AppShimmerBox.text(width: 110, height: 10),
                      SizedBox(height: 8),
                      AppShimmerBox.text(width: 160, height: 16),
                      SizedBox(height: 6),
                      AppShimmerBox.text(width: double.infinity, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Título Detalles Shimmer
          const AppShimmerBox.text(width: 170, height: 11),
          const SizedBox(height: 8),

          // Tarjeta Inset de Detalles Shimmer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: const [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppShimmerBox.text(width: 100, height: 13),
                    AppShimmerBox.text(width: 140, height: 13),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppShimmerBox.text(width: 110, height: 13),
                    AppShimmerBox.text(width: 90, height: 13),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Botón de acción Shimmer
          const AppShimmerBox(
            width: double.infinity,
            height: 50,
            borderRadius: 16,
          ),
        ],
      ),
    );
  }

  // --- ENCABEZADO INSTITUCIONAL DE MARK (IDÉNTICO A EDITPROFILEPAGE / CHANGEPASSWORDPAGE) ---
  Widget _buildMarkHeader(BuildContext context, {bool isDisabled = false}) {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: (isDisabled || _isActionLoading) ? null : () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _border,
                  width: 1.0,
                ),
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
                'Verificación en 2 Pasos',
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

  // --- TÍTULO DE SECCIÓN INSET GROUPED ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: _textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // --- CONTENEDOR INSET GROUPED ESTILO MARK ---
  Widget _buildAppleGroupContainer({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _border,
          width: 1.0,
        ),
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

  // --- FILA DE CARACTERÍSTICA ("CÓMO FUNCIONA") ---
  Widget _buildFeatureRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
