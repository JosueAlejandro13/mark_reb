import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/Routes_/distance_route_page.dart';
import 'package:mark_v3/services/ConnectionRoutes_/RoutesCon_service.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

//Autor: Josue Hernandez
class VisitRecordPage extends StatefulWidget {
  final String idMainAccount;
  final double latitude;
  final double longitude;
  final int idRoute;
  final String idAssignClients;
  final String clientId;
  final String? idVehic;
  final double distanceMint;
  final String typeRoute;
  final String nClients;

  const VisitRecordPage(
      {super.key,
      required this.idMainAccount,
      required this.latitude,
      required this.longitude,
      required this.idRoute,
      required this.idAssignClients,
      required this.clientId,
      required this.idVehic,
      required this.distanceMint,
      required this.typeRoute,
      required this.nClients});

  @override
  _VisitRecordPageState createState() => _VisitRecordPageState();
}

class _VisitRecordPageState extends State<VisitRecordPage> {
  final TextEditingController _visitobsController = TextEditingController();
  final TextEditingController _dateTimeController = TextEditingController();
  final RoutesconService dbService = RoutesconService();
  Map<String, dynamic>? routeConfig;

  bool isLoading = true;

  final ImagePicker _picker = ImagePicker();
  XFile? _image;

  @override
  void initState() {
    super.initState();
    debugPrint(
        'Latitude: ${widget.latitude}, Longitude: ${widget.longitude}, vehic: ${widget.idVehic}');
    debugPrint('ruta ${widget.idRoute}');
    debugPrint('DISTANCIA DE CLIENTES: ${widget.distanceMint}');
    debugPrint('TYPERoute: ${widget.typeRoute}');
    debugPrint('nClients ${widget.nClients}');
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _fetchRouteConfiguration(widget.idRoute, widget.clientId);
  }

