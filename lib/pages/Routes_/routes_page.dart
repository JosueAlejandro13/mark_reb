import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/pages/Error_/RoutesErrorPage.dart';
import 'package:mark_v3/pages/Routes_/MapPickerPage.dart';
import 'package:mark_v3/pages/Routes_/check_visit_page.dart';
import 'package:mark_v3/pages/Routes_/deliver_page.dart';
import 'package:mark_v3/pages/Routes_/visit_record_page.dart';
import 'package:mark_v3/services/ConnectionRoutes_/RoutesCon_service.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:url_launcher/url_launcher.dart';

//Autor: Josue Hernandez
class RoutesPage extends StatefulWidget {
  final String idMainAccount;
  final String idCollaborator;

  const RoutesPage({
    super.key,
    required this.idMainAccount,
    required this.idCollaborator,
  });

  @override
  _RoutesPageState createState() => _RoutesPageState();
}

class _RoutesPageState extends State<RoutesPage> {
  final RoutesconService dbService = RoutesconService();
  List<Map<String, dynamic>> activeRoutes = [];
  Map<int, List<Map<String, dynamic>>> routeSteps = {};

  List<Map<String, dynamic>> clientsList = [];
  Map<String, dynamic>? confiClient;

  bool showCheckButton = true;
  bool showVisitButton = true;
  bool isCancelled = false;

