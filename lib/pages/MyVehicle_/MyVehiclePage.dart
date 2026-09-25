import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/pages/Error_/unexpectedErrorPage.dart';
import 'package:mark_v3/pages/MyVehicle_/EditVehiclePage.dart';
import 'package:mark_v3/pages/MyVehicle_/SeleccionPlantillasPage.dart';
import 'package:mark_v3/services/ConnectionMyVehicle_/MyVehicleCon_service.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';

//Autor: Josue Hernandez
class MyVehiclePage extends StatefulWidget {
  final String idCollaborator;
  final String userId;
  final String idMainAccount;
  final String inspectionsPermission;

  const MyVehiclePage(
      {super.key,
      required this.idCollaborator,
      required this.inspectionsPermission,
      required this.idMainAccount,
      required this.userId});

  @override
  _MyVehiclePageState createState() => _MyVehiclePageState();
}

class _MyVehiclePageState extends State<MyVehiclePage> {
  late Future<List<Vehicle>> vehicles;
  late int inspectionsPermission;

  @override
  void initState() {
    super.initState();
    inspectionsPermission = widget.inspectionsPermission.isNotEmpty
        ? int.tryParse(widget.inspectionsPermission) ?? 0
        : 0;
    _loadVehicles();
  }

  void _loadVehicles() {
    setState(() {
      vehicles = MyvehicleconService()
          .getVehiclesByCollaboratorId(widget.idCollaborator)
          .then((vehicleMaps) {
        if (vehicleMaps.isEmpty) {
          return <Vehicle>[];
        }
        return vehicleMaps.map<Vehicle>((map) => Vehicle.fromMap(map)).toList();
      }).catchError((error) {
        if (error is SocketException || error is TimeoutException) {
          throw error;
        }
        throw Exception("Error desconocido: $error");
      });
    });
  }

  Future<void> _refreshData() async {
    setState(() {
      _loadVehicles();
    });
  }

