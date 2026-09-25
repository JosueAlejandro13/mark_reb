import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/pages/Error_/ClientErrrorPage.dart';
import 'package:mark_v3/pages/Routes_/distance_route_page.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/services/ConnectionRoutes_/RoutesCon_service.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

// Autor: Josue Hernandez
class CheckVisitPage extends StatefulWidget {
  final String clientId;
  final String idMainAccount;
  final double latitude;
  final double longitude;
  final int idRoute;

  const CheckVisitPage(
      {super.key,
      required this.clientId,
      required this.idMainAccount,
      required this.latitude,
      required this.longitude,
      required this.idRoute});

  @override
  _CheckVisitPageState createState() => _CheckVisitPageState();
}

class _CheckVisitPageState extends State<CheckVisitPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  bool isLoading = true;

  final RoutesconService dbService = RoutesconService();

  String clientName = '';
  String clientAddress = '';
  String clientstreetNum = '';
  String clientintNum = '';
  String clientcolonia = '';
  String clientdelegacion = '';
  String clientciudad = '';
  String clientpais = '';
  String clientcp = '';
  String clienttelefono = '';
  String clientmail = '';
  String clientcod = '';
  List<Map<String, dynamic>> products = [];
  Map<String, dynamic>? routeConfig;
  List<TextEditingController> quantityControllers = [];

  @override
  void initState() {
    super.initState();

    debugPrint("Valor de clientId en DeliverPage: ${widget.clientId}");
    debugPrint(
        "Valores obtenidos ${widget.idRoute}, ${widget.longitude}, ${widget.latitude}");
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _fetchRouteConfiguration(widget.idRoute);
    await loadClientData();
  }

  Future<void> _withLoading(Future<void> Function() action) async {
    setState(() {
      isLoading = true;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      setState(() {
        _image = image;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _fetchRouteConfiguration(int idRoute) async {
    await _withLoading(() async {
      try {
        final config = await dbService.getRouteConfigurationById(idRoute);
        if (config != null) {
          double maxDist = routeConfig?['maxDist']?.toDouble() ?? 50.0;

          debugPrint('Configuración obtenida:');
          debugPrint('Distancia máxima permitida: $maxDist metros');

          _compareLocation(widget.latitude, widget.longitude, maxDist);
        } else {
          debugPrint('No se encontró configuración para la ruta $idRoute');
        }
      } catch (e) {
        _handleError(e);
      }
    });
  }

  void _handleError(Object e) {
    if (e.toString().contains('SocketException')) {
      debugPrint('SocketException: Error de conexión.');
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
    } else if (e.toString().contains('TimeoutException')) {
      debugPrint('TimeoutException: Tiempo de espera excedido.');
      if (mounted) {
        Navigator.of(context).push(
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
    } else {
      debugPrint('Error al obtener configuración de la ruta: $e');
    }
  }

  Future<void> loadClientData() async {
    await _withLoading(() async {
      try {
        final clientData = await dbService.obtenerCliente(
            widget.clientId, widget.idMainAccount);

        if (mounted) {
          setState(() {
            clientName = clientData?['namClient'] ?? '';
            clientAddress = clientData?['calle'] ?? '';
            clientstreetNum = clientData?['streetNum'] ?? '';
            clientintNum = clientData?['intNum'] ?? '';
            clientcolonia = clientData?['colonia'] ?? '';
            clientdelegacion = clientData?['delegacion'] ?? '';
            clientciudad = clientData?['ciudad'] ?? '';
            clientpais = clientData?['pais'] ?? '';
            clientcp = clientData?['cp'] ?? '';
            clienttelefono = clientData?['telefono'] ?? '';
            clientmail = clientData?['mail'] ?? '';
            clientcod = clientData?['cod'] ?? '';
          });
        }
      } catch (e) {
        if (e.toString().contains('SocketException')) {
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
        } else if (e.toString().contains('TimeoutException')) {
          debugPrint('TimeoutException: Tiempo de espera excedido.');

          if (mounted) {
            await Navigator.of(context).push(
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
        } else {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => ClientErrrorPage(
                  onRetry: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => widget),
                    );
                  },
                ),
              ),
            );
          }
          debugPrint('Error al cargar los datos del cliente: $e');
        }
      }
    });
  }

  Future<void> _refreshData() async {
    await loadClientData();
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double radius = 6371;

    double lat1Rad = _degToRad(lat1);
    double lon1Rad = _degToRad(lon1);
    double lat2Rad = _degToRad(lat2);
    double lon2Rad = _degToRad(lon2);

    double dLat = lat2Rad - lat1Rad;
    double dLon = lon2Rad - lon1Rad;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return radius * c * 1000;
  }

  double _degToRad(double deg) {
    return deg * (pi / 180);
  }

  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('El servicio de ubicación está deshabilitado.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Los permisos de ubicación están denegados.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Los permisos de ubicación están permanentemente denegados.');
    }

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  void _compareLocation(
      double routeLat, double routeLon, double maxDist) async {
    setState(() {
      isLoading = true;
    });

    try {
      Position currentPosition = await _getCurrentPosition();

      double currentLatitude = currentPosition.latitude;
      double currentLongitude = currentPosition.longitude;

      debugPrint(
          'Ubicación actual: Latitude: $currentLatitude, Longitude: $currentLongitude');
      debugPrint(
          'Ubicación de la ruta: Latitude: $routeLat, Longitude: $routeLon');
      double distance = calculateDistance(
          currentLatitude, currentLongitude, routeLat, routeLon);

      debugPrint('Distancia calculada: $distance metros');

      double exceededDistance = distance - maxDist;
      if (exceededDistance > 0) {
        debugPrint('Te has pasado del rango por $exceededDistance metros');

        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DistanceRoutePage(
              onRetry: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => widget),
                );
              },
              exceededDistance: exceededDistance,
            ),
          ),
        );
      } else {
        debugPrint('Estás dentro del rango permitido.');
      }
    } catch (e) {
      debugPrint('Error al comparar ubicación: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(45.0),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0886B5),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                offset: Offset(0, 7),
                blurRadius: 4,
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
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
      ),
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(seconds: 5),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, 250, 250, 250),
                  Color.fromARGB(255, 205, 240, 255),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          RefreshIndicator(
            onRefresh: _refreshData,
            color: Colors.black,
            child: isLoading
                ? Center(
                    child: Lottie.asset(
                    'assets/loading.json',
                    height: screenHeight * 0.2,
                    width: screenWidth * 0.2,
                    repeat: true,
                  ))
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Comprueba tu Visita',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.040,
                                ),
                              ),
                              GestureDetector(
                                onTap: _takePhoto,
                                child: Icon(
                                  Icons.verified,
                                  color: _image == null
                                      ? Colors.red
                                      : Colors.green,
                                  size: 32,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Card(
                            elevation: 6,
                            color: const Color.fromARGB(255, 255, 255, 255),
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Datos de la Ruta',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.037,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Nombre: $clientName',
                                      style: TextStyle(
                                          fontSize: screenWidth * 0.034),
                                      softWrap: true),
                                  const SizedBox(height: 8),
                                  Text(clientcod),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Dirección: $clientAddress, $clientstreetNum, $clientintNum, $clientcolonia, $clientdelegacion, $clientciudad, $clientcp, $clientpais.',
                                      style: TextStyle(
                                          fontSize: screenWidth * 0.034),
                                      softWrap: true),
                                  const SizedBox(height: 8),
                                  Text('Contacto: $clienttelefono',
                                      style: TextStyle(
                                          fontSize: screenWidth * 0.034),
                                      softWrap: true)
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: _image == null
                                ? Text('No se ha tomado ninguna foto.',
                                    style: TextStyle(
                                        fontSize: screenWidth * 0.034))
                                : Image.file(
                                    File(_image!.path),
                                    height: 200,
                                    width: 200,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton(
                              onPressed: _takePhoto,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color(0xFF0886B5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text('Tomar Foto',
                                  style:
                                      TextStyle(fontSize: screenWidth * 0.030)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton(
                              onPressed: () {
                                showTopSnackBar(
                                  Overlay.of(context),
                                  Material(
                                    color: Colors.transparent,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color.fromARGB(
                                            255, 0, 155, 85),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check,
                                              color: Colors.white, size: 24),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              "Visita comprobada.",
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
                              },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color(0xFF0886B5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Comprobar',
                                style: TextStyle(fontSize: screenWidth * 0.030),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
