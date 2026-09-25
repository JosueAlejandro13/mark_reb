import 'package:flutter/material.dart';
import 'package:mark_v3/pages/Vehicles_/CirculationCardPage%20.dart';
import 'package:mark_v3/pages/Vehicles_/CreditPage.dart';
import 'package:mark_v3/pages/Vehicles_/InsurancePage.dart';
import 'package:mark_v3/pages/MaintenancePage.dart';
import 'package:mark_v3/pages/Vehicles_/TaxesPage.dart';
import 'package:mark_v3/pages/Vehicles_/VehicleSelecPlanPage.dart';
import 'package:mark_v3/pages/Vehicles_/VerificationsPage.dart';

//Autor: Josue Hernandez
class VehicleDetailPage extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  final String userId;
  final String circulationCardPermission;
  final String taxesPermission;
  final String verificationsPermission;
  final String insurancePermission;
  final String creditPermission;
  final String additionalPermissions;
  final String idMainAccount;
  final String inspectionsPermission;
  final String idCollaborator;

  const VehicleDetailPage(
      {super.key,
      required this.vehicle,
      required this.userId,
      required this.circulationCardPermission,
      required this.taxesPermission,
      required this.verificationsPermission,
      required this.insurancePermission,
      required this.creditPermission,
      required this.additionalPermissions,
      required this.idMainAccount,
      required this.inspectionsPermission,
      required this.idCollaborator});

  @override
  _VehicleDetailPageState createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  late int circulationPermissionValue;
  late int taxesPermissionValue;
  late int verificationsPermissionValue;
  late int insurancePermissionValue;
  late int creditPermissionValue;
  late int inspectionsPermission;

  @override
  void initState() {
    super.initState();
    circulationPermissionValue = int.parse(widget.circulationCardPermission);
    taxesPermissionValue = int.parse(widget.taxesPermission);
    verificationsPermissionValue = int.parse(widget.verificationsPermission);
    insurancePermissionValue = int.parse(widget.insurancePermission);
    creditPermissionValue = int.parse(widget.creditPermission);
    inspectionsPermission = int.parse(widget.inspectionsPermission);

    debugPrint('Permisos recibidos:');
    debugPrint('Tarjeta de Circulación: $circulationPermissionValue');
    debugPrint('Impuestos: $taxesPermissionValue');
    debugPrint('Verificaciones: $verificationsPermissionValue');
    debugPrint('Vehicle being passed: ${widget.vehicle}');
    debugPrint('Inspeccionar: $inspectionsPermission');
    debugPrint('Seguro: $insurancePermissionValue');
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(30.0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Color.fromARGB(255, 0, 0, 0),
              size: 19,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Stack(
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
            padding: const EdgeInsets.all(12.0),
            child: ListView(
              children: [
                Text(
                  'Detalles del vehículo - ${widget.vehicle['make']} ${widget.vehicle['model']}',
                  style: TextStyle( fontSize: screenWidth * 0.050,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                ),
                const SizedBox(height: 16),
                if (hasPermission(inspectionsPermission, 2))
                  _buildMenuOption(
                    context,
                    'Inspeccionar',
                    Icons.search_outlined,
                  ),
                SizedBox(height: 8),
                _buildMenuOption(
                    context, 'Mantenimiento', Icons.build_outlined),
                _buildVehicleManagementTile(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleManagementTile() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    bool hasAdditionalPermissions =
        widget.additionalPermissions == '{"vehicleManagement":true}';

    return hasAdditionalPermissions
        ? ExpansionTile(
            title: Text(
              'Gestión Vehicular',
              style: TextStyle(fontSize: screenWidth * 0.037),
            ),
            children: [
              if (hasPermission(circulationPermissionValue, 2))
                _buildMenuOption(
                  context,
                  'Tarjeta de Circulación',
                  Icons.card_membership_outlined,
                ),
              SizedBox(height: 8),
              if (hasPermission(taxesPermissionValue, 2))
                _buildMenuOption(context, 'Impuestos', Icons.attach_money),
              SizedBox(height: 8),
              if (hasPermission(verificationsPermissionValue, 2))
                _buildMenuOption(context, 'Verificaciones', Icons.checklist),
              SizedBox(height: 8),
              if (hasPermission(insurancePermissionValue, 2))
                _buildMenuOption(context, 'Seguro', Icons.shield),
              SizedBox(height: 8),
              if (hasPermission(creditPermissionValue, 2))
                _buildMenuOption(context, 'Credito', Icons.credit_card)
            ],
          )
        : const SizedBox.shrink();
  }

  Widget _buildMenuOption(BuildContext context, String title, IconData icon) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Card(
      elevation: 6,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide.none,
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(screenWidth * 0.017),
          decoration: BoxDecoration(
              color: const Color(0xFF0886B5).withOpacity(0.1),
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: const Color(0xFF0886B5)),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: screenWidth * 0.034,
          ),
        ),
        trailing: const Icon(Icons.navigate_next, color: Colors.black),
        onTap: () {
          _handleMenuSelection(title);
        },
      ),
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'Inspeccionar':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VehicleSelecPlanPage(
              vehicle: widget.vehicle,
              userId: widget.userId,
              idCollaborator: widget.idCollaborator,
              idMainAccount: widget.idMainAccount,
            ),
          ),
        );

        break;
      case 'Tarjeta de Circulación':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CirculationCardPage(
              vehicle: widget.vehicle,
              circulationCardPermission: widget.circulationCardPermission,
              idMainAccount: widget.idMainAccount,
              userId: widget.userId,
            ),
          ),
        );
        break;
      case 'Mantenimiento':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MaintenancePage(
              vehicle: widget.vehicle,
            ),
          ),
        );
        break;
      case 'Impuestos':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaxesPage(
              vehicle: widget.vehicle,
              taxesPermission: widget.taxesPermission,
              circulationCardPermission: widget.circulationCardPermission,
              idMainAccount: widget.idMainAccount,
              userId: widget.userId,
            ),
          ),
        );
        break;
      case 'Verificaciones':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationsPage(
              vehicle: widget.vehicle,
              verificationsPermission: widget.verificationsPermission,
              idMainAccount: widget.idMainAccount,
              userId: widget.userId,
            ),
          ),
        );
        break;
      case 'Seguro':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InsurancePage(
              vehicle: widget.vehicle,
              insurancePermission: widget.insurancePermission,
              idMainAccount: widget.idMainAccount,
              userId: widget.userId,
            ),
          ),
        );
        break;
      case 'Credito':
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => Creditpage(
                    vehicle: widget.vehicle,
                    creditPermission: widget.creditPermission,
                    idMainAccount: widget.idMainAccount,
                    userId: widget.userId,
                  )),
        );
      default:
        break;
    }
  }

  bool hasPermission(int permissionValue, int actionBit) {
    return (permissionValue & actionBit) == actionBit ||
        (permissionValue & 1) == 1;
  }
}