  Future<void> saveHistoricalJob({
    required int idAssignClients,
    required int idDelivVehic,
    required int idClie,
    required int idRoute,
    required int idPos,
    required DateTime routeDay,
    required double dist,
    required int st,
  }) async {
    try {
      final DateTime dateCreate = DateTime.now();
      final DateTime dateRecord = DateTime.now();

      await dbService.insertHistoricalJob(
        idAssignClients: idAssignClients,
        idDelivVehic: idDelivVehic,
        idClie: idClie,
        idRoute: idRoute,
        idPos: idPos,
        routeDay: routeDay,
        dateCreate: dateCreate,
        dateRecord: dateRecord,
        dist: dist,
        st: st,
      );

      final screenWidth = MediaQuery.of(context).size.width;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              '¡Registro exitoso!',
              style: TextStyle(fontSize: screenWidth * 0.037),
            ),
            content: Text(
              'El registro se ha guardado con éxito.',
              style: TextStyle(fontSize: screenWidth * 0.033),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(true);
                },
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF0886B5),
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'OK',
                  style: TextStyle(fontSize: screenWidth * 0.030),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint("Error al guardar el registro histórico: $e");
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
                    "Error al guardar cambios. Intente nuevamente más tarde.",
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
    }
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

  Future<void> _fetchRouteConfiguration(int idRoute, String clientId) async {
    await _withLoading(() async {
      try {
        final config = await dbService.getRouteConfigurationById(idRoute);
        if (config != null) {
          setState(() {
            routeConfig = config;
          });

          double maxDist = routeConfig?['maxDist']?.toDouble() ?? 50.0;
          int timTolerance = routeConfig?['timTolerance']?.toInt() ?? 900;
          _compareLocation(widget.latitude, widget.longitude, maxDist);

          debugPrint('Configuración obtenida:');
          debugPrint('Distancia máxima permitida: $maxDist metros');
          debugPrint('Tolerancia: $timTolerance ');

          final horarioClient =
              await dbService.getarriveTiempoClient(int.parse(clientId));

          if (horarioClient != null) {
            debugPrint('Datos de tiempo del cliente obtenidos.');
          } else {
            debugPrint('No se encontraron datos tiempo del cliente');
          }

          final conteo = await dbService.getConteoTypeandDeliver(idRoute);

          if (conteo.isNotEmpty) {
            List filteredClients =
                conteo.where((tipo) => tipo['typStep'] == 2).toList();

            int countClientes = filteredClients.length;

            debugPrint('Clientes filtrados: $countClientes');
          } else {
            debugPrint('No se encontraron datos para el cliente');
          }

          final clientConfig =
              await dbService.getarriveClient(int.parse(clientId), idRoute);

          if (clientConfig != null) {
            debugPrint('Hora de llegada: ${clientConfig['arrival']} ');
          } else {
            debugPrint(
                'No se encontró configuración para el cliente $clientId');
          }
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
      } else {
        debugPrint('Estás dentro del rango permitido.');
      }

      if (distance > maxDist) {
        Navigator.of(context).pushReplacement(
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
        debugPrint('Dentro del rango permitido.');
      }
    } catch (e) {
      debugPrint('Error al comparar ubicación: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
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

  Future<void> _pickDateTime() async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        builder: (context, child) {
          return Transform.scale(
            scale: 0.9,
            child: child,
          );
        });

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        final DateTime finalDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          _dateTimeController.text = "${finalDateTime.toLocal()}".split('.')[0];
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
          isLoading
              ? Center(
                  child: Lottie.asset(
                  'assets/loading.json',
                  width: screenWidth * 0.2,
                  height: screenHeight * 0.2,
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
                              'Registrar Visita',
                              style: TextStyle(
                                fontSize: screenWidth * 0.040,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                            GestureDetector(
                              onTap: _takePhoto,
                              child: Icon(
                                Icons.verified,
                                color:
                                    _image == null ? Colors.red : Colors.green,
                                size: 32,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: TextField(
                                controller: _dateTimeController,
                                readOnly: true,
                                onTap: _pickDateTime,
                                decoration: InputDecoration(
                                  labelText: 'Fecha y Hora de la Visita',
                                  border: OutlineInputBorder(),
                                  labelStyle: TextStyle(
                                      color: Colors.black,
                                      fontSize: screenWidth * 0.031),
                                  suffixIcon: Icon(Icons.calendar_today),
                                  filled: false,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                    borderSide: const BorderSide(
                                        color: Color.fromARGB(255, 0, 0, 0),
                                        width: 1.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                    borderSide: const BorderSide(
                                      color: Colors.black,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                style: TextStyle(
                                    color: Colors.black,
                                    fontSize: screenWidth * 0.031),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: TextField(
                                  controller: _visitobsController,
                                  decoration: InputDecoration(
                                    labelText: 'Observaciones',
                                    labelStyle: TextStyle(
                                        color: Colors.black,
                                        fontSize: screenWidth * 0.031),
                                    filled: false,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide: const BorderSide(
                                          color: Color.fromARGB(255, 0, 0, 0),
                                          width: 1.0),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide: const BorderSide(
                                        color: Colors.black,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontSize: screenWidth * 0.031),
                                ),
                              ),
                            ]),
                        const SizedBox(height: 32.0),
                        Center(
                          child: _image == null
                              ? Text('No se ha tomado ninguna foto.',
                                  style:
                                      TextStyle(fontSize: screenWidth * 0.034))
                              : Image.file(
                                  File(_image!.path),
                                  height: 200,
                                  width: 200,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _takePhoto,
                            label: const Text('Tomar Foto'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0886B5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8))),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        Center(
                          child: ElevatedButton(
                            onPressed: () async {
                              int idAssignClients =
                                  int.tryParse(widget.idAssignClients) ?? 0;
                              int idDelivVehic =
                                  int.tryParse(widget.idVehic ?? '0') ?? 0;
                              int idClie = int.tryParse(widget.clientId) ?? 0;
                              int idRoute = widget.idRoute;
                              int idPos = 0;
                              DateTime routeDay = DateTime.now();
                              double distance = widget.distanceMint;

                              await _showLoadingDialog(context, 'Cargando...');
                              try {
                                final arriveDatar = await dbService
                                    .getarriveTiempoClient(idClie);

                                if (arriveDatar != null) {
                                  int dateRecordSeconds = routeDay.hour * 3600 +
                                      routeDay.minute * 60 +
                                      routeDay.second;

                                  int visitingIn = int.tryParse(
                                          arriveDatar['visitingIn']
                                                  ?.toString() ??
                                              '0') ??
                                      0;
                                  int visitingOut = int.tryParse(
                                          arriveDatar['visitingOut']
                                                  ?.toString() ??
                                              '0') ??
                                      0;

                                  int visitingHours = int.tryParse(
                                        arriveDatar['visitingHours']
                                                ?.toString() ??
                                            '0',
                                      ) ??
                                      0;

                                  int status = 64;

                                  debugPrint(
                                      'Hora de visita (visitingIn): $visitingIn segundos');
                                  debugPrint(
                                      'Hora de salida (visitingOut): $visitingOut segundos');
                                  debugPrint(
                                      'Fecha actual en segundos (dateRecordSeconds): $dateRecordSeconds');
                                  debugPrint(
                                      '1 Si el cliente tiene horario de visita, 0 si no (visitingHours): $visitingHours');

                                  final conteo = await dbService
                                      .getConteoTypeandDeliver(idRoute);
                                  List filteredClients = conteo
                                      .where((tipo) => tipo['typStep'] == 2)
                                      .toList();

                                  List<int> deliveryOrders = filteredClients
                                      .map((tipo) =>
                                          int.tryParse(tipo['deliveryOrder']
                                                  ?.toString() ??
                                              '0') ??
                                          0)
                                      .toList();

                                  deliveryOrders.sort();

                                  int clientCount = filteredClients.length;

                                  final arriveData = await dbService
                                      .getarriveClient(idClie, idRoute);

                                  if (arriveData != null) {
                                    int deliveryOrder = int.tryParse(
                                            arriveData['deliveryOrder']
                                                    ?.toString() ??
                                                '0') ??
                                        0;
                                    int typStep = int.tryParse(
                                            arriveData['typStep']?.toString() ??
                                                '0') ??
                                        0;

                                    int totalClients =
                                        int.tryParse(widget.nClients) ?? 0;

                                    debugPrint(
                                        'Orden de la ruta: $deliveryOrder');
                                    debugPrint(
                                        'DeliveryOrders: $deliveryOrders');
                                    debugPrint(
                                        'Cantidad de clientes con typStep == 2: $clientCount');
                                    debugPrint(
                                        'CONTEO------------------------------------------');

                                    if (deliveryOrder == deliveryOrders.first) {
                                      status |= 16;
                                      debugPrint(
                                          "Es el primer cliente (status |= 16)");
                                    } else if (deliveryOrder ==
                                        deliveryOrders.last) {
                                      status |= 32;
                                      debugPrint(
                                          "Es el último cliente (status |= 32)");
                                    } else {
                                      status |= 0; // Cliente intermedio
                                      debugPrint(
                                          "Cliente intermedio (status |= 0)");
                                    }
                                    // Determinar si está en secuencia
                                    if (deliveryOrders
                                        .contains(deliveryOrder)) {
                                      status |= 1; // Visita en secuencia
                                      debugPrint(
                                          "Visita en secuencia (status |= 1)");
                                    } else {
                                      debugPrint(
                                          "Visita fuera de secuencia (status |= 0)");
                                    }
                                  } else {
                                    debugPrint(
                                        'Error: No se encontraron datos en arriveData.');
                                  }

                                  if (visitingHours == 0) {
                                    status |= 2;
                                    debugPrint(
                                        'Visitas no registrada por horario (status = 2)');
                                  } else {
                                    if (dateRecordSeconds < visitingIn ||
                                        dateRecordSeconds > visitingOut) {
                                      status |= 0;
                                      debugPrint(
                                          "Llegada fuera del horario de visita (status = 0)");
                                    } else {
                                      status |= 2;
                                      debugPrint(
                                          "Llegada dentro del horario de visita (status = 2)");
                                    }
                                  }

                                  String secondsToTimeFormat(int totalSeconds) {
                                    int hours =
                                        totalSeconds ~/ 3600; // Calcular horas
                                    int minutes = (totalSeconds % 3600) ~/
                                        60; // Calcular minutos

                                    return '$hours horas $minutes minutos';
                                  }

                                  final arrive = await dbService
                                      .getarriveClient(idClie, idRoute);
                                  if (arrive != null) {
                                    int arrival = int.tryParse(
                                            arrive['arrival']?.toString() ??
                                                '0') ??
                                        0;
                                    int timTolerance =
                                        routeConfig?['timTolerance']?.toInt() ??
                                            0;

                                    DateTime now = DateTime.now();
                                    int currentTimeInSeconds = now.hour * 3600 +
                                        now.minute * 60 +
                                        now.second;

                                    int adjustedArrivalEarly = arrival -
                                        timTolerance; // Llegada temprana
                                    int adjustedArrivalLate =
                                        arrival + timTolerance; // Llegada tarde

                                    debugPrint(
                                        'LLEGADA DEL OPERADOR------------------------------------------');
                                    debugPrint(
                                        'Hora actual: ${secondsToTimeFormat(currentTimeInSeconds)}');
                                    debugPrint(
                                        'Hora original de llegada (arrival): ${secondsToTimeFormat(arrival)}');
                                    debugPrint(
                                        'Tolerancia: ${secondsToTimeFormat(timTolerance)}');
                                    debugPrint(
                                        'Rango de llegada: ${secondsToTimeFormat(adjustedArrivalEarly)} - ${secondsToTimeFormat(adjustedArrivalLate)}');

                                    if (currentTimeInSeconds <
                                        adjustedArrivalEarly) {
                                      status |= 0;
                                      debugPrint(
                                          "Llegada temprana (status = 0)");
                                    } else if (currentTimeInSeconds >
                                        adjustedArrivalLate) {
                                      status |= 4;
                                      debugPrint("Llegada tarde. (status = 4)");
                                    } else {
                                      debugPrint("Llegada bien.");
                                    }

                                    debugPrint(
                                        'Visita al cliente (visita al client = 64)');

                                    debugPrint(
                                        'Estado final calculado (status): $status');
                                  } else {
                                    debugPrint(
                                        'Error: No se encontraron datos en arrive.');
                                  }

                                  await saveHistoricalJob(
                                    idAssignClients: idAssignClients,
                                    idDelivVehic: idDelivVehic,
                                    idClie: idClie,
                                    idRoute: idRoute,
                                    idPos: idPos,
                                    routeDay: routeDay,
                                    dist: distance,
                                    st: status,
                                  );

                                  final screenWidth =
                                      MediaQuery.of(context).size.width;
                                  await showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    barrierColor: Colors.transparent,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Text(
                                          '¡Registro éxito!',
                                          style: TextStyle(
                                              fontSize: screenWidth * 0.037),
                                        ),
                                        content: Text(
                                          'El registro se ha guardado con éxito.',
                                          style: TextStyle(
                                              fontSize: screenWidth * 0.033),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                              Navigator.of(context).pop(true);
                                              Navigator.of(context).pop(true);
                                            },
                                            style: TextButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF0886B5),
                                              foregroundColor: Colors.white,
                                            ),
                                            child: Text(
                                              'OK',
                                              style: TextStyle(
                                                  fontSize:
                                                      screenWidth * 0.030),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                } else {
                                  throw Exception(
                                      'Error: No se encontraron datos del cliente.');
                                }
                              } catch (e) {
                                debugPrint('Error al registrar la visita: $e');
                                final screenWidth =
                                    MediaQuery.of(context).size.width;
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text(
                                        'Error',
                                        style: TextStyle(
                                            fontSize: screenWidth * 0.032),
                                      ),
                                      content: Text(
                                        'Ocurrió un error al registrar la visita: $e',
                                        style: TextStyle(
                                            fontSize: screenWidth * 0.030),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: Text(
                                            'OK',
                                            style: TextStyle(
                                                fontSize: screenWidth * 0.030),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              } finally {
                                await _hideLoadingDialog(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: const Color(0xFF0886B5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Registrar Visita',
                              style: TextStyle(fontSize: screenWidth * 0.030),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _showLoadingDialog(BuildContext context, String message) async {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenWidth * 5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  "Registrando             ",
                  style: TextStyle(fontSize: screenWidth * 0.033),
                ),
              ),
              const SizedBox(width: 20),
              Lottie.asset(
                'assets/loading.json',
                height: screenHeight * 0.08,
                width: screenHeight * 0.08,
                repeat: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _hideLoadingDialog(BuildContext context) async {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }
}