  int? _selectedRouteId;
  bool _isLoading = true;
  String? idVehic;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _fetchActiveRouteData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    isCancelled = true;
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (_isDisposed || !mounted) return;
    await _fetchActiveRouteData();
  }

  Future<void> _withLoading(Future<void> Function() action) async {
    if (_isDisposed || !mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      await action();
    } finally {
      if (!_isDisposed && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchActiveRouteData() async {
    if (_isDisposed || !mounted) return;
    isCancelled = false;
    await _withLoading(() async {
      if (isCancelled || _isDisposed || !mounted) return;
      try {
        final vehiculos =
            await dbService.obtenerIdVehicPorOperador(widget.idMainAccount);

        if (isCancelled || _isDisposed || !mounted) return;

        if (vehiculos.isNotEmpty) {
          idVehic = vehiculos.first['idvehic'].toString();
        } else {
          idVehic = null;
        }
      } catch (vehiculoError) {
        if (isCancelled || _isDisposed || !mounted) return;
        _handleRouteStepError(vehiculoError);
      }

      if (idVehic == null) {
        if (isCancelled || _isDisposed || !mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => RoutesErrorPage(
              onRetry: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => widget),
                );
              },
            ),
          ),
        );
        return;
      }

      try {
        activeRoutes = await dbService.obtenerRutasActivasUser(
          idVehic!,
          widget.idMainAccount,
        );
        if (isCancelled || _isDisposed || !mounted) return;

        int idMainAccount = int.parse(widget.idMainAccount);

        debugPrint("Datos de las rutas activas: $activeRoutes");

        if (activeRoutes.isEmpty) {
          if (isCancelled || _isDisposed || !mounted) return;
          debugPrint('No se encontraron rutas activas.');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => RoutesErrorPage(
                onRetry: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => widget),
                  );
                },
              ),
            ),
          );
          return;
        } else {
          debugPrint('Rutas activas encontradas: $activeRoutes');
          for (var route in activeRoutes) {
            if (isCancelled || _isDisposed || !mounted) return;
            int idRut = route['id'];
            String typeRoute = route['typeRoute']?.toString() ?? '';
            String nClients = route['nClients']?.toString() ?? '';

            try {
              routeSteps[idRut] =
                  await dbService.obtenerRutasPorIdRut(idRut, idMainAccount);
              if (isCancelled || _isDisposed || !mounted) return;
              if (routeSteps[idRut] != null && routeSteps[idRut]!.isNotEmpty) {
                List<Map<String, dynamic>> steps = routeSteps[idRut]!;

                List<Map<String, dynamic>> filteredSteps =
                    steps.where((step) => step['typStep'] != 5).toList();

                for (int i = 1; i < filteredSteps.length; i++) {
                  var currentClient = filteredSteps[i];
                  var previousClient = filteredSteps[i - 1];

                  if (currentClient['lat'] != null &&
                      currentClient['lng'] != null &&
                      previousClient['lat'] != null &&
                      previousClient['lng'] != null) {
                    double lat1 =
                        double.tryParse(previousClient['lat'].toString()) ??
                            0.0;
                    double lng1 =
                        double.tryParse(previousClient['lng'].toString()) ??
                            0.0;
                    double lat2 =
                        double.tryParse(currentClient['lat'].toString()) ?? 0.0;
                    double lng2 =
                        double.tryParse(currentClient['lng'].toString()) ?? 0.0;

                    double distance = haversineDistance(lat1, lng1, lat2, lng2);
                    int distanceMint = (distance * 1000).toInt();

                    debugPrint(
                        'Distancia entre el cliente ${currentClient['namClient']} y el cliente anterior ${previousClient['namClient']}: $distanceMint m');

                    currentClient['distanceMint'] = distanceMint;
                  } else {}

                  for (var step in steps) {
                    step['typeRoute'] = typeRoute;
                  }

                  for (var step in steps) {
                    step['nClients'] = nClients;
                  }
                }

                setState(() {
                  _selectedRouteId = idRut;
                });
              }

              debugPrint('Pasos para la ruta $idRut: ${routeSteps[idRut]}');
            } catch (e) {
              _handleRouteStepError(e);
            }
          }
        }
      } catch (e) {
        _handleError(e);
      }
    });
  }

  void _handleRouteStepError(Object e) {
    if (e.toString().contains('SocketException')) {
      debugPrint(
          'SocketException: Error de conexión al obtener pasos de ruta.');
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
      debugPrint(
          'TimeoutException: Tiempo de espera excedido al obtener pasos de ruta.');
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
    }
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

  void cancelProcess() {
    if (_isDisposed || !mounted) return;
    setState(() {
      isCancelled = true;
    });
  }

  double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371;
    double dLat = _degToRad(lat2 - lat1);
    double dLon = _degToRad(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  double _degToRad(double deg) {
    return deg * (pi / 180);
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
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: Colors.black,
        child: Stack(
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
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Rutas',
                      style: TextStyle(
                        fontSize: screenWidth * 0.040,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: activeRoutes.length,
                      itemBuilder: (context, index) {
                        final route = activeRoutes[index];
                        return _buildRouteCard(route);
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              Center(
                child: Lottie.asset(
                  'assets/loading.json',
                  width: screenWidth * 0.2,
                  height: screenWidth * 0.2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    int idRut = route['id'];

    final totalTiempo = calcularTotalTiempo(route);

    Set<String> habilidadesTotales = {};

    return Card(
      elevation: 6,
      color: const Color.fromARGB(255, 255, 255, 255),
      margin: const EdgeInsets.symmetric(
        vertical: 15.0,
        horizontal: 6.0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        route['name'] ?? 'Nombre de Ruta',
                        style: TextStyle(
                          fontSize: screenWidth * 0.037,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 0, 0, 0),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                        softWrap: true,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person,
                          size: 18, color: const Color.fromARGB(255, 0, 0, 0)),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Clientes: ${route['nClients']}',
                          style: TextStyle(fontSize: screenWidth * 0.032),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.build,
                          size: 18, color: const Color.fromARGB(255, 0, 0, 0)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Proceso de configuración: ${route['setup'] != null ? _convertToHours(route['setup']) : 'N/A'}',
                          style: TextStyle(fontSize: screenWidth * 0.032),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.route,
                          size: 18, color: const Color.fromARGB(255, 0, 0, 0)),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Servicio: ${route['service'] != null ? _convertToHours(route['service']) : 'N/A'}',
                          style: TextStyle(fontSize: screenWidth * 0.032),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 18, color: const Color.fromARGB(255, 0, 0, 0)),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Duración: ${route['duration'] != null ? _convertToHours(route['duration']) : 'N/A'}',
                          style: TextStyle(fontSize: screenWidth * 0.032),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 18, color: const Color.fromARGB(255, 0, 0, 0)),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Distancia: ${route['distance'] != null ? _convertToKilometers(route['distance']) : 'N/A'} km',
                          style: TextStyle(fontSize: screenWidth * 0.032),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 18, color: const Color.fromARGB(255, 0, 0, 0)),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Tiempo Total: ${_convertToHours(totalTiempo.toInt())}',
                          style: TextStyle(fontSize: screenWidth * 0.032),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                          child: Text(
                        'Observaciones: ${route['obs'] ?? 'N/A'}',
                        style: TextStyle(fontSize: screenWidth * 0.032),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 9,
                        softWrap: true,
                      ))
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
        children: [
          Builder(builder: (context) {
            List<String> habilidadesTotales = [];

            routeSteps[idRut]?.forEach((step) {
              List<dynamic> habilidades = step['habilidades'] ?? [];

              for (var hab in habilidades) {
                if (!habilidadesTotales.contains(hab['nam'])) {
                  habilidadesTotales.add(hab['nam']);
                }
              }
            });

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Habilidades Requeridas:',
                    style: TextStyle(
                      fontSize: screenWidth * 0.034,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    habilidadesTotales.isNotEmpty
                        ? habilidadesTotales.map((hab) => '- $hab').join('\n')
                        : 'No hay habilidades',
                    style: TextStyle(fontSize: screenWidth * 0.033),
                  ),
                ],
              ),
            );
          }),
          ...routeSteps[idRut]?.map<Widget>((step) {
                return _buildStepCard(step);
              }).toList() ??
              [const Center(child: Text('No hay detalles adicionales.'))],
        ],
      ),
    );
  }

  double calcularTotalTiempo(Map<String, dynamic> route) {
    double setup = (route['setup'] ?? 0).toDouble();
    double service = (route['service'] ?? 0).toDouble();
    double duration = (route['duration'] ?? 0).toDouble();

    return setup + service + duration;
  }

  Widget _buildStepCard(Map<String, dynamic> step) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    int idClie = step['idClient'];
    Color borderColor;
    Color backgroundColor;
    switch (step['typStep']) {
      case 1:
        borderColor = Colors.green;
        backgroundColor = Colors.green[100]!;
        break;
      case 3:
        borderColor = Colors.yellow;
        backgroundColor = Colors.green[100]!;

        break;
      case 4:
        borderColor = Colors.red;
        backgroundColor = Colors.green[100]!;

        break;
      case 5:
        borderColor = Colors.purple;
        backgroundColor = Colors.green[100]!;

        break;
      default:
        borderColor = const Color(0xFF0886B5);
        backgroundColor = Colors.green[100]!;
    }

    return Card(
      color: const Color.fromARGB(255, 255, 255, 255),
      margin: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 15.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1),
      ),
      elevation: 4,
      child: step['typStep'] == 0
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade300,
                    Colors.green.shade600,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.5),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      'Completado',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: screenWidth * 0.09,
                    ),
                  ],
                ),
              ),
            )
          : step['typStep'] == 0
              ? Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.shade300,
                        Colors.red.shade600,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          'No Completado',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Icon(
                          Icons.cancel,
                          color: Colors.white,
                          size: screenWidth * 0.09,
                        ),
                      ],
                    ),
                  ),
                )
              : ExpansionTile(
                  title: Text(
                    '${step['deliveryOrder'] ?? ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: screenWidth * 0.034,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              (() {
                                switch (step['typStep']) {
                                  case 1:
                                    return 'Inicio';
                                  case 2:
                                    return 'En curso';
                                  case 3:
                                    return 'Descanso';
                                  case 4:
                                    return 'Fin';
                                  case 5:
                                    return 'Estación';
                                  default:
                                    return '${step['typStep'] ?? ''}';
                                }
                              })(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: screenWidth * 0.032,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (step['typStep'] != 1 &&
                          step['typStep'] != 4 &&
                          step['typStep'] != 3 &&
                          step['typStep'] != 5)
                        Row(
                          children: [
                            const Icon(Icons.access_time,
                                size: 16, color: Color.fromARGB(255, 0, 0, 0)),
                            const SizedBox(width: 7),
                            Text(
                                'Horario de Atención: ${step['visitingIn'] != null ? _convertToHoursalone(step['visitingIn']) : ''} - '
                                '${step['visitingOut'] != null ? _convertToHoursalone(step['visitingOut']) : ''}',
                                style:
                                    TextStyle(fontSize: screenWidth * 0.031)),
                          ],
                        ),
                      if (step['typStep'] != 1 &&
                          step['typStep'] != 4 &&
                          step['typStep'] != 3 &&
                          step['typStep'] != 5)
                        Row(
                          children: [
                            const Icon(Icons.person,
                                size: 16, color: Color.fromARGB(255, 0, 0, 0)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                ' ${step['namClient'] ?? ''}',
                                style: TextStyle(fontSize: screenWidth * 0.031),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 3,
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                      if (step['typStep'] != 1 &&
                          step['typStep'] != 4 &&
                          step['typStep'] != 3 &&
                          step['typStep'] != 5)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on,
                                size: 16, color: Color.fromARGB(255, 0, 0, 0)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                ' ${step['calle'] ?? ''}, ${step['streetNum'] ?? ''}, ${step['colonia'] ?? ''}, ${step['delegacion'] ?? ''}.',
                                style: TextStyle(fontSize: screenWidth * 0.031),
                                softWrap: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ),
                      const SizedBox(height: 10),
                      if (step['typStep'] != 5)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                '${step['typStep'] == 1 ? 'Inicio de la ruta:' : step['typStep'] == 4 ? 'Fin de la ruta' : 'Llegada'} ${step['arrival'] != null ? _convertToHours(step['arrival']) : ''}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: screenWidth * 0.032,
                                ),
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                      if (step['typStep'] != 1 &&
                          step['typStep'] != 4 &&
                          step['typStep'] != 3 &&
                          step['typStep'] != 2)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.person,
                                size: 16, color: Color.fromARGB(255, 0, 0, 0)),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                  '${step['cod'] ?? ''}, ${step['descrip'] ?? ''},',
                                  style:
                                      TextStyle(fontSize: screenWidth * 0.031),
                                  softWrap: true),
                            ),
                          ],
                        ),
                      if (step['typStep'] != 1 &&
                          step['typStep'] != 4 &&
                          step['typStep'] != 3 &&
                          step['typStep'] != 5)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                  'Distancia ${step['distance'] != null ? _convertToKilometers(step['distance']) : ''} km',
                                  style:
                                      TextStyle(fontSize: screenWidth * 0.031),
                                  softWrap: true),
                            ),
                          ],
                        ),
                      if (step['typStep'] != 1 &&
                          step['typStep'] != 4 &&
                          step['typStep'] != 5)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                  'Duración ${step['duration'] != null ? _convertToHours(step['duration']) : ''}',
                                  style:
                                      TextStyle(fontSize: screenWidth * 0.031),
                                  softWrap: true),
                            ),
                          ],
                        ),
                      if (step['typStep'] != 1 &&
                          step['typStep'] != 4 &&
                          step['typStep'] != 3 &&
                          step['typStep'] != 5)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                  'Servicio ${step['service'] != null ? _convertToHours(step['service']) : ''}',
                                  style:
                                      TextStyle(fontSize: screenWidth * 0.031),
                                  softWrap: true),
                            ),
                          ],
                        ),
                      if (step['typStep'] != 1 &&
                          step['typStep'] != 4 &&
                          step['typStep'] != 3 &&
                          step['typStep'] != 5)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                  'Proceso de configuración ${step['service'] != null ? _convertToHours(step['setup']) : ''}',
                                  style:
                                      TextStyle(fontSize: screenWidth * 0.031),
                                  softWrap: true),
                            ),
                          ],
                        ),
                    ],
                  ),
                  // ignore: sort_child_properties_last
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            if (step['typStep'] != 1 &&
                                step['typStep'] != 4 &&
                                step['typStep'] != 3)
                              ElevatedButton.icon(
                                onPressed: (step['typStep'] == 5
                                        ? (step['lati'] != null &&
                                            step['longi'] != null)
                                        : (step['lat'] != null &&
                                            step['lng'] != null))
                                    ? () {
                                        final double latitude = step[
                                                    'typStep'] ==
                                                5
                                            ? double.tryParse(
                                                    step['lati'].toString()) ??
                                                0.0
                                            : double.tryParse(
                                                    step['lat'].toString()) ??
                                                0.0;
                                        final double longitude = step[
                                                    'typStep'] ==
                                                5
                                            ? double.tryParse(
                                                    step['longi'].toString()) ??
                                                0.0
                                            : double.tryParse(
                                                    step['lng'].toString()) ??
                                                0.0;

                                        _showMapSelectionDialog(
                                            latitude, longitude);
                                      }
                                    : null,
                                icon: const Icon(Icons.navigation),
                                label: const Text('Ir'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0886B5),
                                  foregroundColor: Colors.white,
                                  textStyle:
                                      TextStyle(fontSize: screenWidth * 0.030),
                                ),
                              ),
                            const SizedBox(width: 5),
                            if (step['typStep'] != 1 &&
                                step['typStep'] != 4 &&
                                step['typStep'] != 3 &&
                                step['typStep'] != 5)
                              ElevatedButton.icon(
                                onPressed: () async {
                                  LatLng? selectedLocation =
                                      await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const MapPickerPage()),
                                  );
                                  if (selectedLocation != null) {
                                    showTopSnackBar(
                                      Overlay.of(context),
                                      Material(
                                        color: Colors.transparent,
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 20),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Color(0xFF0886B5),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.error,
                                                  color: Colors.white,
                                                  size: 24),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  "Ubicación seleccionada: ${selectedLocation.latitude}, ${selectedLocation.longitude}",
                                                  style: TextStyle(
                                                    fontSize:
                                                        screenWidth * 0.034,
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.location_on),
                                label: const Text('Ubicación'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0886B5),
                                  foregroundColor: Colors.white,
                                  textStyle:
                                      TextStyle(fontSize: screenWidth * 0.030),
                                ),
                              ),
                            const SizedBox(width: 5),
                            if (step['typStep'] != 1 &&
                                step['typStep'] != 4 &&
                                step['typStep'] != 3 &&
                                step['typStep'] != 5)
                              ElevatedButton.icon(
                                onPressed: () {
                                  final String? clientId =
                                      step['idClient']?.toString();
                                  final String? routeId =
                                      step['id']?.toString();
                                  if (clientId != null && routeId != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DeliverPage(
                                          idMainAccount: widget.idMainAccount,
                                          clientId: clientId,
                                          idAssignClients: routeId,
                                        ),
                                      ),
                                    );
                                  } else {
                                    showTopSnackBar(
                                      Overlay.of(context),
                                      Material(
                                        color: Colors.transparent,
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 20),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Color(0xFF0886B5),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.error,
                                                  color: Colors.white,
                                                  size: 24),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  "Cliente no encontrado para este paso.",
                                                  style: TextStyle(
                                                    fontSize:
                                                        screenWidth * 0.034,
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.directions_car),
                                label: const Text('Entregar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0886B5),
                                  foregroundColor: Colors.white,
                                  textStyle:
                                      TextStyle(fontSize: screenWidth * 0.030),
                                ),
                              ),
                            const SizedBox(width: 5),
                            if (step['typStep'] != 1 &&
                                step['typStep'] != 4 &&
                                step['typStep'] != 3 &&
                                step['typStep'] != 2)
                              ElevatedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      TextEditingController litersController =
                                          TextEditingController();

                                      String id =
                                          (step['idEsta'] ?? '').toString();
                                      String cod =
                                          (step['cod'] ?? '').toString();
                                      String descrip =
                                          (step['descrip'] ?? '').toString();

                                      debugPrint('Id: $id');
                                      debugPrint("codigo: $cod");
                                      debugPrint("Nombre: $descrip");

                                      String selectedFuel = 'Gasolina';
                                      List<String> fuelTypes = [
                                        'Biodiesel',
                                        'GNP',
                                        'Diésel',
                                        'Diésel/eléctrico',
                                        'Eléctrico',
                                        'Gasolina',
                                        'Gasolina/Eléctrico'
                                            'Gasolina Premium',
                                        'Alcohol'
                                      ];
                                      return AlertDialog(
                                        title: Text(
                                          'Registrar Combustible',
                                          style: TextStyle(
                                              fontSize: screenWidth * 0.037),
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(height: 10),
                                            DropdownButtonFormField<String>(
                                              value: selectedFuel,
                                              onChanged: (String? newValue) {
                                                if (newValue != null) {
                                                  selectedFuel = newValue;
                                                }
                                              },
                                              decoration: InputDecoration(
                                                labelText: 'Combustible',
                                                labelStyle: TextStyle(
                                                  fontSize: screenWidth * 0.032,
                                                ),
                                                border: OutlineInputBorder(),
                                              ),
                                              isExpanded: true,
                                              items:
                                                  fuelTypes.map((String fuel) {
                                                return DropdownMenuItem<String>(
                                                  value: fuel,
                                                  child: Text(
                                                    fuel,
                                                    style: TextStyle(
                                                        fontSize: screenWidth *
                                                            0.032),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                            const SizedBox(height: 10),
                                            TextField(
                                              controller: litersController,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: 'Cantidad',
                                                labelStyle: TextStyle(
                                                  fontSize: screenWidth * 0.032,
                                                ),
                                                border: OutlineInputBorder(),
                                                suffixText: 'L',
                                                suffixStyle: TextStyle(
                                                  fontSize: screenWidth * 0.032,
                                                ),
                                              ),
                                              style: TextStyle(
                                                fontSize: screenWidth * 0.032,
                                              ),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: Text(
                                              'Cancelar',
                                              style: TextStyle(
                                                  fontSize:
                                                      screenWidth * 0.030),
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              String liters =
                                                  litersController.text;
                                              debugPrint(
                                                  "Tipo de combustible: $selectedFuel");
                                              debugPrint(
                                                  "Cantidad de litros: $liters L");
                                              Navigator.of(context).pop();
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF0886B5),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 10),
                                            ),
                                            child: Text(
                                              'Guardar',
                                              style: TextStyle(
                                                  fontSize:
                                                      screenWidth * 0.030),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                icon: const Icon(Icons.local_gas_station),
                                label: const Text('Combustible'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0886B5),
                                  foregroundColor: Colors.white,
                                  textStyle:
                                      TextStyle(fontSize: screenWidth * 0.030),
                                ),
                              ),
                            const SizedBox(width: 5),
                            if (step['typStep'] != 1 &&
                                step['typStep'] != 4 &&
                                step['typStep'] != 3 &&
                                step['typStep'] != 5)
                              ElevatedButton.icon(
                                onPressed: () {
                                  final String? clientId =
                                      step['idClient']?.toString();
                                  if (clientId != null) {
                                    setState(() {
                                      showCheckButton = false;
                                    });

                                    final double latitude = step['typStep'] == 5
                                        ? double.tryParse(
                                                step['lati'].toString()) ??
                                            0.0
                                        : double.tryParse(
                                                step['lat'].toString()) ??
                                            0.0;

                                    final double longitude =
                                        step['typStep'] == 5
                                            ? double.tryParse(
                                                    step['longi'].toString()) ??
                                                0.0
                                            : double.tryParse(
                                                    step['lng'].toString()) ??
                                                0.0;

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CheckVisitPage(
                                          clientId: clientId,
                                          idMainAccount: widget.idMainAccount,
                                          latitude: latitude,
                                          longitude: longitude,
                                          idRoute: _selectedRouteId ?? 0,
                                        ),
                                      ),
                                    );
                                  } else {
                                    showTopSnackBar(
                                      Overlay.of(context),
                                      Material(
                                        color: Colors.transparent,
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 20),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Color(0xFF0886B5),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.error,
                                                  color: Colors.white,
                                                  size: 24),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  "Cliente no encontrado para este paso.",
                                                  style: TextStyle(
                                                    fontSize:
                                                        screenWidth * 0.034,
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.verified),
                                label: const Text('Comprobar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0886B5),
                                  foregroundColor: Colors.white,
                                  textStyle:
                                      TextStyle(fontSize: screenWidth * 0.030),
                                ),
                              ),
                            const SizedBox(width: 5),
                            if (step['typStep'] != 1 &&
                                step['typStep'] != 4 &&
                                step['typStep'] != 3 &&
                                step['typStep'] != 5)
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    showVisitButton = false;
                                  });

                                  final double latitude = step['typStep'] == 5
                                      ? double.tryParse(
                                              step['lati'].toString()) ??
                                          0.0
                                      : double.tryParse(
                                              step['lat'].toString()) ??
                                          0.0;

                                  final double longitude = step['typStep'] == 5
                                      ? double.tryParse(
                                              step['longi'].toString()) ??
                                          0.0
                                      : double.tryParse(
                                              step['lng'].toString()) ??
                                          0.0;

                                  final String? clientId =
                                      step['idClient']?.toString();
                                  final String? routeId =
                                      step['id']?.toString();

                                  final double distanceMint = double.tryParse(
                                          step['distanceMint']?.toString() ??
                                              '0') ??
                                      0.0;

                                  final String typeRoute =
                                      step['typeRoute']?.toString() ?? '';

                                  final String nClients =
                                      step['nClients']?.toString() ?? '';

                                  if (clientId != null && routeId != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => VisitRecordPage(
                                          idMainAccount: widget.idMainAccount,
                                          latitude: latitude,
                                          longitude: longitude,
                                          idRoute: _selectedRouteId ?? 0,
                                          idAssignClients: routeId,
                                          clientId: clientId,
                                          idVehic: idVehic,
                                          distanceMint: distanceMint,
                                          typeRoute: typeRoute,
                                          nClients: nClients,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: Icon(FontAwesomeIcons.book.data),
                                label: const Text('Registrar visita'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0886B5),
                                  foregroundColor: Colors.white,
                                  textStyle:
                                      TextStyle(fontSize: screenWidth * 0.030),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  trailing: (step['typStep'] == 1)
                      ? const Icon(Icons.home)
                      : (step['typStep'] == 3)
                          ? const Icon(Icons.fastfood)
                          : (step['typStep'] == 4)
                              ? const Icon(Icons.flag)
                              : (step['typStep'] == 5)
                                  ? const Icon(Icons.local_gas_station)
                                  : (step['typStep'] == 2)
                                      ? const Icon(Icons.route)
                                      : null,
                ),
    );
  }

  String _convertToHours(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '$hours : $minutes min';
  }

  String _convertToHoursalone(int seconds) {
    final hours = seconds ~/ 3600;
    return '${hours}h ';
  }

  String _convertToKilometers(int meters) {
    final kilometers = meters / 1000;
    return kilometers.toStringAsFixed(2);
  }

  void _showMapSelectionDialog(double lat, double lng) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Selecciona',
              style: TextStyle(fontSize: screenWidth * 0.037)),
          content: Text('¿Qué aplicación deseas usar para navegar?',
              style: TextStyle(fontSize: screenWidth * 0.034)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openMap(lat, lng, useWaze: false);
              },
              child: Text('Google Maps',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openMap(lat, lng, useWaze: true);
              },
              child:
                  Text('Waze', style: TextStyle(fontSize: screenWidth * 0.030)),
            ),
          ],
        );
      },
    );
  }

  void _preloadMapData({required bool useWaze}) async {
    try {
      String preloadUrl = useWaze ? 'waze://' : 'https://maps.google.com/';
      await launch(preloadUrl);
      // ignore: empty_catches
    } catch (e) {}
  }

  void _openMap(double lat, double lng, {required bool useWaze}) async {
    _preloadMapData(useWaze: useWaze);
    try {
      String url = useWaze
          ? 'waze://?ll=$lat,$lng&navigate=yes'
          : 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';

      await launch(url);
    } catch (e) {
      String fallbackUrl =
          useWaze ? 'https://www.waze.com/ul?ll=$lat,$lng&navigate=yes' : '';

      if (fallbackUrl.isNotEmpty) {
        try {
          await launch(fallbackUrl);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'No se puede abrir ${useWaze ? "Waze" : "Google Maps"} ni el navegador.')),
          );
          final screenWidth = MediaQuery.of(context).size.width;

          showTopSnackBar(
            Overlay.of(context),
            Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF0886B5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "No se puede abrir ${useWaze ? "Waze" : "Google Maps"} ni el navegador.",
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
    }
  }

  Future<void> _checkAndOpenMap(double lat, double lng,
      {required bool useWaze}) async {
    String googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
    String wazeUrl = 'waze://?ll=$lat,$lng&navigate=yes';
    String wazeFallbackUrl =
        'https://www.waze.com/ul?ll=$lat,$lng&navigate=yes';

    if (useWaze) {
      if (await canLaunch(wazeUrl)) {
        await launch(wazeUrl);
      } else if (await canLaunch(wazeFallbackUrl)) {
        await launch(wazeFallbackUrl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se puede abrir Waze ni el navegador.')),
        );
        final screenWidth = MediaQuery.of(context).size.width;
        showTopSnackBar(
          Overlay.of(context),
          Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF0886B5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "No se puede abrir Waze ni el navegador.",
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
    } else {
      if (await canLaunch(googleMapsUrl)) {
        await launch(googleMapsUrl);
      } else {
        final screenWidth = MediaQuery.of(context).size.width;
        showTopSnackBar(
          Overlay.of(context),
          Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF0886B5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "No se puede abrir Google Maps ni el navegador.",
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
  }
}
