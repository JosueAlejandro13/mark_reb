import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'Profile_/EditProfilePage.dart';
import 'Profile_/change_password_page.dart';
import 'Profile_/LicenseDetailsPage.dart';
import 'package:mark_v3/providers/profile_provider.dart';

// Autor: Josue Hernandez
class ProfilePage extends ConsumerWidget {
  final String usuario;
  final String userId;
  final String idCollaborator;
  final String idMainAccount;
  final String email;
  final String password;

  const ProfilePage({
    super.key,
    required this.usuario,
    required this.userId,
    required this.idCollaborator,
    required this.idMainAccount,
    required this.email,
    required this.password,
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
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado de la Pantalla
              _buildTopHeader(),
              const SizedBox(height: 20),

              // Tarjeta Hero Principal de Perfil (Avatar + Info + Badges)
              _buildHeroProfileCard(context, profileState, profileNotifier),
              const SizedBox(height: 24),

              // SECCIÓN 1: GESTIÓN DE CUENTA Y DOCUMENTOS
              _buildSectionTitle(
                title: 'Cuenta y Credenciales',
                subtitle: 'Información personal y documentos de operación',
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 24),

              // SECCIÓN 2: DETALLES DE IDENTIFICACIÓN
              _buildSectionTitle(
                title: 'Información de Cuenta',
                subtitle: 'Identificadores asignados en el sistema',
              ),
              const SizedBox(height: 12),
              _buildAccountDetailsCard(),
              const SizedBox(height: 30),
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
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Administra tu información personal y credenciales',
          style: TextStyle(
            fontSize: 13,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE0F2FE),
                        border: Border.all(
                          color: const Color(0xFF0886B5).withOpacity(0.25),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
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
                                  size: 40,
                                ),
                              ),
                      ),
                    ),
                    // Badge de edición de foto
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0886B5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

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
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email.isNotEmpty ? email : 'Sin correo registrado',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Badges de Rol y Estado
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                color: Color(0xFF16A34A),
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Colaborador Activo',
                                style: TextStyle(
                                  fontSize: 10.5,
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
            const SizedBox(height: 14),
            Divider(color: Colors.grey[100], height: 1),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => notifier.removeImage(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 16, color: Colors.red[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Restablecer foto predeterminada',
                      style: TextStyle(
                        color: Colors.red[600],
                        fontSize: 12,
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
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Contenedor de Icono Squircle
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Icon(icon, color: iconColor, size: 21),
                  ),
                ),
                const SizedBox(width: 14),

                // Textos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),

                // Chevron
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey[500],
                    size: 20,
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          _buildInfoRow(
            label: 'ID de Colaborador',
            value: '#$idCollaborator',
            icon: Icons.badge_outlined,
          ),
          Divider(color: Colors.grey[100], height: 20),
          _buildInfoRow(
            label: 'Cuenta Principal',
            value: '#$idMainAccount',
            icon: Icons.business_outlined,
          ),
          Divider(color: Colors.grey[100], height: 20),
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
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
