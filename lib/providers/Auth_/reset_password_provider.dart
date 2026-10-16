import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/services/ConnectionAuth_/AuthCon_service.dart';

// Estado inmutable para la pantalla de restablecimiento de contraseña
class ResetPasswordState {
  final bool isLoading;
  final bool isNewPasswordVisible;
  final bool isConfirmPasswordVisible;
  final double passwordStrength;
  final String passwordStrengthMessage;
  final Color passwordStrengthColor;
  final bool passwordsMatch;
  final String? errorMessage;
  final bool isSuccess;

  const ResetPasswordState({
    this.isLoading = false,
    this.isNewPasswordVisible = false,
    this.isConfirmPasswordVisible = false,
    this.passwordStrength = 0.0,
    this.passwordStrengthMessage = '',
    this.passwordStrengthColor = const Color(0xFF94A3B8),
    this.passwordsMatch = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  ResetPasswordState copyWith({
    bool? isLoading,
    bool? isNewPasswordVisible,
    bool? isConfirmPasswordVisible,
    double? passwordStrength,
    String? passwordStrengthMessage,
    Color? passwordStrengthColor,
    bool? passwordsMatch,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return ResetPasswordState(
      isLoading: isLoading ?? this.isLoading,
      isNewPasswordVisible:
          isNewPasswordVisible ?? this.isNewPasswordVisible,
      isConfirmPasswordVisible:
          isConfirmPasswordVisible ?? this.isConfirmPasswordVisible,
      passwordStrength: passwordStrength ?? this.passwordStrength,
      passwordStrengthMessage:
          passwordStrengthMessage ?? this.passwordStrengthMessage,
      passwordStrengthColor:
          passwordStrengthColor ?? this.passwordStrengthColor,
      passwordsMatch: passwordsMatch ?? this.passwordsMatch,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

// Notificador que maneja la lógica de negocio y validación de contraseñas
class ResetPasswordNotifier extends Notifier<ResetPasswordState> {
  final AuthConService _authService = AuthConService();

  @override
  ResetPasswordState build() => const ResetPasswordState();

  void toggleNewPasswordVisibility() {
    state = state.copyWith(
      isNewPasswordVisible: !state.isNewPasswordVisible,
    );
  }

  void toggleConfirmPasswordVisibility() {
    state = state.copyWith(
      isConfirmPasswordVisible: !state.isConfirmPasswordVisible,
    );
  }

  void checkPasswordStrength(String password) {
    if (password.isEmpty) {
      state = state.copyWith(
        passwordStrength: 0.0,
        passwordStrengthMessage: '',
        passwordStrengthColor: const Color(0xFF94A3B8),
      );
      return;
    }

    double strength = 0;
    if (password.length >= 6) strength += 0.25;
    if (password.length >= 8) strength += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.15;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.15;

    final finalStrength = strength >= 1.0 ? 1.0 : strength.clamp(0.0, 1.0);
    String message = 'Contraseña Débil';
    Color color = const Color(0xFFEF4444);

    if (finalStrength >= 0.75) {
      message = 'Contraseña Segura';
      color = const Color(0xFF10B981);
    } else if (finalStrength >= 0.4) {
      message = 'Contraseña Moderada';
      color = const Color(0xFFF59E0B);
    }

    state = state.copyWith(
      passwordStrength: finalStrength,
      passwordStrengthMessage: message,
      passwordStrengthColor: color,
    );
  }

  void checkPasswordsMatch(String newPass, String confirmPass) {
    state = state.copyWith(
      passwordsMatch: confirmPass.isNotEmpty && confirmPass == newPass,
    );
  }

  Future<Map<String, dynamic>> submitResetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final res = await _authService.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );

      final isSuccess = res['success'] == true;
      state = state.copyWith(
        isLoading: false,
        isSuccess: isSuccess,
        errorMessage:
            isSuccess ? null : (res['message'] ?? 'Error al actualizar contraseña'),
      );
      return res;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        errorMessage: 'Error de conexión: $e',
      );
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  void reset() {
    state = const ResetPasswordState();
  }
}

// Proveedor global para ResetPassword
final resetPasswordProvider =
    NotifierProvider<ResetPasswordNotifier, ResetPasswordState>(
        ResetPasswordNotifier.new);
