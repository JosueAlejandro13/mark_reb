import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'Profile_/EditProfilePage.dart';
import 'Profile_/change_password_page.dart';
import 'Profile_/LicenseDetailsPage.dart';
import 'package:mark_v3/providers/profile_provider.dart';
import 'package:mark_v3/pages/login_page.dart';
import 'package:mark_v3/services/database_service.dart';
import 'package:mark_v3/widgets/single_tap_button.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado de la Pantalla
              _buildTopHeader(),
              const SizedBox(height: 12),

              // Tarjeta Hero Principal de Perfil (Avatar + Info + Badges)
              _buildHeroProfileCard(context, profileState, profileNotifier),
              const SizedBox(height: 16),

              // SECCIÓN 1: GESTIÓN DE CUENTA Y DOCUMENTOS
              _buildSectionTitle(
                title: 'Cuenta y Credenciales',
                subtitle: 'Información personal y documentos de operación',
              ),
              const SizedBox(height: 9),
              _buildActionCard(
                icon: Icons.person_outline_rounded,
                iconColor: const Color(0xFF0886B5),
                iconBg: const Color(0xFFE0F2FE),
                title: 'Datos Personales',
                subtitle: 'Actualiza tu nombre, teléfono y datos de contacto',
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
              const SizedBox(height: 9),
              _buildActionCard(
                icon: Icons.badge_rounded,
                iconColor: const Color(0xFFEA580C),
                iconBg: const Color(0xFFFFF7ED),
                title: 'Licencia de Conducir',
                subtitle: 'Consulta el estatus, vigencia y tipo de licencia',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LicenseDetailsPage(
                        idCollaborator: idCollaborator,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 9),
              _buildActionCard(
                icon: Icons.lock_outline_rounded,
                iconColor: const Color(0xFF7C3AED),
                iconBg: const Color(0xFFF3E8FF),
                title: 'Cambiar Contraseña',
                subtitle: 'Modifica tu clave de acceso a la plataforma',
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
              ),
              const SizedBox(height: 16),

              // SECCIÓN 2: DETALLES DE IDENTIFICACIÓN
              _buildSectionTitle(
                title: 'Información de Cuenta',
                subtitle: 'Identificadores asignados en el sistema',
              ),
              const SizedBox(height: 9),
              _buildAccountDetailsCard(),
              const SizedBox(height: 16),

              // BOTÓN CERRAR SESIÓN
              _buildLogoutButton(context),
              const SizedBox(height: 85),
            ],
          ),
        ),
      ),
    );
  }

  // --- TOP HEADER ---
  Widget _buildTopHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mi Perfil',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          'Administra tu información personal y credenciales',
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.grey[600],
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // --- HERO PROFILE CARD ---
  Widget _buildHeroProfileCard(
    BuildContext context,
    ProfileState state,
    ProfileNotifier notifier,
  ) {
    final displayName = _getFormattedDisplayName();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar con botón de cámara integrado
              GestureDetector(
                onTap: () => notifier.pickImage(),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE0F2FE),
                        border: Border.all(
                          color: const Color(0xFF0886B5).withOpacity(0.25),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: state.imageFile != null
                            ? Image.file(
                                state.imageFile!,
                                fit: BoxFit.cover,
                              )
                            : Image.asset(
                                'assets/person.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  color: Color(0xFF0886B5),
                                  size: 32,
                                ),
                              ),
                      ),
                    ),
                    // Badge de edición de foto
                    Container(
                      padding: const EdgeInsets.all(4.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0886B5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

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
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email.isNotEmpty ? email : 'Sin correo registrado',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 7),

                    // Badges de Rol y Estado
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                color: Color(0xFF16A34A),
                                size: 11,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Colaborador Activo',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF15803D),
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
            ],
          ),

          // Botón opcional para quitar imagen personalizada
          if (state.imageFile != null) ...[
            const SizedBox(height: 10),
            Divider(color: Colors.grey[100], height: 1),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => notifier.removeImage(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 14, color: Colors.red[600]),
                    const SizedBox(width: 5),
                    Text(
                      'Restablecer foto predeterminada',
                      style: TextStyle(
                        color: Colors.red[600],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- TITULO DE SECCIÓN ---
  Widget _buildSectionTitle({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // --- TARJETA DE ACCIÓN ESTILO PREMIUM ---
  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Contenedor de Icono Squircle
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                ),
                const SizedBox(width: 10),

                // Textos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Chevron
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey[500],
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- TARJETA DE DETALLES DE CUENTA ---
  Widget _buildAccountDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(
            label: 'ID de Colaborador',
            value: '#$idCollaborator',
            icon: Icons.badge_outlined,
          ),
          Divider(color: Colors.grey[100], height: 14),
          _buildInfoRow(
            label: 'Cuenta Principal',
            value: '#$idMainAccount',
            icon: Icons.business_outlined,
          ),
          Divider(color: Colors.grey[100], height: 14),
          _buildInfoRow(
            label: 'Identificador de Usuario',
            value: '#$userId',
            icon: Icons.tag_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  // --- BOTÓN Y DIÁLOGO DE CERRAR SESIÓN ---
  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showLogoutDialog(context),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 11, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 18),
                SizedBox(width: 8),
                Text(
                  'Cerrar Sesión',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext outerContext) {
    showDialog(
      context: outerContext,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 22),
              SizedBox(width: 10),
              Text(
                'Cerrar Sesión',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: const Text(
            '¿Estás seguro de que deseas cerrar sesión?',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
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
              child: const Text('Cancelar',
                  style:
                      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
            SingleTapButton(
              onPressed: () async {
                if (creationId.isNotEmpty && uuid.isNotEmpty) {
                  try {
                    DatabaseService dbService = DatabaseService();
                    await dbService.updateAccessRecord(
                        int.parse(creationId), uuid);
                  } catch (e) {
                    debugPrint('Error actualizando registro de acceso: $e');
                  }
                }

                // Borrar el token de sesión segura al cerrar sesión
                const secureStorage = FlutterSecureStorage();
                await secureStorage.delete(key: 'session_token');

                if (context.mounted) {
                  Navigator.of(context).pop();
                }

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
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
