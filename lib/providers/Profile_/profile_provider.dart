import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mark_v3/services/mark_api_client.dart';

// Estado inmutable del Perfil
class ProfileState {
  final File? imageFile;
  final String? networkPhotoUrl;
  final bool isLoading;

  const ProfileState({
    this.imageFile,
    this.networkPhotoUrl,
    this.isLoading = false,
  });

  ProfileState copyWith({
    File? imageFile,
    String? networkPhotoUrl,
    bool? isLoading,
    bool clearImage = false,
    bool clearNetworkPhoto = false,
  }) {
    return ProfileState(
      imageFile: clearImage ? null : (imageFile ?? this.imageFile),
      networkPhotoUrl: clearNetworkPhoto
          ? null
          : (networkPhotoUrl ?? this.networkPhotoUrl),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Proveedor global de Perfil gestionado con Riverpod
final profileProvider =
    NotifierProvider<ProfileNotifier, ProfileState>(ProfileNotifier.new);

class ProfileNotifier extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    Future.microtask(() {
      _cleanLegacyImagePrefs();
      _loadNetworkPhoto();
    });
    return const ProfileState();
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
      if (res['ok'] == true && res['colaborador'] is Map<String, dynamic>) {
        final colaborador = res['colaborador'] as Map<String, dynamic>;
        final rawFoto = (colaborador['foto'] ?? '').toString().trim();
        if (rawFoto.isNotEmpty) {
          setNetworkPhotoUrl(rawFoto);
        }
      }
    } catch (e) {
      debugPrint('[ProfileNotifier] Error loading network photo: $e');
    }
  }

  Future<void> pickImage() async {
    try {
      state = state.copyWith(isLoading: true);
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        state = state.copyWith(imageFile: file, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      debugPrint('Error al seleccionar imagen: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> removeImage() async {
    state = state.copyWith(clearImage: true, clearNetworkPhoto: true);
    await _cleanLegacyImagePrefs();
  }
}