  void _navigateToErrorPage(Widget errorPage) {
    if (mounted) {
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (context) => errorPage));
    }
  }

  void handleGlobalError(
      BuildContext context, Object error, VoidCallback onRetry) {
    if (error is SocketException) {
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
    } else if (error is TimeoutException) {
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
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => Unexpectederrorpage(
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
          actions: [
            FutureBuilder<List<Vehicle>>(
              future: vehicles,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData &&
                    snapshot.data!.isNotEmpty &&
                    hasPermission(inspectionsPermission, 2)) {
                  return IconButton(
                    icon: const Icon(Icons.drag_handle_outlined,
                        color: Color.fromARGB(255, 0, 0, 0)),
                    onPressed: () {
                      showMenu<String>(
                        context: context,
                        position: const RelativeRect.fromLTRB(1000, 80, 0, 0),
                        color: Colors.white,
                        items: <PopupMenuEntry<String>>[
                          _buildPopupMenuItem(
                              context, 'insp', 'Inspeccionar'),
                        ],
                        elevation: 8.0,
                      ).then((value) {
                        if (value == 'insp') {
                          _inspectVehicles(snapshot.data!);
                        }
                      });
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Mi Vehículo',
                    style: TextStyle(
                      fontSize: screenWidth * 0.050,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Vehicle>>(
                    future: vehicles,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                            child: Lottie.asset(
                          'assets/loading.json',
                          width: screenWidth * 0.2,
                          height: screenWidth * 0.2,
                          repeat: true,
                        ));
                      } else if (snapshot.hasError) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          handleGlobalError(
                              context, snapshot.error!, () => _loadVehicles());
                        });
                        return const SizedBox.shrink();
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Column(
                            children: [
                              const SizedBox(height: 15),
                              Icon(
                                Icons.warning_rounded,
                                size: 64,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No se encontró ningún vehículo.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.040,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Verifica que la información esté registrada',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.030,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        );
                      } else {
                        return ListView.builder(
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            final vehicle = snapshot.data![index];

                            return AnimationLimiter(
                                child: Column(
                                    children:
                                        AnimationConfiguration.toStaggeredList(
                              duration: const Duration(milliseconds: 500),
                              childAnimationBuilder: (widget) => SlideAnimation(
                                horizontalOffset: 100.0,
                                child: FadeInAnimation(
                                  child: widget,
                                ),
                              ),
                              children: [
                                _buildVehicleCard(vehicle),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 15),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: _buildHorizontalCard(vehicle),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 2,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(right: 1),
                                          child: _buildFinalCard(vehicle),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          0.7,
                                      child: _buildAdditionalCard(vehicle),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],
                            )));
                          },
                        );
                      }
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

  Widget _buildFinalCard(Vehicle vehicle) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditVehiclePage(
              vehicle: vehicle,
              idCollaborator: widget.idCollaborator,
              userId: widget.userId,
              idMainAccount: widget.idMainAccount,
            ),
          ),
        ).then((updatedVehicle) {
          if (updatedVehicle != null) {
            setState(() {
              _loadVehicles();
            });
          }
        });
      },
      child: Card(
        color: Colors.white,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0886B5).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_gas_station,
                      size: 40,
                      color: Color(0xFF0886B5),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 15,
                    color: Colors.black,
                  ),
                ],
              ),
              const Divider(),
              _buildInfoRow(
                  'Tipo de Combustible', vehicle.tipoCombustibleNombre),
              _buildInfoRow('Capacidad Tanque', vehicle.capacidadTanque),
              _buildInfoRow('Promedio Consumo', vehicle.promConsumo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalCard(Vehicle vehicle) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditVehiclePage(
              vehicle: vehicle,
              idCollaborator: widget.idCollaborator,
              userId: widget.userId,
              idMainAccount: widget.idMainAccount,
            ),
          ),
        ).then((updatedVehicle) {
          if (updatedVehicle != null) {
            setState(() {
              _loadVehicles();
            });
          }
        });
      },
      child: Card(
        color: Colors.white,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0886B5).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.speed,
                      size: 40,
                      color: Color(0xFF0886B5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(vehicle.odom, 'km'),
                        _buildInfoRow('Cilindrada', vehicle.cilindrada),
                        _buildInfoRow(
                            'Número de Cilindros', vehicle.nCilindros),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 15,
                    color: Colors.black,
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalCard(Vehicle vehicle) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditVehiclePage(
              vehicle: vehicle,
              idCollaborator: widget.idCollaborator,
              userId: widget.userId,
              idMainAccount: widget.idMainAccount,
            ),
          ),
        ).then((updatedVehicle) {
          if (updatedVehicle != null) {
            setState(() {
              _loadVehicles();
            });
          }
        });
      },
      child: Card(
        color: Colors.white,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0886B5).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.assignment,
                      size: 40,
                      color: Color(0xFF0886B5),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 15,
                    color: Colors.black,
                  ),
                ],
              ),
              const Divider(),
              _buildInfoRow('Placas', vehicle.placas),
              _buildInfoRow('VIN', vehicle.vin),
              _buildInfoRow('Tipo de Vehículo', vehicle.tipoVehiculoNombre),
              _buildStatusRow('Status', vehicle.Status),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String date) {
    try {
      DateTime parsedDate = DateTime.parse(date);
      return DateFormat('dd/MM/yyyy').format(parsedDate);
    } catch (e) {
      return date;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label: $value',
              style: TextStyle(fontSize: screenWidth * 0.030),
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  void _inspectVehicles(List<Vehicle> vehicles) {
    if (vehicles.isNotEmpty) {
      Vehicle vehicle = vehicles.first;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SeleccionPlantillasPage(
              userId: widget.userId,
              vehicle: vehicle,
              idMainAccount: widget.idMainAccount,
              idCollaborator: widget.idCollaborator),
        ),
      );
    }
  }

  Widget _buildVehicleCard(Vehicle vehicle) {
   final screenWidth = MediaQuery.of(context).size.width;
    return GestureDetector(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildVehicleHeader(vehicle),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Make y Model
                      Text(
                        '${vehicle.make} ${vehicle.model} ${vehicle.year}',
                        style: TextStyle(
                          fontSize: screenWidth * 0.045,
                          fontWeight: FontWeight.w700,
                          color: const Color.fromARGB(255, 255, 255, 255),
                          shadows: [
                            Shadow(
                              blurRadius: 6,
                              color: const Color.fromARGB(255, 0, 0, 0)
                                  .withOpacity(0.9),
                              offset: Offset(1, 1),
                            )
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleHeader(Vehicle vehicle) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 250,
        width: double.infinity,
        child: Align(
          alignment: Alignment.centerRight,
          child: Transform.translate(
            offset: Offset(30, 10),
            child: Image.asset(
              'assets/car.png',
              width: 350,
              height: 420,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleTitle(Vehicle vehicle) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Text(
      '${vehicle.make} ${vehicle.model}) ',
      style: TextStyle(
        fontSize: screenWidth * 0.035,
        fontWeight: FontWeight.bold,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 3,
      softWrap: true,
    );
  }

  Widget _buildStatusRow(String label, String status) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    Color statusColor;
    IconData statusIcon;
    switch (status.toLowerCase()) {
      case 'activo':
        statusColor = Colors.green;
        statusIcon = FontAwesomeIcons.checkCircle.data;
        break;
      case 'inactivo':
        statusColor = Colors.red;
        statusIcon = FontAwesomeIcons.timesCircle.data;
        break;
      case 'en taller':
        statusColor = Colors.orange;
        statusIcon = FontAwesomeIcons.wrench.data;
        break;
      case 'fuera de servicio':
        statusColor = Colors.grey;
        statusIcon = FontAwesomeIcons.ban.data;
        break;
      case 'vendido':
        statusColor = Colors.amberAccent;
        statusIcon = FontAwesomeIcons.dollarSign.data;
        break;
      case 'corralon':
        statusColor = Colors.brown;
        statusIcon = FontAwesomeIcons.truck.data;
        break;
      case 'robo':
        statusColor = Colors.blueAccent;
        statusIcon = FontAwesomeIcons.exclamationTriangle.data;
        break;
      default:
        statusColor = Colors.black54;
        statusIcon = FontAwesomeIcons.questionCircle.data;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label:',
            style: TextStyle(fontSize: screenWidth * 0.030),
          ),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 5,
            backgroundColor: statusColor,
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
                fontSize: screenWidth * 0.030,
                color: statusColor,
                fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
            softWrap: true,
          ),
        ],
      ),
    );
  }

  PopupMenuEntry<String> _buildPopupMenuItem(
      BuildContext context, String value, String title) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return PopupMenuItem<String>(
      value: value,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style:
                TextStyle(color: Colors.black, fontSize: screenWidth * 0.030),
          ),
        ),
      ),
    );
  }

  bool hasPermission(int permissionValue, int actionBit) {
    return (permissionValue & actionBit) == actionBit ||
        (permissionValue & 1) == 1;
  }
}

