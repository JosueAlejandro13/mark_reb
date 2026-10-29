import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

/// Pantalla completa para verificar el código de 6 dígitos de doble autenticación
/// Utiliza exactamente el mismo sistema de cuadros interactivos, autocompletado y
/// auto-envío que la pantalla de 2FA del login (TwoFactorAuthPage).
class TwoFactorVerifyCodePage extends StatefulWidget {
  final String desafio;
  final String? email;
  final bool isActivation;
  final String title;
  final String subtitle;

  const TwoFactorVerifyCodePage({
    super.key,
    required this.desafio,
    this.email,
    this.isActivation = true,
    required this.title,
    required this.subtitle,
  });

  @override
  State<TwoFactorVerifyCodePage> createState() => _TwoFactorVerifyCodePageState();
}

class _TwoFactorVerifyCodePageState extends State<TwoFactorVerifyCodePage> {
  // Paleta oficial de Mark App
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _primary = Color(0xFF0284C7);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _red = Color(0xFFEF4444);

  static const int _codeLength = 6;
  final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_codeLength, (_) => FocusNode());
  final List<FocusNode> _keyboardFocusNodes =
      List.generate(_codeLength, (_) => FocusNode());

  late String _currentDesafio;
  int _resendCountdown = 60;
  Timer? _timer;
  bool _canResend = false;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentDesafio = widget.desafio;
    _startResendTimer();
    // Poner el foco en el primer cuadro automáticamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    });
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
        // Auto-submit automático igual que en el login
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

      // Al completar los 6 dígitos: se quita el foco y se oprime solo el botón
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

  Future<void> _handleResend() async {
    if (!_canResend || _isResending || _isVerifying) return;

    setState(() => _isResending = true);
    try {
      final res = await MarkApiClient.instance.reenviarCodigo(
        desafio: _currentDesafio,
        medio: 'correo',
      );
      if (res['desafio'] != null) {
        _currentDesafio = res['desafio'].toString();
      }
      _startResendTimer();
      if (mounted) {
        final dest = widget.email?.isNotEmpty == true ? ' a ${widget.email}' : '';
        SnackbarTop.showSuccess(
          context,
          res['mensaje'] ?? 'Código reenviado exitosamente$dest.',
          title: 'Código Reenviado',
        );
      }
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
      final res = await MarkApiClient.instance.dosPasosConfirmar(
        desafio: _currentDesafio,
        codigo: code,
      );

      if (!mounted) return;

      if (res['ok'] == false) {
        final error = (res['error'] ?? 'Código inválido o expirado.').toString();
        setState(() {
          _errorMessage = error;
        });
        SnackbarTop.showError(
          context,
          error,
          title: 'Código Inválido',
        );
        return;
      }

      HapticFeedback.heavyImpact();
      SnackbarTop.showSuccess(
        context,
        widget.isActivation
            ? '¡Verificación en dos pasos activada exitosamente!'
            : 'Verificación en dos pasos desactivada correctamente.',
        title: 'Operación Exitosa',
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        final err = e.toString().replaceAll('Exception: ', '');
        setState(() {
          _errorMessage = err;
        });
        SnackbarTop.showError(
          context,
          err,
          title: 'Error de Verificación',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Widget _buildDigitBox(int index, {double width = 46, double height = 54}) {
    final isBusy = _isVerifying || _isResending;
    return SizedBox(
      width: width,
      height: height,
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
            color: _textPrimary,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: isBusy ? const Color(0xFFF1F5F9) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _border, width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _border, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: widget.isActivation ? _primary : _red,
                width: 1.8,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _border, width: 1.0),
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
              absorbing: _isVerifying || _isResending,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Encabezado institucional de Mark
                  _buildHeader(context),
                  const SizedBox(height: 16),

                  // 2. Tarjeta contenedora de verificación
                  _buildAppleGroupContainer(
                    children: [
                      Center(
                        child: Column(
                          children: [
                            // Emblema Hero
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: widget.isActivation
                                      ? const [Color(0xFFE0F2FE), Color(0xFFBAE6FD)]
                                      : const [Color(0xFFFEE2E2), Color(0xFFFECACA)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(color: Colors.white, width: 3.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: (widget.isActivation ? _primary : _red)
                                        .withOpacity(0.20),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  widget.isActivation
                                      ? Icons.mark_email_read_rounded
                                      : Icons.shield_outlined,
                                  color: widget.isActivation ? _primary : _red,
                                  size: 34,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Título
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Subtítulo
                            Text(
                              widget.subtitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: _textSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Cajas de dígitos (6 cuadros independientes)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final availableWidth = constraints.maxWidth;
                                final boxWidth =
                                    ((availableWidth - 40) / _codeLength).clamp(38.0, 48.0);
                                final boxHeight = (boxWidth * 1.18).clamp(48.0, 56.0);

                                return AutofillGroup(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: List.generate(
                                      _codeLength,
                                      (index) => _buildDigitBox(
                                        index,
                                        width: boxWidth,
                                        height: boxHeight,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Mensaje de error
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFFECACA),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      size: 16,
                                      color: _red,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: _red,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            // Temporizador y botón de reenviar
                            Center(
                              child: (_canResend && !_isVerifying)
                                  ? TextButton.icon(
                                      onPressed: _isResending ? null : _handleResend,
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        size: 18,
                                        color: _primary,
                                      ),
                                      label: const Text(
                                        'Reenviar código',
                                        style: TextStyle(
                                          color: _primary,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'Reenviar código en ${_resendCountdown.toString().padLeft(2, '0')}s',
                                      style: const TextStyle(
                                        color: _textMuted,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                            ),

                            const SizedBox(height: 20),

                            // Botón de confirmación (se oprime solo al llenar los 6 dígitos)
                            LoadingActionButton(
                              text: 'Confirmar Código',
                              isLoading: _isVerifying,
                              icon: Icons.check_circle_rounded,
                              height: 50,
                              borderRadius: 16,
                              onPressed: _isVerifying ? null : _handleVerify,
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: (_isVerifying || _isResending)
                ? null
                : () => Navigator.pop(context, false),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isActivation
                    ? 'Verificación en 2 Pasos'
                    : 'Autorizar Desactivación',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                widget.isActivation
                    ? 'Paso final de activación de seguridad'
                    : 'Paso final para desactivar la protección',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
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
}

