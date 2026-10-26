import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/providers/Custodia_/custodia_provider.dart';
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
        title: 'Claves iguales',
      );
      return;
    }

    if (clave == '1111' || coaccion == '1111' || clave == '0000' || coaccion == '0000') {
      SnackbarTop.showError(
        context,
        'No se permiten claves débiles o repetidas (como 1111 o 0000).',
        title: 'Clave no segura',
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
      final err = ref.read(custodiaProvider).errorMessage ?? 'No se pudo configurar las claves';
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Claves de Custodia',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: Color(0xFF1D4ED8),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seguridad en Custodia',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Configura dos claves numéricas secretas (4 a 8 dígitos):\n'
                              '• Clave de Seguridad: para check-ins periódicos de rutina ("Todo bien").\n'
                              '• Clave de Coacción: en caso de amenaza forzada; aparenta éxito pero alerta silenciosamente al centro de monitoreo.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1E40AF),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Contraseña de la cuenta
                _buildFieldLabel('Contraseña de tu cuenta', isRequired: true),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _buildInputDecoration(
                    hintText: 'Ingresa tu contraseña actual',
                    prefixIcon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'La contraseña es requerida';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Clave de seguridad
                _buildFieldLabel('Clave de Seguridad (Normal)', isRequired: true),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _claveController,
                  obscureText: _obscureClave,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: _buildInputDecoration(
                    hintText: '4 a 8 dígitos numéricos',
                    prefixIcon: Icons.pin_outlined,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureClave
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureClave = !_obscureClave),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 4) {
                      return 'Debe tener entre 4 y 8 números';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Clave de coacción
                _buildFieldLabel('Clave de Coacción (Alerta silenciosa)', isRequired: true),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _coaccionController,
                  obscureText: _obscureCoaccion,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: _buildInputDecoration(
                    hintText: '4 a 8 dígitos (distinta a la de seguridad)',
                    prefixIcon: Icons.warning_amber_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCoaccion
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureCoaccion = !_obscureCoaccion),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 4) {
                      return 'Debe tener entre 4 y 8 números';
                    }
                    if (v.trim() == _claveController.text.trim()) {
                      return 'Debe ser distinta a la clave de seguridad';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                // Botón Guardar
                ElevatedButton(
                  onPressed: state.isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: state.isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Guardar Claves de Seguridad',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFEF4444),
            ),
          ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 13,
        color: Color(0xFF94A3B8),
      ),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF64748B), size: 20),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }
}
