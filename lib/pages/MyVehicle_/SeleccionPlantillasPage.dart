import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/pages/Error_/InspError.dart';
import 'package:mark_v3/pages/MyVehicle_/MyVehiclePage.dart';
import 'package:mark_v3/pages/MyVehicle_/MyInspectVehiclePage.dart';
import 'package:mark_v3/services/ConnectionInspeccion_/InspeccionCon_service.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

//Autor: Josue Hernandez
class SeleccionPlantillasPage extends StatefulWidget {
  final Vehicle vehicle;
  final String userId;
  final String idCollaborator;
  final String idMainAccount;

  const SeleccionPlantillasPage(
      {super.key,
      required this.userId,
      required this.vehicle,
      required this.idCollaborator,
      required this.idMainAccount});

  @override
  _SeleccionPlantillasPageState createState() =>
      _SeleccionPlantillasPageState();
}

class _SeleccionPlantillasPageState extends State<SeleccionPlantillasPage> {
  List<Map<String, dynamic>> plantillas = [];
  bool _isLoading = false;
  bool _isSnackBarShown = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _cargarPlantillas();
  }

  Future<void> _cargarPlantillas() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbService = InspeccionconService();
      final nuevasPlantillas =
          await dbService.obtenerPlantillasPorUsuarioYVehiculo(
              widget.idMainAccount, int.parse(widget.vehicle.id));

      if (nuevasPlantillas.isEmpty) {
        debugPrint(
            'No se encontraron plantillas para el usuario ${widget.idMainAccount} y vehículo ${widget.vehicle.id}');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => InspError(
                onRetry: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => widget),
                  );
                },
              ),
            ),
          );
        }
      } else {
        setState(() {
          plantillas = nuevasPlantillas;
        });
      }
    } on SocketException {
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
    } on TimeoutException {
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
            builder: (context) => InspError(
              onRetry: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => widget),
                );
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    await _cargarPlantillas();
  }

  Future<int> _calcularDiasRestantes(Map<String, dynamic> plantilla) async {
    final dbService = InspeccionconService();
    String vehicleId = widget.vehicle.id.toString();
    String userId = widget.idMainAccount.toString();
    String plantillaId = plantilla['id'].toString();
    debugPrint('ID Vehículo: $vehicleId');
    debugPrint('ID Usuario: $userId');
    debugPrint('ID Plantilla: $plantillaId');
    final lastInspection =
        await dbService.obtenerUltimaInspeccion(vehicleId, plantillaId, userId);

    if (lastInspection != null) {
      DateTime lastDate = lastInspection['endDate'];
      int periodicity = plantilla['periodicity'] ?? 0;

      DateTime nextInspectionDate = lastDate.add(Duration(days: periodicity));
      DateTime now = DateTime.now();
      int daysRemaining = nextInspectionDate.difference(now).inDays;

      return daysRemaining;
    }
    return -1;
  }

  Color _determinarTextoColor(int daysRemaining) {
    if (daysRemaining < 0) {
      return Colors.green;
    } else if (daysRemaining <= 7) {
      return Colors.amber;
    } else {
      return Colors.red;
    }
  }

  Future<bool> _puedeNavegar(Map<String, dynamic> plantilla) async {
    int daysRemaining = await _calcularDiasRestantes(plantilla);

    return daysRemaining < 0;
  }

  void _navegarAMyInspectVehiclePage(Map<String, dynamic> plantilla) async {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Lottie.asset(
          'assets/loading.json',
          height: screenHeight * 0.1,
          width: screenWidth * 0.1,
          repeat: true,
        ),
      ),
    );

    if (_isNavigating) return;

    _isNavigating = true;

    bool puedeNavegar = await _puedeNavegar(plantilla);

    debugPrint('Puede navegar: $puedeNavegar');

    Navigator.pop(context);

    if (puedeNavegar) {
      String plantillaId = plantilla['id'].toString();
      int enableStorePhoto = plantilla['enableStorePhoto'] ?? 0;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MyInspectVehiclePage(
            vehicle: widget.vehicle,
            plantillaId: plantillaId,
            userId: widget.idMainAccount,
            idCollaborator: widget.idCollaborator,
            enableStorePhoto: enableStorePhoto,
            idMainAccount: widget.idMainAccount,
          ),
        ),
      );

      if (result == true) {
        setState(() {
          _isLoading = true;
        });
        await _cargarPlantillas();

        setState(() {
          _isLoading = false;
        });
      }
    } else {
      if (!_isSnackBarShown) {
        _isSnackBarShown = true;

        final screenWidth = MediaQuery.of(context).size.width;
        showTopSnackBar(
          Overlay.of(context),
          Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "No se puede crear una nueva inspección. Espere a que pase la periodicidad.",
                      style: TextStyle(
                        fontSize: screenWidth * 0.034,
                        color: Colors.white,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        Future.delayed(const Duration(seconds: 3), () {
          _isSnackBarShown = false;
        });
      }
    }
    _isNavigating = false;
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
            plantillas.isEmpty
                ? Center(
                    child: Lottie.asset(
                    'assets/loading.json',
                    height: screenHeight * 0.2,
                    width: screenWidth * 0.2,
                    repeat: true,
                  ))
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Plantillas de Inspección',
                            style: TextStyle(
                              fontSize: screenWidth * 0.050,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 10.0,
                              mainAxisSpacing: 10.0,
                            ),
                            itemCount: plantillas.length,
                            itemBuilder: (context, index) {
                              final plantilla = plantillas[index];
                              return FutureBuilder<int>(
                                future: _calcularDiasRestantes(plantilla),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Center(
                                        child: Lottie.asset(
                                      'assets/loading.json',
                                      height: screenHeight * 0.2,
                                      width: screenWidth * 0.2,
                                      repeat: true,
                                    ));
                                  } else {
                                    int daysRemaining = snapshot.data ?? 0;

                                    return GestureDetector(
                                      onTap: () =>
                                          _navegarAMyInspectVehiclePage(
                                              plantilla),
                                      child: Card(
                                        elevation: 6,
                                        color: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                plantilla['name'],
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.032,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 7,
                                                overflow: TextOverflow.ellipsis,
                                                softWrap: true,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                plantilla['decription'] ??
                                                    'Sin descripción',
                                                style: TextStyle(
                                                  fontSize: screenWidth * 0.030,
                                                  color: Colors.grey,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 70,
                                                overflow: TextOverflow.ellipsis,
                                                softWrap: true,
                                              ),
                                              const SizedBox(height: 8),
                                              Icon(
                                                FontAwesomeIcons.cogs.data,
                                                size: 30,
                                                color: Colors.black,
                                              ),
                                              const SizedBox(height: 20),
                                              Container(
                                                color: const Color.fromARGB(
                                                    255, 255, 255, 255),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8.0,
                                                        vertical: 4.0),
                                                child: Text(
                                                  daysRemaining < 0
                                                      ? 'Listo para realizar'
                                                      : 'Faltan $daysRemaining ${daysRemaining == 1 ? 'día' : 'días'}',
                                                  style: TextStyle(
                                                    fontSize:
                                                        screenWidth * 0.029,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        _determinarTextoColor(
                                                            daysRemaining),
                                                  ),
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  softWrap: true,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
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
}
