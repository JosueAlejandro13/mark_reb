import 'package:flutter/material.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

/// Ronda 149: Configuración de Verificación en 2 Pasos (2FA) desde la App
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
  bool _isLoading = true;
  bool _isActionLoading = false;
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

  // --- FLUJO 1: ACTIVAR 2 PASOS ---
  Future<void> _startActivation() async {
    final passCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool passObscured = true;
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final mq = MediaQuery.of(sheetCtx);
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, mq.viewInsets.bottom + 20),
              child: SafeArea(
                top: false,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text(
                        'Activar Verificación en 2 Pasos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ingresa tu contraseña actual y el correo donde recibirás los códigos de acceso.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: passCtrl,
                        obscureText: passObscured,
                        decoration: InputDecoration(
                          labelText: 'Contraseña de la cuenta',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(passObscured ? Icons.visibility_off : Icons.visibility, size: 20),
                            onPressed: () => setSheetState(() => passObscured = !passObscured),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico para códigos',
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Ingresa un correo';
                          if (!v.contains('@') || !v.contains('.')) return 'Correo no válido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0886B5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (formKey.currentState?.validate() == true) {
                            Navigator.of(sheetCtx).pop(true);
                          }
                        },
                        child: const Text('Continuar', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isActionLoading = true);
    try {
      final res = await MarkApiClient.instance.dosPasosActivar(
        password: passCtrl.text,
        correo: emailCtrl.text.trim(),
      );

      final desafio = (res['desafio'] ?? '').toString();
      if (desafio.isEmpty) {
        throw Exception(res['error'] ?? 'No se recibió desafío del servidor.');
      }

      if (!mounted) return;
      setState(() => _isActionLoading = false);

      final verified = await _promptCodeVerification(
        desafio: desafio,
        title: 'Confirma el código enviado',
        subtitle: 'Enviamos un código de 6 dígitos a ${emailCtrl.text.trim()}. Escríbelo para completar la activación:',
      );

      if (verified == true && mounted) {
        SnackbarTop.showSuccess(
          context,
          'Verificación en dos pasos activada exitosamente.',
          style: SnackbarTopStyle.appleCard,
        );
        _loadStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionLoading = false);
        SnackbarTop.showError(
          context,
          'No se pudo activar: $e',
          style: SnackbarTopStyle.appleCard,
        );
      }
    }
  }

  // --- FLUJO 2: DESACTIVAR 2 PASOS ---
  Future<void> _startDeactivation() async {
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool passObscured = true;
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final mq = MediaQuery.of(sheetCtx);
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, mq.viewInsets.bottom + 20),
              child: SafeArea(
                top: false,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text(
                        'Desactivar Verificación en 2 Pasos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFDC2626),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Por seguridad, ingresa tu contraseña. Te mandaremos un código a tu correo para autorizar la desactivación.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: passCtrl,
                        obscureText: passObscured,
                        decoration: InputDecoration(
                          labelText: 'Contraseña de la cuenta',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(passObscured ? Icons.visibility_off : Icons.visibility, size: 20),
                            onPressed: () => setSheetState(() => passObscured = !passObscured),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (formKey.currentState?.validate() == true) {
                            Navigator.of(sheetCtx).pop(true);
                          }
                        },
                        child: const Text('Continuar', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isActionLoading = true);
    try {
      final res = await MarkApiClient.instance.dosPasosApagar(
        password: passCtrl.text,
      );

      final desafio = (res['desafio'] ?? '').toString();
      if (desafio.isEmpty) {
        throw Exception(res['error'] ?? 'No se recibió desafío del servidor.');
      }

      if (!mounted) return;
      setState(() => _isActionLoading = false);

      final verified = await _promptCodeVerification(
        desafio: desafio,
        title: 'Autorizar desactivación',
        subtitle: 'Escribe el código de 6 dígitos enviado a tu correo registrado para confirmar la desactivación:',
      );

      if (verified == true && mounted) {
        SnackbarTop.showSuccess(
          context,
          'Verificación en dos pasos desactivada.',
          style: SnackbarTopStyle.appleCard,
        );
        _loadStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionLoading = false);
        SnackbarTop.showError(
          context,
          'No se pudo desactivar: $e',
          style: SnackbarTopStyle.appleCard,
        );
      }
    }
  }

  // --- MODAL DE INGRESO DEL CÓDIGO DE 6 DÍGITOS ---
  Future<bool?> _promptCodeVerification({
    required String desafio,
    required String title,
    required String subtitle,
  }) {
    final codeCtrl = TextEditingController();
    bool isConfirming = false;
    String? localError;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final mq = MediaQuery.of(sheetCtx);
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, mq.viewInsets.bottom + 20),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: codeCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '000000',
                        hintStyle: const TextStyle(
                          fontSize: 24,
                          letterSpacing: 8,
                          color: Color(0xFFCBD5E1),
                        ),
                        errorText: localError,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0886B5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isConfirming
                          ? null
                          : () async {
                              final code = codeCtrl.text.trim();
                              if (code.length != 6) {
                                setSheetState(() => localError = 'Ingresa los 6 dígitos');
                                return;
                              }
                              setSheetState(() {
                                isConfirming = true;
                                localError = null;
                              });

                              try {
                                final res = await MarkApiClient.instance.dosPasosConfirmar(
                                  desafio: desafio,
                                  codigo: code,
                                );
                                if (res['ok'] == false) {
                                  throw Exception(res['error'] ?? 'Código inválido o expirado');
                                }
                                Navigator.of(sheetCtx).pop(true);
                              } catch (e) {
                                setSheetState(() {
                                  isConfirming = false;
                                  localError = e.toString().replaceAll('Exception: ', '');
                                });
                              }
                            },
                      child: isConfirming
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Verificación en 2 Pasos',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0886B5)),
            )
          : RefreshIndicator(
              onRefresh: _loadStatus,
              color: const Color(0xFF0886B5),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(20),
                children: [
                  // Card principal de estado
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _activo ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _activo ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Icon(
                                _activo ? Icons.verified_user_rounded : Icons.shield_outlined,
                                color: _activo ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _activo ? 'Activada' : 'Desactivada',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: _activo ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _activo
                                        ? 'Tu cuenta está protegida con código de 6 dígitos'
                                        : 'Protección adicional no configurada',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_activo && _correo.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.email_outlined, color: Color(0xFF0886B5), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Correo para recibir códigos:',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        _correo,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_exigido) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'La empresa exige la verificación en 2 pasos para tu cuenta; no puede ser desactivada.',
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Información explicativa
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '¿Cómo funciona?',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Cada vez que inicies sesión en un nuevo dispositivo, se te enviará un código de seguridad de 6 dígitos a tu correo electrónico.\n\n• Si marcas "Recordar este dispositivo", el teléfono mantendrá una confianza de 90 días sin volver a pedirte el código.\n\n• Si cambias tu contraseña, la verificación volverá a exigirse inmediatamente.',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.45),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  // Botón de acción principal
                  if (!_activo)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0886B5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _isActionLoading ? null : _startActivation,
                      icon: const Icon(Icons.shield_rounded, size: 20),
                      label: const Text(
                        'Activar Verificación en 2 Pasos',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    )
                  else if (!_exigido)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isActionLoading ? null : _startDeactivation,
                      icon: const Icon(Icons.power_settings_new_rounded, size: 20),
                      label: const Text(
                        'Desactivar Verificación en 2 Pasos',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
