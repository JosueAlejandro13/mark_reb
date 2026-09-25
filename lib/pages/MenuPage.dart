import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mark_v3/pages/MyVehicle_/MyVehiclePage.dart';
import 'package:mark_v3/pages/login_page.dart';
import 'package:mark_v3/pages/Routes_/routes_page.dart';
import 'package:mark_v3/pages/Vehicles_/vehicles_page.dart';
import 'package:mark_v3/services/database_service.dart';
import 'package:mark_v3/widgets/single_tap_button.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class MenuPage extends StatelessWidget {
  final String idCollaborator;
  final String circulationCardPermission;
  final String taxesPermission;
  final String verificationsPermission;
  final String insurancePermission;
  final String creditPermission;
  final String userId;
  final String additionalPermissions;
  final String inspectionsPermission;
  final String uuid;
  final String idMainAccount;
  final String creationId;

  const MenuPage({
    super.key,
    required this.idCollaborator,
    required this.circulationCardPermission,
    required this.taxesPermission,
    required this.verificationsPermission,
    required this.insurancePermission,
    required this.creditPermission,
    required this.userId,
    required this.inspectionsPermission,
    required this.additionalPermissions,
    required this.uuid,
    required this.idMainAccount,
    required this.creationId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final screenHeight = constraints.maxHeight;
          final screenWidth = constraints.maxWidth;

          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(seconds: 5),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.fromARGB(255, 250, 250, 250),
                      Color.fromARGB(255, 205, 240, 255)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(screenWidth * 0.03),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Menú',
                      style: TextStyle(
                        fontSize: screenWidth * 0.050,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.only(top: screenHeight * 0.02),
                        children: [
                          buildAnimatedItem(
                              _buildCardItem(
                                context,
                                icon: Icons.directions_car,
                                title: 'Mi Vehículo',
                                subtitle: 'Ver detalles del vehículo',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MyVehiclePage(
                                          idCollaborator: idCollaborator,
                                          idMainAccount: idMainAccount,
                                          inspectionsPermission:
                                              inspectionsPermission,
                                          userId: userId),
                                    ),
                                  );
                                },
                              ),
                              0),
                          SizedBox(height: screenWidth * 0.025),
                          buildAnimatedItem(
                              _buildCardItemAdmin(
                                context,
                                imagePath: 'assets/carrs.png',
                                title: 'Administrar Vehículos',
                                subtitle: 'Gestiona tu flota de vehículos',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => VehiclesPage(
                                        circulationCardPermission:
                                            circulationCardPermission,
                                        taxesPermission: taxesPermission,
                                        inspectionsPermission:
                                            inspectionsPermission,
                                        idCollaborator: idCollaborator,
                                        verificationsPermission:
                                            verificationsPermission,
                                        insurancePermission:
                                            insurancePermission,
                                        creditPermission: creditPermission,
                                        idMainAccount: idMainAccount,
                                        additionalPermissions:
                                            additionalPermissions,
                                        userId: userId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              1),
                          SizedBox(height: screenWidth * 0.025),
                          buildAnimatedItem(
                              _buildCardItem(
                                context,
                                icon: FontAwesomeIcons.route.data,
                                title: 'Rutas',
                                subtitle: 'Planifica y revisa tus trayectos',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RoutesPage(
                                          idCollaborator: idCollaborator,
                                          idMainAccount: idMainAccount),
                                    ),
                                  );
                                },
                              ),
                              2),
                          SizedBox(height: screenWidth * 0.025),
                          buildAnimatedItem(
                              _buildCardItem(
                                context,
                                icon: Icons.logout,
                                title: 'Cerrar Sesión',
                                onTap: () {
                                  _showLogoutDialog(context);
                                },
                              ),
                              3),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCardItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required Function() onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Card(
      color: Colors.white,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.035),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(screenWidth * 0.016),
                decoration: BoxDecoration(
                  color: const Color(0xFF0886B5).withOpacity(0.1),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: Color(0xFF0886B5),
                ),
              ),
              SizedBox(width: screenWidth * 0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: screenWidth * 0.032,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (subtitle != null) // Solo muestra si hay subtítulo
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: screenWidth * 0.028,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.navigate_next, color: Colors.black),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardItemAdmin(
    BuildContext context, {
    required String imagePath,
    required String title,
    String? subtitle,
    required Function() onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Card(
      color: Colors.white,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.035),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(screenWidth * 0.016),
                decoration: BoxDecoration(
                    color: const Color(0xFF0886B5).withOpacity(0.1),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(8)),
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Color(0xFF0886B5),
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    imagePath,
                    width: 22,
                    height: 22,
                  ),
                ),
              ),
              SizedBox(width: screenWidth * 0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: screenWidth * 0.032,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (subtitle != null) // Solo muestra si hay subtítulo
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: screenWidth * 0.028,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.navigate_next, color: Colors.black),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext outerContext) {
    final screenHeight = MediaQuery.of(outerContext).size.height;
    final screenWidth = MediaQuery.of(outerContext).size.width;
    showDialog(
      context: outerContext,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          titlePadding: EdgeInsets.zero,
          title: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 23, left: 24, right: 24),
                child: Row(
                  children: [
                    const Icon(Icons.exit_to_app,
                        color: Colors.black, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Cierre de Sesión',
                      style: TextStyle(fontSize: screenWidth * 0.037),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 246, 246, 246),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: screenHeight * 0.040,
                    height: screenHeight * 0.040,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: screenHeight * 0.025,
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.black),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          content: Text('¿Estás seguro de que deseas cerrar sesión?',
              style: TextStyle(fontSize: screenWidth * 0.033)),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                elevation: 6,
                shadowColor: Colors.grey.withOpacity(0.3),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancelar',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
            ),
            SingleTapButton(
              onPressed: () async {
                DatabaseService dbService = DatabaseService();
                await dbService.updateAccessRecord(int.parse(creationId), uuid);
                
                // Borrar el token de sesión segura al cerrar sesión
                const secureStorage = FlutterSecureStorage();
                await secureStorage.delete(key: 'session_token');

                Navigator.of(context).pop();

                Navigator.of(outerContext).pushAndRemoveUntil(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const LoginPage(),
                    transitionsBuilder: (_, animation, __, child) =>
                        FadeTransition(opacity: animation, child: child),
                  ),
                  (route) => false, // eliminar todo el stack anterior
                );
              },
              child: Text('Cerrar Sesión',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
            ),
          ],
        );
      },
    );
  }

  Widget buildAnimatedItem(Widget child, int index) {
    return TweenAnimationBuilder(
      tween: Tween<Offset>(begin: Offset(1, 0), end: Offset.zero),
      duration: Duration(milliseconds: 500 + index * 100),
      curve: Curves.easeInOut,
      builder: (context, Offset offset, child) {
        return Transform.translate(
          offset: offset * 30,
          child: Opacity(
            opacity: 1.0 - offset.dx.abs(),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
