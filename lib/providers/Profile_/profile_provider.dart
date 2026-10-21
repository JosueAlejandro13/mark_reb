import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/services/ConnectionProfile_/ProfileCon_service.dart';

// Estado inmutable del Perfil
class ProfileState {
  final File? imageFile;
  final String? networkPhotoUrl;
  final bool isLoading;
  final bool isUploadingPhoto;
  final String? error;
  final bool hasLicense;
  final bool canEditLicense;

  const ProfileState({
    this.imageFile,
    this.networkPhotoUrl,
    this.isLoading = false,
    this.isUploadingPhoto = false,
    this.error,
    this.hasLicense = false,
    this.canEditLicense = true,
  });

  ProfileState copyWith({
    File? imageFile,
    String? networkPhotoUrl,
    bool? isLoading,
    bool? isUploadingPhoto,
    String? error,
    bool? hasLicense,
    bool? canEditLicense,
    bool clearImage = false,
    bool clearNetworkPhoto = false,
    bool clearError = false,
  }) {
    return ProfileState(
      imageFile: clearImage ? null : (imageFile ?? this.imageFile),
      networkPhotoUrl: clearNetworkPhoto
          ? null
          : (networkPhotoUrl ?? this.networkPhotoUrl),
      isLoading: isLoading ?? this.isLoading,
      isUploadingPhoto: isUploadingPhoto ?? this.isUploadingPhoto,
      error: clearError ? null : (error ?? this.error),
      hasLicense: hasLicense ?? this.hasLicense,
      canEditLicense: canEditLicense ?? this.canEditLicense,
    );
  }
}

// Proveedor global de Perfil gestionado con Riverpod
final profileProvider =
    NotifierProvider<ProfileNotifier, ProfileState>(ProfileNotifier.new);

class ProfileNotifier extends Notifier<ProfileState> {
  final ProfileconService _profileService = ProfileconService();

  @override
  ProfileState build() {
    Future.microtask(() {
      _cleanLegacyImagePrefs();
      _loadNetworkPhoto();
    });
    return const ProfileState(
      canEditLicense: true,
    );
  }

  /// Limpieza única de claves obsoletas de imagen en base64 de SharedPreferences
  Future<void> _cleanLegacyImagePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('image');
      final keys =
          prefs.getKeys().where((k) => k.startsWith('user_image_')).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  void setNetworkPhotoUrl(String? url) {
    if (url != null && url.trim().isNotEmpty) {
      final fullUrl = MarkApiClient.instance.resolveAssetUrl(url.trim());
      state = state.copyWith(networkPhotoUrl: fullUrl);
    }
  }

  Future<void> _loadNetworkPhoto() async {
    try {
      final res = await MarkApiClient.instance.getPerfil();
      if (res['ok'] == true) {
        if (res['colaborador'] is Map<String, dynamic>) {
          final colaborador = res['colaborador'] as Map<String, dynamic>;
          final rawFoto = (colaborador['foto'] ?? '').toString().trim();
          if (rawFoto.isNotEmpty) {
            setNetworkPhotoUrl(rawFoto);
          }
        }

        final licencia = res['licencia'];
        final licNum = (licencia is Map ? (licencia['numero'] ?? '') : '').toString().trim();
        final hasLic = licNum.isNotEmpty;

        state = state.copyWith(
          hasLicense: hasLic,
          canEditLicense: true,
        );
      }
    } catch (e) {
      debugPrint('[ProfileNotifier] Error loading network photo/license: $e');
    }
  }

  Future<void> refreshProfile() async {
    await _loadNetworkPhoto();
  }

  /// Selecciona una fotografía y la sube de inmediato al servidor (api.php?a=foto y acción perfil)
  Future<bool> changeProfilePhoto({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile == null) return false;

      final file = File(pickedFile.path);
      state = state.copyWith(
        imageFile: file,
        isUploadingPhoto: true,
        clearError: true,
      );

      // Subida de imagen al servidor vía api.php?a=foto y api.php?a=acciones
      await _profileService.updateProfilePhoto(file.path);

      // Recargar perfil del servidor para obtener la nueva URL definitiva
      await _loadNetworkPhoto();

      state = state.copyWith(
        clearImage: true,
        isUploadingPhoto: false,
        clearError: true,
      );
      return true;
    } catch (e) {
      debugPrint('[ProfileNotifier] Error al actualizar foto de perfil: $e');
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      state = state.copyWith(
        clearImage: true,
        isUploadingPhoto: false,
        error: msg.isNotEmpty ? msg : 'Error al subir la fotografía al servidor.',
      );
      rethrow;
    }
  }

  /// Compatibilidad con llamadas previas: sube la foto directamente al servidor
  Future<void> pickImage({ImageSource source = ImageSource.gallery}) async {
    await changeProfilePhoto(source: source);
  }

  Future<void> removeImage() async {
    state = state.copyWith(clearImage: true, clearNetworkPhoto: true);
    await _cleanLegacyImagePrefs();
  }
}
