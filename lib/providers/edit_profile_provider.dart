import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/services/ConnectionProfile_/ProfileCon_service.dart';

// Estado inmutable de Edición de Perfil
class EditProfileState {
  final bool isLoading;
  final bool isSaving;
  final Map<String, dynamic>? userData;
  final String? error;
  final String? successMessage;

  const EditProfileState({
    this.isLoading = true,
    this.isSaving = false,
    this.userData,
    this.error,
    this.successMessage,
  });

  EditProfileState copyWith({
    bool? isLoading,
    bool? isSaving,
    Map<String, dynamic>? userData,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return EditProfileState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      userData: userData ?? this.userData,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

// Provider Global de Edición de Perfil
final editProfileProvider =
    NotifierProvider<EditProfileNotifier, EditProfileState>(
        EditProfileNotifier.new);

class EditProfileNotifier extends Notifier<EditProfileState> {
  final ProfileconService _service = ProfileconService();

  @override
  EditProfileState build() {
    return const EditProfileState();
  }

  Future<void> loadUserData({
    required String collaboratorId,
    required String idMainAccount,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final data = await _service.getUserData(collaboratorId, idMainAccount);
      state = state.copyWith(isLoading: false, userData: data);
    } catch (e) {
      debugPrint('Error al cargar datos del usuario: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'No se pudieron cargar los datos del usuario.',
      );
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
  }) async {
    state = state.copyWith(isSaving: true, clearError: true, clearSuccess: true);
    try {
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
      );
      state = state.copyWith(
        isSaving: false,
        successMessage: 'Cambios guardados con éxito.',
      );
      return true;
    } catch (e) {
      debugPrint('Error al guardar datos: $e');
      state = state.copyWith(
        isSaving: false,
        error: 'Error al guardar los cambios. Intente nuevamente.',
      );
      return false;
    }
  }
}
