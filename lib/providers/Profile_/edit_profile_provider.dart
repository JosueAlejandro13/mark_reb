import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:mark_v3/services/ConnectionProfile_/ProfileCon_service.dart';
import 'package:mark_v3/providers/Profile_/profile_provider.dart';

// Estado inmutable de Edición de Perfil
class EditProfileState {
  final bool isLoading;
  final bool isSaving;
  final Map<String, dynamic>? userData;
  final String? error;
  final String? successMessage;
  final bool isConnectionError;
  final bool isServerError;
  final bool isUnexpectedError;

  const EditProfileState({
    this.isLoading = true,
    this.isSaving = false,
    this.userData,
    this.error,
    this.successMessage,
    this.isConnectionError = false,
    this.isServerError = false,
    this.isUnexpectedError = false,
  });

  EditProfileState copyWith({
    bool? isLoading,
    bool? isSaving,
    Map<String, dynamic>? userData,
    String? error,
    String? successMessage,
    bool? isConnectionError,
    bool? isServerError,
    bool? isUnexpectedError,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearUserData = false,
  }) {
    return EditProfileState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      userData: clearUserData ? null : (userData ?? this.userData),
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
      isConnectionError: isConnectionError ?? this.isConnectionError,
      isServerError: isServerError ?? this.isServerError,
      isUnexpectedError: isUnexpectedError ?? this.isUnexpectedError,
    );
  }
}

// Provider Global de Edición de Perfil con autoDispose para que se destruya al salir de la pantalla
final editProfileProvider =
    NotifierProvider.autoDispose<EditProfileNotifier, EditProfileState>(
        EditProfileNotifier.new);

class EditProfileNotifier extends Notifier<EditProfileState> {
  final ProfileconService _service = ProfileconService();

  @override
  EditProfileState build() {
    return const EditProfileState();
  }

  void reset() {
    state = const EditProfileState();
  }

  bool _isNetworkError(Object e) {
    if (e is SocketException || e is http.ClientException) return true;
    final msg = e.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('clientexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable') ||
        msg.contains('software caused connection abort') ||
        msg.contains('connection refused');
  }

  Future<void> loadUserData({
    required String collaboratorId,
    required String idMainAccount,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearUserData: true,
      clearError: true,
      clearSuccess: true,
      isConnectionError: false,
      isServerError: false,
      isUnexpectedError: false,
    );
    try {
      final data = await _service.getUserData(collaboratorId, idMainAccount);
      final photoUrl = (data['photo'] ?? data['foto'] ?? '').toString();
      if (photoUrl.isNotEmpty) {
        ref.read(profileProvider.notifier).setNetworkPhotoUrl(photoUrl);
      }
      state = state.copyWith(
        isLoading: false,
        userData: data,
        isConnectionError: false,
        isServerError: false,
        isUnexpectedError: false,
      );
    } on TimeoutException catch (_) {
      state = state.copyWith(
        isLoading: false,
        isServerError: true,
        error: 'Tiempo de espera agotado con el servidor.',
      );
    } catch (e) {
      debugPrint('Error al cargar datos del usuario: $e');
      if (_isNetworkError(e)) {
        state = state.copyWith(
          isLoading: false,
          isConnectionError: true,
          error: 'No hay conexión a Internet.',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          isUnexpectedError: true,
          error: 'No se pudieron cargar los datos del usuario.',
        );
      }
    }
  }

  Future<bool> saveUserData({
    required String userId,
    required String idMainAccount,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String mobilPhone,
    required String address,
    required String dateOfBirth,
    required String employeeNum,
    required String idJobTitle,
    File? newPhotoFile,
    String? photoUuid,
  }) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
      isConnectionError: false,
      isServerError: false,
      isUnexpectedError: false,
    );
    try {
      String? finalPhotoUuid = photoUuid;
      if (newPhotoFile != null && await newPhotoFile.exists()) {
        finalPhotoUuid = await _service.updateProfilePhoto(newPhotoFile.path);
      }

      await _service.updateUserData(
        userId: userId,
        idMainAccount: idMainAccount,
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        mobilPhone: mobilPhone,
        address: address,
        dateOfBirth: dateOfBirth,
        employeeNum: employeeNum,
        idJobTitle: idJobTitle,
        photoUuid: finalPhotoUuid,
      );

      // Sincronizar fotografía y datos oficiales desde el servidor
      ref.read(profileProvider.notifier).refreshProfile();

      state = state.copyWith(
        isSaving: false,
        successMessage: 'Cambios guardados con éxito.',
      );
      return true;
    } on TimeoutException catch (_) {
      state = state.copyWith(
        isSaving: false,
        isServerError: true,
        error: 'Tiempo de espera agotado con el servidor.',
      );
      return false;
    } catch (e) {
      debugPrint('Error al guardar datos: $e');
      if (_isNetworkError(e)) {
        state = state.copyWith(
          isSaving: false,
          isConnectionError: true,
          error: 'No hay conexión a Internet.',
        );
      } else {
        final rawMsg = e.toString().replaceFirst('Exception: ', '').trim();
        state = state.copyWith(
          isSaving: false,
          error: rawMsg.isNotEmpty
              ? rawMsg
              : 'Error al guardar los cambios. Intente nuevamente.',
        );
      }
      return false;
    }
  }
}