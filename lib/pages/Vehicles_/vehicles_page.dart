import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/pages/Error_/VehicleErrorPage.dart';
import 'package:mark_v3/pages/Vehicles_/VehicleDetailPage.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';

//Autor: Josue Hernandez
class VehiclesPage extends StatefulWidget {
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

  const VehiclesPage(
      {super.key,
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
  _VehiclesPageState createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  final VehiclesconService dbService = VehiclesconService();
  List<Map<String, dynamic>> vehicles = [];
  bool _isLoading = false;
  late String userId;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    userId = widget.userId;
    debugPrint('ID del usuario pasado a VehiclesPage: $userId');
    _loadVehicles();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    if (_isDisposed || !mounted) return;
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      List<Map<String, dynamic>> vehiculos =
          await dbService.obtenerVehiculosPorUsuario(
              widget.userId.toString(), widget.idMainAccount.toString());

      setState(() {
        vehicles = vehiculos;
        debugPrint('Número de vehículos cargados: ${vehicles.length}');
      });

      if (vehicles.isEmpty) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => VehicleErrorPage(
                onRetry: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => widget),
                  );
                },
              ),
            ),
          );
        }
      }
    } on SocketException catch (_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ConnectionErrorPage(
              onRetry: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => widget),
                );
              },
            ),
          ),
        );
      }
    } on TimeoutException catch (_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ServerErrorPage(
              onRetry: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => widget),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => VehicleErrorPage(
              onRetry: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => widget),
                );
              },
            ),
          ),
        );
      }
      debugPrint('Error al cargar vehículos: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    await _loadVehicles();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    if (_isLoading) {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(30.0),
          child: AppBar(
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
                size: 19,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        body: Center(
            child: Lottie.asset(
          'assets/loading.json',
          width: screenWidth * 0.2,
          height: screenHeight * 0.2,
          repeat: true,
        )),
      );
    }

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
      body: RefreshIndicator(
        color: Colors.black,
        onRefresh: _refreshData,
        child: Stack(
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
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Vehículos registrados',
                    style: TextStyle(
                      fontSize: screenWidth * 0.050,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: vehicles.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VehicleDetailPage(
                                  vehicle: vehicles[index],
                                  additionalPermissions:
                                      widget.additionalPermissions,
                                  userId: widget.userId,
                                  circulationCardPermission:
                                      widget.circulationCardPermission,
                                  taxesPermission: widget.taxesPermission,
                                  verificationsPermission:
                                      widget.verificationsPermission,
                                  insurancePermission:
                                      widget.insurancePermission,
                                  creditPermission: widget.creditPermission,
                                  idMainAccount: widget.idMainAccount,
                                  inspectionsPermission:
                                      widget.inspectionsPermission,
                                  idCollaborator: widget.idCollaborator),
                            ),
                          );
                        },
                        child: buildAnimatedItem(
                          Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 16),
                            elevation: 6,
                            color: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: 120,
                                    width: 100,
                                    child: Image.asset(
                                      'assets/car.jpg',
                                      fit: BoxFit.contain,
                                      colorBlendMode: BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          vehicles[index]['placas'],
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: screenWidth * 0.035),
                                          softWrap: true,
                                        ),
                                        Text(
                                          'VIN: ${vehicles[index]['vin'] ?? 'N/A'}\n'
                                          'Marca: ${vehicles[index]['make'] ?? 'N/A'}\n'
                                          'Modelo: ${vehicles[index]['model'] ?? 'N/A'}\n'
                                          'Año: ${vehicles[index]['year'] ?? 'N/A'}\n'
                                          'Departamento: ${vehicles[index]['dep'] ?? 'N/A'}',
                                          style: TextStyle(
                                              fontSize: screenWidth * 0.032),
                                          softWrap: true,
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                          index,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAnimatedItem(Widget child, int index) {
    return TweenAnimationBuilder(
      tween: Tween<Offset>(begin: Offset(1, 0), end: Offset.zero),
      duration: Duration(milliseconds: 500 + index * 100),
      curve: Curves.easeOut,
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
