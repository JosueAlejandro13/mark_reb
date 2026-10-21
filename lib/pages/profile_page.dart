import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'Profile_/EditProfilePage.dart';
import 'Profile_/change_password_page.dart';
import 'Profile_/LicenseDetailsPage.dart';
import 'package:mark_v3/providers/Profile_/profile_provider.dart';
import 'package:mark_v3/providers/Profile_/edit_profile_provider.dart';
import 'package:mark_v3/providers/Routes_/routes_provider.dart';
import 'package:mark_v3/services/ConnectionRoutes_/driver_local_db.dart';
import 'package:mark_v3/providers/Notification_/notifications_provider.dart';
import 'package:mark_v3/providers/Home_/home_provider.dart';
import 'package:mark_v3/pages/Auth_/login_page.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mark_v3/services/mark_api_client.dart';

// Autor: Josue Hernandez
class ProfilePage extends ConsumerWidget {
  final String usuario;
  final String userId;
  final String idCollaborator;
  final String idMainAccount;
  final String email;
  final String password;
  final String uuid;
  final String creationId;

  const ProfilePage({
    super.key,
    required this.usuario,
    required this.userId,
    required this.idCollaborator,
    required this.idMainAccount,
    required this.email,
    required this.password,
    this.uuid = '',
    this.creationId = '',
  });

