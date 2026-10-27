import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/providers/Custodia_/custodia_provider.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

class CustodiaClavesPage extends ConsumerStatefulWidget {
  const CustodiaClavesPage({super.key});

  @override
  ConsumerState<CustodiaClavesPage> createState() => _CustodiaClavesPageState();
}

class _CustodiaClavesPageState extends ConsumerState<CustodiaClavesPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _claveController = TextEditingController();
  final _coaccionController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureClave = true;
  bool _obscureCoaccion = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _claveController.dispose();
    _coaccionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final clave = _claveController.text.trim();
    final coaccion = _coaccionController.text.trim();

    if (clave == coaccion) {
      SnackbarTop.showError(
        context,
        'La clave de coacción no puede ser igual a la de seguridad.',
        title: 'Claves idénticas',
      );
      return;
    }

    if (clave == '1111' ||
        coaccion == '1111' ||
        clave == '0000' ||
        coaccion == '0000') {
      SnackbarTop.showError(
        context,
        'No se permiten claves débiles o repetidas (como 1111 o 0000).',
        title: 'Clave insegura',
      );
      return;
    }

    final success = await ref.read(custodiaProvider.notifier).configurarClaves(
          password: _passwordController.text,
          clave: clave,
          coaccion: coaccion,
        );

    if (!mounted) return;

    if (success) {
      SnackbarTop.showSuccess(
        context,
        'Claves de seguridad y coacción configuradas correctamente.',
        title: 'Configuración guardada',
      );
      Navigator.of(context).pop(true);
    } else {
      final err = ref.read(custodiaProvider).errorMessage ??
          'No se pudo configurar las claves';
      SnackbarTop.showError(
        context,
        err,
        title: 'Error de configuración',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(custodiaProvider);
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 360;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: state.isLoading
            ? SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12.0 : 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 16),
                    AppSkeleton.form(
                      hasHeader: false,
                      sectionsCount: 2,
                      fieldsPerSection: 2,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              )
            : GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.translucent,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12.0 : 16.0,
                    vertical: 8.0,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header estilo Apple
                        _buildHeader(context),
                        const SizedBox(height: 16),

                        // Tarjeta informativa Apple
                        _buildApplePrivacyCard(),
                        const SizedBox(height: 18),

                        // Grupo 1: Contraseña de cuenta
                        _buildSectionTitle('AUTENTICACIÓN DE CUENTA'),
                        _buildAppleGroupContainer(
                          children: [
                            _buildAppleTextField(
                              controller: _passwordController,
                              label: 'Contraseña actual',
                              hintText: 'Ingresa tu contraseña',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              onToggleVisibility: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                              helperText:
                                  'Requerida por seguridad corporativa para autorizar las nuevas claves.',
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Ingresa tu contraseña actual'
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Grupo 2: Claves numéricas
                        _buildSectionTitle('CLAVES DE OPERACIÓN Y SEGURIDAD'),
                        _buildAppleGroupContainer(
                          children: [
                            _buildAppleTextField(
                              controller: _claveController,
                              label: 'Clave de Seguridad (Rutina)',
                              hintText: '4 a 8 dígitos numéricos',
                              icon: Icons.shield_outlined,
                              obscureText: _obscureClave,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(8),
                              ],
                              onToggleVisibility: () => setState(
                                  () => _obscureClave = !_obscureClave),
                              helperText:
                                  'Úsala para tus check-ins periódicos de rutina ("Todo bien").',
                              validator: (v) {
                                if (v == null || v.trim().length < 4) {
                                  return 'Debe tener entre 4 y 8 números';
                                }
                                return null;
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child:
                                  Divider(color: Color(0xFFF1F5F9), height: 1),
                            ),
                            _buildAppleTextField(
                              controller: _coaccionController,
                              label: 'Clave de Coacción (Alerta Silenciosa)',
                              hintText: '4 a 8 dígitos distintos',
                              icon: Icons.warning_amber_rounded,
                              obscureText: _obscureCoaccion,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(8),
                              ],
                              onToggleVisibility: () => setState(
                                  () => _obscureCoaccion = !_obscureCoaccion),
                              helperText:
                                  'Si te amenazan, ingresa esta clave. La app mostrará éxito pero enviará alerta silenciosa inmediata al centro de monitoreo.',
                              validator: (v) {
                                if (v == null || v.trim().length < 4) {
                                  return 'Debe tener entre 4 y 8 números';
                                }
                                if (v.trim() == _claveController.text.trim()) {
                                  return 'Debe ser distinta a la de seguridad';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Botón de Guardar estilo Apple
                        _buildSaveButton(state),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // --- HEADER SUPERIOR ESTILO APPLE ---
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
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.03),
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
                'Claves de Custodia',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Configuración de seguridad y coacción personal',
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

  Widget _buildApplePrivacyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.shield_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seguridad Blindada',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Nadie más conoce tus claves. La clave de coacción protege tu integridad: si te obligan a reportar, la app no cambia de pantalla ni vibra, pero emite alerta prioritaria al CEDI.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
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

  Widget _buildAppleGroupContainer({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
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

  Widget _buildAppleTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 19),
            suffixIcon: onToggleVisibility != null
                ? IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFF94A3B8),
                      size: 19,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide:
                  const BorderSide(color: Color(0xFF0284C7), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
          ),
          validator: validator,
        ),
        if (helperText != null) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              helperText,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                height: 1.3,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSaveButton(CustodiaState state) {
    return LoadingActionButton(
      text: 'Guardar Claves de Seguridad',
      isLoading: state.isSubmitting,
      onPressed: _submit,
      icon: Icons.check_circle_rounded,
      borderRadius: 16,
      height: 50,
      fontSize: 14.5,
    );
  }
}
