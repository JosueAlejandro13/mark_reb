import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Estado inmutable del Perfil
class ProfileState {
  final File? imageFile;
  final bool isLoading;

  const ProfileState({
    this.imageFile,
    this.isLoading = false,
  });

  ProfileState copyWith({
    File? imageFile,
    bool? isLoading,
    bool clearImage = false,
  }) {
    return ProfileState(
      imageFile: clearImage ? null : (imageFile ?? this.imageFile),
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
    Future.microtask(() => _loadImage());
    return const ProfileState();
  }

  Future<void> _loadImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64Image = prefs.getString('image');

      if (base64Image != null && base64Image.isNotEmpty) {
        final bytes = base64Decode(base64Image);
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/image.png');
        await file.writeAsBytes(bytes);
        state = state.copyWith(imageFile: file);
      }
    } catch (e) {
      debugPrint('Error al cargar imagen de perfil: $e');
    }
  }

  Future<void> pickImage() async {
    try {
      state = state.copyWith(isLoading: true);
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final bytes = await pickedFile.readAsBytes();
        final base64Image = base64Encode(bytes);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('image', base64Image);

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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('image');
      state = state.copyWith(clearImage: true);
    } catch (e) {
      debugPrint('Error al remover imagen: $e');
    }
  }
}