  String _getFormattedDisplayName() {
    String raw = usuario.trim();
    if (raw.contains('@')) {
      raw = raw.split('@').first;
    }
    if (raw.isNotEmpty) {
      return raw[0].toUpperCase() + raw.substring(1);
    }
    return 'Colaborador';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final profileNotifier = ref.read(profileProvider.notifier);

    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenWidth < 360;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        // Fondo gris suave estilo iOS System Grouped Background
        backgroundColor: const Color(0xFFF2F4F7),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 14.0 : 18.0,
              vertical: 10.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Encabezado Apple (Large Title) ───────────────────
                _buildAnimatedItem(_buildAppleHeader(), 0),
                const SizedBox(height: 14),

                // ── 2. Tarjeta de Usuario Estilo Apple ID (Blanca y Elegante) ──
                _buildAnimatedItem(
                  _buildAppleUserProfileCard(
                    context,
                    profileState,
                    profileNotifier,
                    ref,
                  ),
                  1,
                ),
                const SizedBox(height: 22),

                // ── 3. Sección Cuenta y Credenciales (Apple Inset Grouped) ──
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAnimatedItem(
                      _buildAppleSectionHeader(
                        title: 'CUENTA Y CREDENCIALES',
                        badge: '3 OPCIONES',
                      ),
                      2,
                    ),
                    const SizedBox(height: 7),
                    _buildAnimatedItem(
                      _buildAppleGroupedCard(
                        children: [
                          // Datos Personales
                          _buildAppleListTile(
                            icon: Icons.person_rounded,
                            iconGradient: const [
                              Color(0xFF0284C7),
                              Color(0xFF38BDF8),
                            ],
                            title: 'Datos Personales',
                            subtitle:
                                'Nombre, teléfono y datos de contacto',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditProfilePage(
                                    idCollaborator: idCollaborator,
                                    idMainAccount: idMainAccount,
                                  ),
                                ),
                              );
                            },
                          ),
                          // Licencia de Conducir
                          _buildAppleListTile(
                            icon: Icons.badge_rounded,
                            iconGradient: const [
                              Color(0xFF0369A1),
                              Color(0xFF0284C7),
                            ],
                            title: 'Licencia de Conducir',
                            subtitle:
                                'Estatus, vigencia y tipo de documento',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      LicenseDetailsPage(
                                    idCollaborator: idCollaborator,
                                  ),
                                ),
                              );
                            },
                          ),
                          // Cambiar Contraseña
                          _buildAppleListTile(
                            icon: Icons.lock_rounded,
                            iconGradient: const [
                              Color(0xFF0F172A),
                              Color(0xFF1E3A8A),
                            ],
                            title: 'Cambiar Contraseña',
                            subtitle:
                                'Modifica tu clave de acceso a la cuenta',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChangePasswordPage(
                                    usuario: usuario,
                                    userId: userId,
                                    idMainAccount: idMainAccount,
                                  ),
                                ),
                              );
                            },
                            isLast: true,
                          ),
                        ],
                      ),
                      3,
                    ),
                  ],
                ),
                _buildAppleSectionFooter(
                  'Mantén tus datos y credenciales oficiales actualizados para el registro operativo.',
                ),
                const SizedBox(height: 20),

                // ── 4. Botón Cerrar Sesión Estilo Apple ──────────────────
                _buildAnimatedItem(_buildAppleLogoutButton(context, ref), 4),

                // Margen inferior para la barra de navegación flotante
                const SizedBox(height: 95),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 1. ENCABEZADO APPLE (LARGE TITLE) ───────────────────────────────────────
  Widget _buildAppleHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mi Perfil',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.6,
            height: 1.1,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Administra tu información personal y credenciales',
          style: TextStyle(
            fontSize: 12.5,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w400,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }

  // ── 2. TARJETA DE USUARIO APPLE ID (LIMPIA, BLANCA Y ULTRA-PREMIUM) ─────────
  Widget _buildAppleUserProfileCard(
    BuildContext context,
    ProfileState state,
    ProfileNotifier notifier,
    WidgetRef ref,
  ) {
    final clientSession = MarkApiClient.instance.currentSession;
    final editUserData = ref.watch(editProfileProvider).userData;
    final canEdit = (editUserData?['puedeEditar'] == true) ||
        MarkApiClient.instance.flota.can('colaboradores', 'editar');

    String realName = (editUserData?['name'] ??
            editUserData?['nombre'] ??
            clientSession?.usuario.nombre ??
            clientSession?.chofer.nombre ??
            usuario)
        .toString()
        .trim();
    String parsedName = '';

    if (realName.isNotEmpty) {
      final parts = realName.trim().split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        String first =
            parts[0][0].toUpperCase() + parts[0].substring(1).toLowerCase();
        String last = '';
        if (parts.length == 2) {
          last = parts[1];
        } else if (parts.length == 3) {
          last = parts[1];
        } else if (parts.length >= 4) {
          last = parts[2];
        }

        if (last.isNotEmpty) {
          last = last[0].toUpperCase() + last.substring(1).toLowerCase();
          parsedName = '$first $last';
        } else {
          parsedName = first;
        }
      }
    }

    final displayName =
        parsedName.isNotEmpty ? parsedName : _getFormattedDisplayName();

    String getInitials(String name) {
      if (name.isEmpty) return 'US';
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length > 1) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }

    void showImageDialog(
      BuildContext context, {
      dynamic imageFile,
      String? networkUrl,
    }) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    color: Colors.black87,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                Center(
                  child: FractionallySizedBox(
                    widthFactor:
                        0.65, // No tan grande, 65% del ancho de la pantalla
                    child: AspectRatio(
                      aspectRatio: 1, // Cuadrado perfecto para hacerlo círculo
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.8,
                            maxScale: 4.0,
                            child: imageFile != null
                                ? Image.file(
                                    imageFile,
                                    fit: BoxFit.cover,
                                  )
                                : (networkUrl != null && networkUrl.isNotEmpty)
                                    ? Image.network(
                                        networkUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Center(
                                          child: Icon(
                                              Icons.broken_image_rounded,
                                              size: 40,
                                              color: Colors.white70),
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
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0).withOpacity(0.85),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar (con visor al tocar, sin modal ni icono de cámara)
                  GestureDetector(
                    onTap: () {
                      final hasPhoto = state.imageFile != null ||
                          (state.networkPhotoUrl != null &&
                              state.networkPhotoUrl!.isNotEmpty);
                      if (hasPhoto) {
                        showImageDialog(
                          context,
                          imageFile: state.imageFile,
                          networkUrl: state.networkPhotoUrl,
                        );
                      }
                    },
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF1F5F9),
                        border: Border.all(
                          color: Colors.white,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0A1E34).withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            state.imageFile != null
                                ? Image.file(
                                    state.imageFile!,
                                    fit: BoxFit.cover,
                                  )
                                : (state.networkPhotoUrl != null &&
                                        state.networkPhotoUrl!.isNotEmpty)
                                    ? Image.network(
                                        state.networkPhotoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: const Color(0xFFDDF0FF),
                                          child: Center(
                                            child: Text(
                                              getInitials(displayName),
                                              style: const TextStyle(
                                                color: Color(0xFF0284C7),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 22,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: const Color(0xFFDDF0FF),
                                        child: Center(
                                          child: Text(
                                            getInitials(displayName),
                                            style: const TextStyle(
                                              color: Color(0xFF0284C7),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 22,
                                            ),
                                          ),
                                        ),
                                      ),
                            if (state.isUploadingPhoto)
                              Container(
                                color: Colors.black.withOpacity(0.45),
                                child: const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
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
                  ),
                  const SizedBox(width: 14),

                  // Información de Usuario
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (editUserData?['email'] ??
                                  editUserData?['correo'] ??
                                  editUserData?['correoUsuario'] ??
                                  email)
                              .toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Pill de estado estilo Apple
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF0284C7),
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Colaborador Verificado',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0369A1),
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
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
    );
  }

  // ── 3. ENCABEZADO DE SECCIÓN APPLE ──────────────────────────────────────────
  Widget _buildAppleSectionHeader({
    required String title,
    required String badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0).withOpacity(0.7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Pie de sección estilo Apple HIG
  Widget _buildAppleSectionFooter(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, top: 6, right: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF94A3B8),
          height: 1.25,
        ),
      ),
    );
  }

  // ── 4. CONTENEDOR AGRUPADO INSET APPLE ──────────────────────────────────────
  Widget _buildAppleGroupedCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE2E8F0).withOpacity(0.85),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  // ── 5. FILA DE LISTA APPLE CON SQUIRCLE Y CHEVRON ───────────────────────────
  Widget _buildAppleListTile({
    required IconData icon,
    required List<Color> iconGradient,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0xFF0284C7).withOpacity(0.06),
        highlightColor: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Ícono Squircle con degradado azul
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: iconGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: iconGradient.first.withOpacity(0.26),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Textos del ítem
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Chevron de navegación iOS
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFCBD5E1),
                    size: 20,
                  ),
                ],
              ),
            ),
            // Línea divisoria hairline identada estilo iOS
            if (!isLast)
              const Divider(
                height: 1,
                thickness: 0.6,
                indent: 66,
                endIndent: 0,
                color: Color(0xFFF1F5F9),
              ),
          ],
        ),
      ),
    );
  }

  // ── 7. BOTÓN CERRAR SESIÓN ESTILO APPLE (DESTRUCTIVE INSET) ───────────────────
  Widget _buildAppleLogoutButton(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFFEE2E8),
            width: 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showLogoutDialog(context, ref),
          splashColor: const Color(0xFFEF4444).withOpacity(0.08),
          highlightColor: const Color(0xFFFEF2F2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                // Squircle rojo de alerta
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Textos
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cerrar Sesión',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEF4444),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Finalizar la sesión activa en este dispositivo',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF94A3B8),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFFFCA5A5),
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext outerContext, WidgetRef ref) {
    bool isLoggingOut = false;
    showDialog(
      context: outerContext,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              title: const Row(
                children: [
                  Icon(Icons.logout_rounded,
                      color: Color(0xFFEF4444), size: 21),
                  SizedBox(width: 9),
                  Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              content: const Text(
                '¿Estás seguro de que deseas cerrar sesión? Tendrás que iniciar sesión nuevamente con tus credenciales.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF475569),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancelar',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
                LoadingActionButton(
                  text: 'Cerrar Sesión',
                  isLoading: isLoggingOut,
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  height: 38,
                  width: 130,
                  borderRadius: 10,
                  fontSize: 12.5,
                  onPressed: () async {
                    setState(() {
                      isLoggingOut = true;
                    });

                    // Borrar el token de sesión segura y sesión de rutas al cerrar sesión
                    const secureStorage = FlutterSecureStorage();
                    await secureStorage.deleteAll(); // Borra full

                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear(); // Limpiar token y variable isDemoUser

                    // Cerrar la base de datos local SQLite del chofer
                    await DriverLocalDb.instance.close();

                    // Limpiar sesión en MarkApiClient para evitar fuga de tokens entre cuentas
                    MarkApiClient.instance.clearSession();

                    ref.invalidate(profileProvider);
                    ref.invalidate(editProfileProvider);
                    ref.invalidate(routesProvider);
                    ref.invalidate(notificationsProvider);
                    ref.invalidate(homeProvider);

                    if (outerContext.mounted) {
                      Navigator.of(outerContext).pushAndRemoveUntil(
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => const LoginPage(),
                          transitionsBuilder: (_, animation, __, child) =>
                              FadeTransition(opacity: animation, child: child),
                        ),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── ANIMACIÓN SUAVE STAGGERED ─────────────────────────────────────────────
  Widget _buildAnimatedItem(Widget child, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 260 + (index * 40)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (1.0 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
