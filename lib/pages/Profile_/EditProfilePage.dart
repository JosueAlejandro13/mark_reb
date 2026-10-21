import 'dart:io';
import 'package:easy_mask/easy_mask.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/Error_/ProfileErrorPage.dart';
import 'package:mark_v3/providers/Profile_/edit_profile_provider.dart';
import 'package:mark_v3/providers/Profile_/profile_provider.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

// Autor: Josue Hernandez
class EditProfilePage extends ConsumerStatefulWidget {
  final String idCollaborator;
  final String idMainAccount;

  const EditProfilePage({
    super.key,
    required this.idCollaborator,
    required this.idMainAccount,
  });

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _mobilPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _employeeNumController = TextEditingController();
  final _idJobTitleController = TextEditingController();

  bool _hasInitializedControllers = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(editProfileProvider.notifier).loadUserData(
            collaboratorId: widget.idCollaborator,
            idMainAccount: widget.idMainAccount,
          );
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _mobilPhoneController.dispose();
    _addressController.dispose();
    _dateOfBirthController.dispose();
    _employeeNumController.dispose();
    _idJobTitleController.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> data) {
    _hasInitializedControllers = true;

    _firstNameController.text =
        (data['firstName'] ?? data['nombre'] ?? '').toString();
    _lastNameController.text =
        (data['LastName'] ?? data['lastName'] ?? data['apellido'] ?? '')
            .toString();
    _emailController.text = (data['email'] ?? data['correo'] ?? '').toString();
    _phoneController.text =
        (data['phone'] ?? data['telefono'] ?? '').toString();
    _mobilPhoneController.text =
        (data['mobilPhone'] ?? data['celular'] ?? '').toString();
    _addressController.text =
        (data['address'] ?? data['direccion'] ?? '').toString();

    final dateOfBirth =
        data['dateBirth'] ?? data['dateOfBirth'] ?? data['nacimiento'];
    if (dateOfBirth != null && dateOfBirth.toString().trim().isNotEmpty) {
      if (dateOfBirth is DateTime) {
        _dateOfBirthController.text =
            DateFormat('yyyy-MM-dd').format(dateOfBirth);
      } else {
        final parsed = DateTime.tryParse(dateOfBirth.toString());
        if (parsed != null) {
          _dateOfBirthController.text = DateFormat('yyyy-MM-dd').format(parsed);
        } else {
          _dateOfBirthController.text = dateOfBirth.toString();
        }
      }
    }

    _employeeNumController.text =
        (data['employeeNum'] ?? data['numEmpleado'] ?? '').toString();
    _idJobTitleController.text =
        (data['idJobTitle'] ?? data['jobTitle'] ?? data['puesto'] ?? '')
            .toString();
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime initialDate;
    try {
      initialDate = _dateOfBirthController.text.isNotEmpty
          ? DateFormat('yyyy-MM-dd').parse(_dateOfBirthController.text)
          : DateTime(2000, 1, 1);
    } catch (_) {
      initialDate = DateTime(2000, 1, 1);
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0886B5), // color principal
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateOfBirthController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final notifier = ref.read(editProfileProvider.notifier);
    final success = await notifier.saveUserData(
      userId: widget.idCollaborator,
      idMainAccount: widget.idMainAccount,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      mobilPhone: _mobilPhoneController.text.trim(),
      address: _addressController.text.trim(),
      dateOfBirth: _dateOfBirthController.text.trim(),
      employeeNum: _employeeNumController.text.trim(),
      idJobTitle: _idJobTitleController.text.trim(),
      newPhotoFile: ref.read(profileProvider).imageFile,
    );

    if (!mounted) return;

    if (success) {
      SnackbarTop.showSuccess(
        context,
        "Los cambios en tu perfil se guardaron correctamente.",
      );
    } else {
      final currentState = ref.read(editProfileProvider);
      if (!currentState.isConnectionError && !currentState.isServerError) {
        SnackbarTop.showError(
          context,
          currentState.error ??
              "No se pudieron guardar los cambios. Verifica tus datos e intenta de nuevo.",
        );
      }
    }
  }

  void _retryLoadUserData() {
    _hasInitializedControllers = false;
    ref.read(editProfileProvider.notifier).loadUserData(
          collaboratorId: widget.idCollaborator,
          idMainAccount: widget.idMainAccount,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<EditProfileState>(editProfileProvider, (previous, next) {
      if (next.userData != null && next.userData != previous?.userData) {
        _populateFields(next.userData!);
      }
    });

    final state = ref.watch(editProfileProvider);

    // Manejo de pantallas de error de conexión y servidor
    if (state.isConnectionError) {
      return ConnectionErrorPage(onRetry: _retryLoadUserData);
    }

    if (state.isServerError) {
      return ServerErrorPage(onRetry: _retryLoadUserData);
    }

    if (state.isUnexpectedError) {
      return ProfileErrorPage(onRetry: _retryLoadUserData);
    }

    // Si los datos ya estaban disponibles antes de construir y no está cargando
    if (state.userData != null &&
        !_hasInitializedControllers &&
        !state.isLoading) {
      _populateFields(state.userData!);
    }

    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isSmallScreen = mediaQuery.size.width < 360;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: state.isLoading
              ? SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12.0 : 16.0,
                    vertical: 8.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, isDisabled: true),
                      const SizedBox(height: 12),
                      AppSkeleton.form(
                        hasHeader: false,
                        sectionsCount: 3,
                        fieldsPerSection: 3,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                )
              : GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  behavior: HitTestBehavior.translucent,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12.0 : 16.0,
                      vertical: 8.0,
                    ),
                    child: AbsorbPointer(
                      absorbing: state.isSaving,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Encabezado Apple
                            _buildHeader(context),
                            const SizedBox(height: 8),

                            // Avatar Hero estilo Apple ID
                            _buildProfileAvatarHero(state),
                            const SizedBox(height: 12),

                            // GRUPO 1: DATOS PERSONALES
                            _buildSectionTitle('DATOS PERSONALES'),
                            _buildAppleGroupContainer(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildFormField(
                                        controller: _firstNameController,
                                        label: 'Nombre',
                                        icon: Icons.person_outline_rounded,
                                        enabled:
                                            (state.userData?['puedeEditar'] ==
                                                    true) &&
                                                !state.isSaving,
                                        validator: (val) =>
                                            val == null || val.trim().isEmpty
                                                ? 'Ingresa tu nombre'
                                                : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildFormField(
                                        controller: _lastNameController,
                                        label: 'Apellido',
                                        icon: Icons.badge_outlined,
                                        enabled:
                                            (state.userData?['puedeEditar'] ==
                                                    true) &&
                                                !state.isSaving,
                                        validator: (val) =>
                                            val == null || val.trim().isEmpty
                                                ? 'Ingresa tu apellido'
                                                : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildFormField(
                                  controller: _emailController,
                                  label: 'Correo Electrónico',
                                  icon: Icons.mail_outline_rounded,
                                  enabled: false,
                                  helperText:
                                      'Vinculado a tu cuenta de acceso corporativa',
                                ),
                              ],
                            ),

                            // GRUPO 2: CONTACTO Y UBICACIÓN
                            _buildSectionTitle('CONTACTO Y DOMICILIO'),
                            _buildAppleGroupContainer(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMaskedPhoneField(
                                        controller: _phoneController,
                                        label: 'Tel. Fijo',
                                        icon: Icons.phone_outlined,
                                        enabled:
                                            (state.userData?['puedeEditar'] ==
                                                    true) &&
                                                !state.isSaving,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildMaskedPhoneField(
                                        controller: _mobilPhoneController,
                                        label: 'Tel. Móvil',
                                        icon: Icons.phone_iphone_rounded,
                                        enabled:
                                            (state.userData?['puedeEditar'] ==
                                                    true) &&
                                                !state.isSaving,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildFormField(
                                  controller: _addressController,
                                  label: 'Dirección Registrada',
                                  icon: Icons.location_on_outlined,
                                  enabled: (state.userData?['puedeEditar'] ==
                                          true) &&
                                      !state.isSaving,
                                  validator: (val) =>
                                      val == null || val.trim().isEmpty
                                          ? 'Ingresa tu dirección'
                                          : null,
                                ),
                              ],
                            ),

                            // GRUPO 3: EMPLEO Y FECHA DE NACIMIENTO
                            _buildSectionTitle('INFORMACIÓN DE EMPLEO'),
                            _buildAppleGroupContainer(
                              children: [
                                _buildDateField(
                                  context,
                                  enabled: (state.userData?['puedeEditar'] ==
                                          true) &&
                                      !state.isSaving,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildFormField(
                                        controller: _employeeNumController,
                                        label: 'No. Empleado',
                                        icon: Icons.tag_rounded,
                                        enabled: false,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildFormField(
                                        controller: _idJobTitleController,
                                        label: 'Puesto / Cargo',
                                        icon: Icons.work_outline_rounded,
                                        enabled: false,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // BOTÓN DE GUARDAR CAMBIOS ESTILO APPLE
                            _buildSaveButton(state),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // --- HEADER SUPERIOR ESTILO APPLE ---
  Widget _buildHeader(BuildContext context, {bool isDisabled = false}) {
    final isSaving = ref.watch(editProfileProvider).isSaving;
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap:
                (isDisabled || isSaving) ? null : () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF0F172A),
                  size: 15,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Editar Perfil',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Actualiza tus datos personales y de contacto',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- AVATAR HERO ESTILO APPLE ID ---
  Widget _buildProfileAvatarHero(EditProfileState state) {
    final profileState = ref.watch(profileProvider);
    final canEdit = (state.userData?['puedeEditar'] == true);

    final rawPhoto = (state.userData?['photo'] ??
            state.userData?['foto'] ??
            profileState.networkPhotoUrl ??
            '')
        .toString()
        .trim();
    final photoUrl = rawPhoto.isNotEmpty
        ? MarkApiClient.instance.resolveAssetUrl(rawPhoto)
        : '';
    final hasPhoto = profileState.imageFile != null || photoUrl.isNotEmpty;

    final initials = (_firstNameController.text.isNotEmpty
            ? _firstNameController.text[0]
            : '') +
        (_lastNameController.text.isNotEmpty
            ? _lastNameController.text[0]
            : '');
    final fullName =
        '${_firstNameController.text} ${_lastNameController.text}'.trim();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (profileState.imageFile != null && canEdit)
                  const SizedBox(width: 44),
                GestureDetector(
                  onTap: () {
                    _showPhotoSourceSheet(
                      context: context,
                      canEdit: canEdit,
                      hasPhoto: hasPhoto,
                      file: profileState.imageFile,
                      networkUrl: photoUrl.isNotEmpty ? photoUrl : null,
                    );
                  },
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFE0F2FE),
                              Color(0xFFBAE6FD),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: Colors.white, width: 3.0),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0284C7).withOpacity(0.18),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              profileState.imageFile != null
                                  ? Image.file(
                                      profileState.imageFile!,
                                      fit: BoxFit.cover,
                                    )
                                  : (photoUrl.isNotEmpty)
                                      ? Image.network(
                                          photoUrl,
                                          fit: BoxFit.cover,
                                          loadingBuilder:
                                              (context, child, progress) {
                                            if (progress == null) return child;
                                            return const Center(
                                              child: SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.0,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<Color>(
                                                          Color(0xFF0284C7)),
                                                ),
                                              ),
                                            );
                                          },
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Center(
                                              child: Text(
                                                initials.isNotEmpty
                                                    ? initials.toUpperCase()
                                                    : '👤',
                                                style: const TextStyle(
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0284C7),
                                                  letterSpacing: -0.5,
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                      : Center(
                                          child: Text(
                                            initials.isNotEmpty
                                                ? initials.toUpperCase()
                                                : '👤',
                                            style: const TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0284C7),
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                        ),
                              if (profileState.isUploadingPhoto)
                                Container(
                                  color: Colors.black.withOpacity(0.45),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (canEdit) {
                            _showPhotoSourceSheet(
                              context: context,
                              canEdit: canEdit,
                              hasPhoto: hasPhoto,
                              file: profileState.imageFile,
                              networkUrl: photoUrl.isNotEmpty ? photoUrl : null,
                            );
                          } else {
                            SnackbarTop.showWarning(
                              context,
                              'Edición de fotografía restringida por permisos corporativos.',
                            );
                          }
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: canEdit
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF0284C7),
                                      Color(0xFF0369A1),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFF475569),
                                      Color(0xFF334155),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.0),
                          ),
                          child: Center(
                            child: Icon(
                              canEdit
                                  ? Icons.camera_alt_rounded
                                  : Icons.lock_rounded,
                              color: Colors.white,
                              size: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (profileState.imageFile != null && canEdit) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => ref.read(profileProvider.notifier).removeImage(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFCA5A5),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFEF4444),
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              fullName.isNotEmpty ? fullName : 'Colaborador',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5.5,
                    height: 5.5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Cuenta Activa · Mark Fleet',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPhotoSourceSheet({
    required BuildContext context,
    required bool canEdit,
    required bool hasPhoto,
    File? file,
    String? networkUrl,
  }) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const Text(
                  'Foto de perfil',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),
                if (hasPhoto)
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.fullscreen_rounded,
                        color: Color(0xFF0284C7),
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Ver fotografía actual',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showImagePreviewDialog(
                        context,
                        file: file,
                        networkUrl: networkUrl,
                      );
                    },
                  ),
                if (canEdit) ...[
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Color(0xFF16A34A),
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Tomar foto con la cámara',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndUploadPhoto(ImageSource.camera);
                    },
                  ),
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.photo_library_rounded,
                        color: Color(0xFF0284C7),
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Elegir de la galería',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndUploadPhoto(ImageSource.gallery);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final notifier = ref.read(profileProvider.notifier);
    try {
      final ok = await notifier.changeProfilePhoto(source: source);
      if (ok && mounted) {
        SnackbarTop.showSuccess(
          context,
          'Fotografía de perfil actualizada en el servidor.',
        );
        ref.read(editProfileProvider.notifier).loadUserData(
              collaboratorId: widget.idCollaborator,
              idMainAccount: widget.idMainAccount,
            );
      }
    } catch (e) {
      if (mounted) {
        SnackbarTop.showError(
          context,
          'Error al subir la fotografía: ${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
  }

  void _showImagePreviewDialog(
    BuildContext context, {
    File? file,
    String? networkUrl,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                child: Container(
                  color: Colors.black.withOpacity(0.85),
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Center(
                child: FractionallySizedBox(
                  widthFactor: 0.75,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: InteractiveViewer(
                          panEnabled: true,
                          minScale: 0.8,
                          maxScale: 4.0,
                          child: file != null
                              ? Image.file(file, fit: BoxFit.cover)
                              : (networkUrl != null && networkUrl.isNotEmpty)
                                  ? Image.network(
                                      networkUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Center(
                                        child: Icon(Icons.broken_image_rounded,
                                            size: 48, color: Colors.white70),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 48,
                right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TÍTULO DE SECCIÓN INSET GROUPED ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // --- CONTENEDOR INSET GROUPED ESTILO APPLE ---
  Widget _buildAppleGroupContainer({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
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

  // --- CAMPO DE FORMULARIO ESTILO APPLE ---
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                  letterSpacing: -0.1,
                ),
              ),
              if (!enabled)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 11, color: Color(0xFF94A3B8)),
                    SizedBox(width: 3),
                    Text(
                      'Fijo',
                      style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          enabled: enabled,
          readOnly: !enabled,
          validator: validator,
          cursorColor: const Color(0xFF0284C7),
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: enabled ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: label,
            hintStyle: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w400),
            prefixIcon: Icon(
              icon,
              size: 17,
              color:
                  enabled ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor:
                enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.04)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF0284C7), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
          ),
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              helperText,
              style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w400),
            ),
          ),
      ],
    );
  }

  // --- CAMPO DE TELÉFONO CON MÁSCARA ---
  Widget _buildMaskedPhoneField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 5),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
              letterSpacing: -0.1,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          enabled: enabled,
          readOnly: !enabled,
          keyboardType: TextInputType.phone,
          cursorColor: const Color(0xFF0284C7),
          inputFormatters: [
            TextInputMask(mask: '(99) 9999-9999', placeholder: '_'),
          ],
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Ingresa número';
            }
            return null;
          },
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: enabled ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: '(00) 0000-0000',
            hintStyle:
                const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
            prefixIcon: Icon(
              icon,
              size: 17,
              color:
                  enabled ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor:
                enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.04)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF0284C7), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
          ),
        ),
      ],
    );
  }

  // --- CAMPO DE FECHA DE NACIMIENTO ---
  Widget _buildDateField(BuildContext context, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 5),
          child: Text(
            'Fecha de Nacimiento',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
              letterSpacing: -0.1,
            ),
          ),
        ),
        TextFormField(
          controller: _dateOfBirthController,
          enabled: enabled,
          readOnly: true,
          onTap: enabled ? () => _selectDate(context) : null,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor seleccione su fecha de nacimiento';
            }
            try {
              final selectedDate = DateTime.parse(value);
              final today = DateTime.now();
              final age = today.year - selectedDate.year;
              final isAdult = (age > 18 ||
                  (age == 18 &&
                      (today.month > selectedDate.month ||
                          (today.month == selectedDate.month &&
                              today.day >= selectedDate.day))));

              if (!isAdult) {
                return 'Debes ser mayor de 18 años para continuar';
              }
            } catch (_) {}
            return null;
          },
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'AAAA-MM-DD',
            hintStyle:
                const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
            prefixIcon: const Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: Color(0xFF0284C7),
            ),
            suffixIcon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF64748B),
              size: 18,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF0284C7), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
          ),
        ),
      ],
    );
  }

  // --- BOTÓN GUARDAR CAMBIOS ESTILO APPLE ---
  Widget _buildSaveButton(EditProfileState state) {
    final bool puedeEditar = state.userData?['puedeEditar'] == true;
    if (!puedeEditar) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: state.isSaving
              ? null
              : const LinearGradient(
                  colors: [
                    Color(0xFF0284C7),
                    Color(0xFF0369A1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          boxShadow: state.isSaving
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withOpacity(0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: state.isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFE2E8F0),
            disabledForegroundColor: const Color(0xFF94A3B8),
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: state.isSaving
              ? Center(
                  child: LoadingAnimationWidget.threeRotatingDots(
                    color: Colors.white,
                    size: 26,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Guardar Cambios',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
