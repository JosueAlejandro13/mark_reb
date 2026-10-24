import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';
import 'package:mark_v3/providers/Auth_/login_provider.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

/// Pantalla completa de Verificación en 2 Pasos (2FA) estilo Apple / Mark V3.1
class TwoFactorAuthPage extends ConsumerStatefulWidget {
  final Login2FaChallenge challenge;
  final String email;
  final String password;
  final bool initialRememberMe;

  const TwoFactorAuthPage({
    super.key,
    required this.challenge,
    required this.email,
    required this.password,
    this.initialRememberMe = true,
  });

  @override
  ConsumerState<TwoFactorAuthPage> createState() => _TwoFactorAuthPageState();
}

class _TwoFactorAuthPageState extends ConsumerState<TwoFactorAuthPage> {
  static const int _codeLength = 6;
  final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_codeLength, (_) => FocusNode());
  final List<FocusNode> _keyboardFocusNodes =
      List.generate(_codeLength, (_) => FocusNode());

  int _resendCountdown = 60;
  Timer? _timer;
  bool _canResend = false;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _rememberDevice = true;
  String? _errorMessage;

  late String _currentMedio;
  late String _currentDesafio;

  @override
  void initState() {
    super.initState();
    _rememberDevice = widget.initialRememberMe;
    _currentMedio = widget.challenge.enviado.isNotEmpty
        ? widget.challenge.enviado
        : (widget.challenge.sms.isNotEmpty ? 'sms' : 'correo');
    _currentDesafio = widget.challenge.desafio;
    _startResendTimer();
  }

  void _startResendTimer() {
    setState(() {
      _resendCountdown = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown > 1) {
        setState(() => _resendCountdown--);
      } else {
        setState(() {
          _canResend = true;
          timer.cancel();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    for (final k in _keyboardFocusNodes) {
      k.dispose();
    }
    super.dispose();
  }

  String get _currentCode => _controllers.map((c) => c.text).join();

  String get _currentDestination {
    if (_currentMedio == 'sms') {
      return widget.challenge.sms.isNotEmpty
          ? widget.challenge.sms
          : 'tu teléfono registrado';
    }
    return widget.challenge.correo.isNotEmpty
        ? widget.challenge.correo
        : widget.email;
  }

  void _onDigitChanged(int index, String value) {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }

    final digits = value.replaceAll(RegExp(r'\D'), '');

    // Manejo de Autofill del sistema o pegado múltiple (SMS / OneTimeCode)
    if (digits.length > 1) {
      if (digits.length >= _codeLength) {
        for (int i = 0; i < _codeLength; i++) {
          _controllers[i].text = digits[i];
        }
        FocusScope.of(context).unfocus();
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted && _currentCode.length == _codeLength && !_isVerifying) {
            _handleVerify();
          }
        });
        return;
      } else {
        for (int i = 0; i < digits.length && (index + i) < _codeLength; i++) {
          _controllers[index + i].text = digits[i];
        }
        final nextIdx = (index + digits.length).clamp(0, _codeLength - 1);
        _focusNodes[nextIdx].requestFocus();
        if (_currentCode.length == _codeLength && !_isVerifying) {
          FocusScope.of(context).unfocus();
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted &&
                _currentCode.length == _codeLength &&
                !_isVerifying) {
              _handleVerify();
            }
          });
        }
        return;
      }
    }

    if (value.isEmpty) {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
      return;
    }

    if (digits.isNotEmpty) {
      _controllers[index].text = digits;
      if (index < _codeLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }

      if (_currentCode.length == _codeLength && !_isVerifying) {
        FocusScope.of(context).unfocus();
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted && _currentCode.length == _codeLength && !_isVerifying) {
            _handleVerify();
          }
        });
      }
    }
  }

  Future<void> _handleResend({String? forcedMedio}) async {
    if ((!_canResend && forcedMedio == null) || _isResending || _isVerifying) {
      return;
    }

    final medioToSend = forcedMedio ?? _currentMedio;

    setState(() => _isResending = true);

    try {
      if (_currentDesafio == 'demo_desafio_12345') {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          _currentMedio = medioToSend;
        });
        if (mounted) {
          SnackbarTop.showSuccess(
            context,
            'Código reenviado exitosamente a $_currentDestination (Modo Demo).',
            title: 'Código Reenviado',
          );
        }
      } else {
        final res = await MarkApiClient.instance.reenviarCodigo(
          desafio: _currentDesafio,
          medio: medioToSend,
        );
        if (res['desafio'] != null) {
          _currentDesafio = res['desafio'].toString();
        }
        setState(() {
          _currentMedio = medioToSend;
        });
        if (mounted) {
          SnackbarTop.showSuccess(
            context,
            res['mensaje'] ??
                'Código reenviado exitosamente a $_currentDestination.',
            title: 'Código Reenviado',
          );
        }
      }
      _startResendTimer();
    } catch (e) {
      if (mounted) {
        SnackbarTop.showError(
          context,
          'No se pudo reenviar el código. Intenta de nuevo en unos momentos.',
          title: 'Error de Reenvío',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _handleVerify() async {
    if (_isVerifying) return;
    final code = _currentCode;
    if (code.length < _codeLength) {
      setState(() {
        _errorMessage = 'Por favor ingresa los 6 dígitos del código.';
      });
      SnackbarTop.showError(
        context,
        'Por favor completa los 6 dígitos del código de verificación.',
        title: 'Código Incompleto',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      // Modo Demo para pruebas visuales
      if (_currentDesafio == 'demo_desafio_12345') {
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) {
          SnackbarTop.showSuccess(
            context,
            '¡Verificación en 2 pasos validada correctamente!',
            title: '2FA Exitoso',
          );
          Navigator.pop(context);
        }
        return;
      }

      final res = await MarkApiClient.instance.login2pasos(
        desafio: _currentDesafio,
        codigo: code,
        recordar: _rememberDevice,
      );

      if (!mounted) return;

      if (!res.isSuccess || res.session == null) {
        setState(() {
          _errorMessage = res.errorMessage ?? 'Código incorrecto o expirado.';
        });
        SnackbarTop.showError(
          context,
          res.errorMessage ??
              'Código incorrecto o expirado. Intenta nuevamente.',
          title: 'Código Inválido',
        );
        return;
      }

      SnackbarTop.showSuccess(
        context,
        'Identidad verificada. Iniciando sesión...',
        title: 'Acceso Correcto',
      );

      await ref.read(loginProvider.notifier).completeLoginFrom2Fa(
            context: context,
            session: res.session!,
            email: widget.email,
            password: widget.password,
            rememberMe: _rememberDevice,
          );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de conexión al verificar el código.';
        });
        SnackbarTop.showError(
          context,
          'Error al verificar código: $e',
          title: 'Error de Conexión',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Widget _buildDigitBox(int index) {
    final isBusy = _isVerifying || _isResending;
    return SizedBox(
      width: 46,
      height: 54,
      child: KeyboardListener(
        focusNode: _keyboardFocusNodes[index],
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_controllers[index].text.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
              _controllers[index - 1].clear();
            }
          }
        },
        child: TextFormField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          enabled: !isBusy,
          readOnly: isBusy,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onTap: () {
            if (_controllers[index].text.isNotEmpty) {
              _controllers[index].selection = TextSelection(
                baseOffset: 0,
                extentOffset: _controllers[index].text.length,
              );
            }
          },
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor:
                isBusy ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                  const BorderSide(color: Color(0xFF0284C7), width: 1.8),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
            ),
          ),
          onChanged: (val) => _onDigitChanged(index, val),
        ),
      ),
    );
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
                          onTap: (_isVerifying || _isResending)
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
                                  color:
                                      const Color(0xFF0F172A).withOpacity(0.04),
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
                        // ── Silueta urbana pastel inferior ───────────────
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
                            child: AbsorbPointer(
                              absorbing: _isVerifying || _isResending,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ── Badge de verificación estilo Apple ───
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
                                          Icons.verified_user_outlined,
                                          size: 14,
                                          color: Color(0xFF0284C7),
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Verificación',
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
                                    'Verificación en 2 Pasos',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Hemos enviado un código de 6 dígitos a:\n$_currentDestination',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: Color(0xFF64748B),
                                      height: 1.4,
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
                                          'Código de seguridad',
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

                                  const SizedBox(height: 24),

                                  // ── Cajas de 6 dígitos ───────────────────
                                  AutofillGroup(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: List.generate(
                                        _codeLength,
                                        (index) => _buildDigitBox(index),
                                      ),
                                    ),
                                  ),

                                  // ── Mensaje de error ─────────────────────
                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: 14),
                                    Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: const Color(0xFFFECACA),
                                              width: 1),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.error_outline_rounded,
                                              size: 16,
                                              color: Color(0xFFEF4444),
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                _errorMessage!,
                                                style: const TextStyle(
                                                  color: Color(0xFFEF4444),
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 16),

                                  // ── Checkbox: Recordar dispositivo 90 días ──
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _rememberDevice = !_rememberDevice;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: Checkbox(
                                              value: _rememberDevice,
                                              activeColor:
                                                  const Color(0xFF0284C7),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              onChanged: (val) {
                                                setState(() => _rememberDevice =
                                                    val ?? true);
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          const Expanded(
                                            child: Text(
                                              'Recordar este dispositivo por 90 días',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: Color(0xFF475569),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // ── Reenviar código / temporizador ───────
                                  Center(
                                    child: (_canResend && !_isVerifying)
                                        ? TextButton.icon(
                                            onPressed: _isResending
                                                ? null
                                                : () => _handleResend(),
                                            icon: const Icon(
                                              Icons.refresh_rounded,
                                              size: 18,
                                              color: Color(0xFF0284C7),
                                            ),
                                            label: const Text(
                                              'Reenviar código',
                                              style: TextStyle(
                                                color: Color(0xFF0284C7),
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            'Reenviar código en ${_resendCountdown.toString().padLeft(2, '0')}s',
                                            style: const TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                  ),

                                  // ── Opción de alternar medio (SMS vs Correo) ─
                                  if (widget.challenge.sms.isNotEmpty &&
                                      widget.challenge.correo.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Center(
                                      child: TextButton(
                                        onPressed: (_isResending ||
                                                _isVerifying)
                                            ? null
                                            : () {
                                                final otherMedio =
                                                    _currentMedio == 'correo'
                                                        ? 'sms'
                                                        : 'correo';
                                                _handleResend(
                                                    forcedMedio: otherMedio);
                                              },
                                        child: Text(
                                          _currentMedio == 'correo'
                                              ? '¿Prefieres recibirlo por SMS?'
                                              : '¿Prefieres recibirlo por Correo?',
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 24),

                                  // ── Botón Verificar Código ───────────────
                                  LoadingActionButton(
                                    text: 'Verificar Código',
                                    isLoading: _isVerifying,
                                    icon: Icons.check_circle_outline_rounded,
                                    height: 50,
                                    borderRadius: 14,
                                    fontSize: 15,
                                    onPressed: _handleVerify,
                                  ),

                                  const SizedBox(height: 16),
                                ],
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

// ── Clipper: Curva asimétrica de la tarjeta blanca ─────────────────────────
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

// ── Painter: Sombra suave bajo la curva ────────────────────────────────────
class _WaveShadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A).withOpacity(0.04)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

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

// ── Painter: Silueta urbana y detalle vegetal en tonos pastel al fondo ─────
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

    // Suave suelo ondulado
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