class Vehicle {
  final String id;
  final String placas;
  final String vin;
  final String make;
  final String model;
  final String year;
  final String cilindrada;
  final String nCilindros;
  final String promConsumo;
  final String capacidadTanque;
  final String color;
  final String tipoVehiculoNombre;
  final String tipoCombustibleNombre;
  final String Estado;
  final String Status;
  final String ColorEngo;
  final String marca;
  final String modelo;
  final String startDate;
  final String endDate;
  final String idStatus;
  final String odom;

  Vehicle(
      {required this.id,
      required this.placas,
      required this.vin,
      required this.make,
      required this.model,
      required this.year,
      required this.cilindrada,
      required this.nCilindros,
      required this.promConsumo,
      required this.capacidadTanque,
      required this.color,
      required this.tipoVehiculoNombre,
      required this.tipoCombustibleNombre,
      required this.ColorEngo,
      required this.Estado,
      required this.marca,
      required this.modelo,
      required this.Status,
      required this.startDate,
      required this.endDate,
      required this.idStatus,
      required this.odom});

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['idvehic']?.toString() ?? '',
      placas: map['placas']?.toString() ?? '',
      vin: map['vin']?.toString() ?? '',
      make: map['make']?.toString() ?? '',
      model: map['model']?.toString() ?? '',
      year: map['year']?.toString() ?? '',
      cilindrada: map['cilindrada']?.toString() ?? '',
      nCilindros: map['nCilindros']?.toString() ?? '',
      promConsumo: map['promConsumo']?.toString() ?? '',
      capacidadTanque: map['capacidadTanque']?.toString() ?? '',
      color: map['color']?.toString() ?? '',
      tipoVehiculoNombre: map['tipoVehiculoNombre']?.toString() ?? '',
      tipoCombustibleNombre: map['tipoCombustibleNombre']?.toString() ?? '',
      Estado: map['Estado']?.toString() ?? '',
      Status: map['Status']?.toString() ?? '',
      ColorEngo: map['ColorEngo']?.toString() ?? '',
      marca: map['marca']?.toString() ?? '',
      modelo: map['modelo']?.toString() ?? '',
      startDate: map['startDate']?.toString() ?? '',
      endDate: map['endDate']?.toString() ?? '',
      idStatus: map['idStatus']?.toString() ?? '',
      odom: map['odom']?.toString() ?? '',
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
