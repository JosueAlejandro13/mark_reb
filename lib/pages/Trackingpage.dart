import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lottie/lottie.dart' show Lottie;
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/Error_/TrackingErrorPage.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import 'package:mark_v3/services/ConnectionTracking_/TrackingCon_service.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

//Autor: Josue Hernandez
class TrackingPage extends StatefulWidget {
  final String userId;

  const TrackingPage({super.key, required this.userId});

  @override
  _TrackingPageState createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage>
    with TickerProviderStateMixin {
  final TrackingconService dbService = TrackingconService();
  late GoogleMapController _mapController;
  LatLng mapCenter = const LatLng(19.4326, -99.1332);
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> devices = [];
  late AnimationController _animationController;
  late Animation<double> _sizeAnimation;
  Map<String, String> deviceTimeElapsed = {};
  bool _isLoading = false;
  bool isCancelled = false;
  bool _hasError = false;
  bool _hasData = false;
  Timer? _timer;
  final Map<MarkerId, Marker> _existingMarkers = {};
  final Map<String, BitmapDescriptor> _iconCache = {};
  final Map<MarkerId, String> _markerIconKeys = {};
  final Map<MarkerId, LatLng> _markerPositions = {};
  bool _isUpdating = false;
  String? _selectedVehicleId;
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _fetchTrackingData();
    _setupAnimation();
    _startPeriodicUpdates();
  }

  void _startPeriodicUpdates() {
    _timer = Timer.periodic(Duration(seconds: 2), (Timer timer) async {
      if (_isUpdating) return;
      _isUpdating = true;
      try {
        await _updateTrackingData();
      } finally {
        _isUpdating = false;
      }
    });
  }

  Future<void> _updateTrackingData() async {
    if (_selectedVehicleId == null || isCancelled) return;

    try {
      final trackingData = await dbService.obtenerTracking(_selectedVehicleId!);

      if (trackingData.isNotEmpty) {
        final updatedDevice = trackingData.first;

        if (mounted) {
          setState(() {
            devices = devices.map((device) {
              if (device['id'].toString() == _selectedVehicleId) {
                return {
                  ...device,
                  'lat': updatedDevice['lat'],
                  'lng': updatedDevice['lng'],
                  'ignStatus': updatedDevice['ignStatus'],
                  'driveStat': updatedDevice['driveStat'],
                  'dir': updatedDevice['dir'],
                };
              }
              return device;
            }).toList();
          });

          await _updateMarkers();

          LatLng newPosition = LatLng(
            double.parse(updatedDevice['lat'].toString()),
            double.parse(updatedDevice['lng'].toString()),
          );

          if (_currentPosition == null ||
              _currentPosition!.latitude != newPosition.latitude ||
              _currentPosition!.longitude != newPosition.longitude) {
            _mapController.animateCamera(
              CameraUpdate.newLatLng(newPosition),
            );

            _currentPosition = newPosition;
          }
        }
      }
    } catch (e) {
      debugPrint('Error al actualizar los datos de seguimiento: $e');
    }
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _sizeAnimation =
        Tween<double>(begin: 90.0, end: 100.0).animate(_animationController);
  }

  Future<void> _updateMarkers() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final double baseIconSize = screenWidth * 0.25;

    Set<Marker> newMarkers = {};
    bool hasChanges = false;

    final deviceIds = devices
        .map((device) => device['id']?.toString() ?? 'default_id')
        .toSet();
    _existingMarkers
        .removeWhere((markerId, _) => !deviceIds.contains(markerId.value));
    _markerIconKeys
        .removeWhere((markerId, _) => !deviceIds.contains(markerId.value));

    for (var device in devices) {
      if (device['lat'] != null && device['lng'] != null) {
        final lat = double.tryParse(device['lat']?.toString() ?? '0.0') ?? 0.0;
        final lng = double.tryParse(device['lng']?.toString() ?? '0.0') ?? 0.0;
        final driveStat = device['ignStatus'] ?? 0;
        final bool isGreen = driveStat == 1;
        final double direction =
            double.tryParse(device['dir']?.toString() ?? '0.0') ?? 0.0;

        final iconSize = isGreen ? _sizeAnimation.value : baseIconSize;
        final markerId = MarkerId(device['id']?.toString() ?? 'default_id');
        final String iconKey = '${isGreen ? "green" : "black"}_$iconSize';

        final double previousSize = double.tryParse(
                _markerIconKeys[markerId]?.split('_')[1] ?? '$baseIconSize') ??
            baseIconSize;
        if ((previousSize - iconSize).abs() < 1.0 &&
            _markerIconKeys[markerId] == iconKey) {
          newMarkers.add(_existingMarkers[markerId]!);
          continue;
        }

        LatLng newPos = LatLng(lat, lng);
        LatLng oldPos = _existingMarkers[markerId]?.position ?? newPos;

        LatLng smoothPos = LatLng(
          lerpDouble(oldPos.latitude, newPos.latitude, 0.95)!,
          lerpDouble(oldPos.longitude, newPos.longitude, 0.95)!,
        );

        final customIcon = await _getCachedIcon(
          isGreen
              ? const ui.Color.fromARGB(255, 36, 146, 39)
              : const ui.Color.fromARGB(255, 139, 139, 139),
          iconSize,
          screenWidth,
        );

        // ignore: unnecessary_null_comparison
        if (customIcon == null) {
          debugPrint(
              'Error: No se pudo obtener el ícono para el marcador ${markerId.value}');
          continue;
        }

        if (_existingMarkers.containsKey(markerId)) {
          final existingMarker = _existingMarkers[markerId]!;

          if (existingMarker.position != smoothPos ||
              existingMarker.rotation != direction ||
              _markerIconKeys[markerId] != iconKey) {
            hasChanges = true;

            final updatedMarker = existingMarker.copyWith(
              positionParam: smoothPos,
              rotationParam: direction,
              iconParam: customIcon,
            );

            newMarkers.add(updatedMarker);
            _existingMarkers[markerId] = updatedMarker;
            _markerIconKeys[markerId] = iconKey;
          } else {
            newMarkers.add(existingMarker);
          }
        } else {
          hasChanges = true;

          final newMarker = Marker(
            markerId: markerId,
            position: smoothPos,
            icon: customIcon,
            onTap: () => _showCarInfo(context, device),
            rotation: direction,
            flat: true,
            anchor: const Offset(0.5, 0.5),
          );

          newMarkers.add(newMarker);
          _existingMarkers[markerId] = newMarker;
          _markerIconKeys[markerId] = iconKey;
        }
      }
    }

    if (hasChanges && mounted) {
      if (!setEquals(_markers, newMarkers)) {
        setState(() {
          _markers = newMarkers;
        });
      }
    }
  }

  Future<BitmapDescriptor> _getCachedIcon(
      Color color, double size, double screenWidth) async {
    String key = '${color.value}_$size';

    if (_iconCache.containsKey(key)) {
      return _iconCache[key]!;
    }

    final icon = await _generateCustomMarkerIcon(
      iconSize: size,
      screenWidth: screenWidth,
      color: color,
    );

    _iconCache[key] = icon;
    return icon;
  }

  Future<BitmapDescriptor> _generateCustomMarkerIcon({
    required double iconSize,
    required double screenWidth,
    required Color color,
  }) async {
    final double markerSize = screenWidth * 0.27;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    canvas.translate(markerSize / 2, markerSize / 2);

    final ByteData data = await rootBundle.load('assets/gps.png');
    final List<int> bytes = data.buffer.asUint8List();
    final img.Image image = img.decodeImage(Uint8List.fromList(bytes))!;

    img.Image coloredImage = img.colorOffset(image,
        red: color.red, green: color.green, blue: color.blue);

    final double scaleFactor = iconSize / coloredImage.width;
    final int newWidth = (coloredImage.width * scaleFactor).toInt();
    final int newHeight = (coloredImage.height * scaleFactor).toInt();
    final img.Image resizedImage =
        img.copyResize(coloredImage, width: newWidth, height: newHeight);

    final ui.Image uiImage = await _loadUiImage(resizedImage);

    final Paint paint = Paint()
      ..colorFilter = ColorFilter.mode(color, BlendMode.modulate);

    canvas.drawImage(
      uiImage,
      Offset(-uiImage.width / 2, -uiImage.height / 2),
      paint,
    );
    final ui.Image finalImage = await pictureRecorder
        .endRecording()
        .toImage(markerSize.toInt(), markerSize.toInt());

    final dataImg = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(dataImg!.buffer.asUint8List());
  }

  Future<ui.Image> _loadUiImage(img.Image image) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(Uint8List.fromList(img.encodePng(image)), (result) {
      return completer.complete(result);
    });
    return completer.future;
  }

  Future<void> _withLoading(Future<void> Function() action) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchTrackingData() async {
    isCancelled = false;
    _hasError = false;

    await _withLoading(() async {
      try {
        final tracking = await dbService.getDevicesBySubAccount(widget.userId);

        if (isCancelled || !mounted) return;

        if (tracking.isNotEmpty) {
          debugPrint('Datos obtenidos: $tracking');

          setState(() {
            _hasData = true;
            devices = tracking;
            if (tracking.isNotEmpty) {
              double lat =
                  double.tryParse(tracking[0]['lat']?.toString() ?? '') ??
                      19.4326;
              double lng =
                  double.tryParse(tracking[0]['lng']?.toString() ?? '') ??
                      -99.1332;
              mapCenter = LatLng(lat, lng);
            }
          });

          final nowUtc = DateTime.now().toUtc();
          final nowUtcRounded = DateTime(nowUtc.year, nowUtc.month, nowUtc.day,
              nowUtc.hour, nowUtc.minute, nowUtc.second);

          debugPrint('Hora actual (UTC): $nowUtc');
          debugPrint('Hora actual redondeada (UTC): $nowUtcRounded');

          for (var device in tracking) {
            if (isCancelled || !mounted) return;

            final lastUpdate =
                int.tryParse(device['timApagado']?.toString() ?? '0') ?? 0;
            final offsetLocalHours =
                int.tryParse(device['timOper']?.toString() ?? '0') ?? 0;

            debugPrint(
                'Offset de la zona horaria local (desde timOper): $offsetLocalHours horas');

            if (lastUpdate > 0) {
              final utcDateTime = DateTime.fromMillisecondsSinceEpoch(
                  lastUpdate * 1000,
                  isUtc: true);
              debugPrint('timApagado (UTC): $utcDateTime');

              final nowLocal =
                  nowUtcRounded.add(Duration(hours: offsetLocalHours));
              final utcDateTimeLocal =
                  utcDateTime.add(Duration(hours: offsetLocalHours));

              debugPrint(
                  'Hora actual ajustada a UTC$offsetLocalHours: $nowLocal');
              debugPrint(
                  'timApagado ajustado a UTC$offsetLocalHours: $utcDateTimeLocal');

              final diferenciaLocal = nowLocal.difference(utcDateTimeLocal);

              debugPrint('Diferencia ajustada a hora local: $diferenciaLocal');

              final dias = diferenciaLocal.inDays;
              final horas = diferenciaLocal.inHours % 24;
              final minutos = diferenciaLocal.inMinutes % 60;
              final segundos = diferenciaLocal.inSeconds % 60;

              final List<String> partes = [];
              if (dias > 0) {
                partes.add('$dias días');
                if (horas > 0 || minutos > 0 || segundos > 0) {
                  partes.add('con');
                }
              }
              if (horas > 0) {
                partes.add('$horas horas');
                if (minutos > 0 || segundos > 0) {
                  partes.add(',');
                }
              }
              if (minutos > 0) {
                partes.add('$minutos minutos');
                if (segundos > 0) {
                  partes.add('y');
                }
              }
              if (segundos > 0) {
                partes.add('$segundos segundos');
              }

              final mensaje = partes.join(' ');

              debugPrint('Mensaje formateado: $mensaje');

              if (mounted) {
                setState(() {
                  deviceTimeElapsed[device['id'].toString()] = mensaje;
                });
              }

              debugPrint('Tiempo de operación ${device['id']}: $mensaje');
            } else {
              debugPrint(
                  'Tiempo de operación ${device['id']}: Timestamp no válido (lastUpdate = $lastUpdate)');
            }
          }
          _updateMarkers();
        } else {
          if (mounted) {
            setState(() {
              _hasData = false;
            });
          }
          debugPrint('No se encontraron dispositivos.');
          throw Exception("No hay datos disponibles");
        }
      } catch (e) {
        _handleError(e);
        return;
      }
    });
  }

  void _handleError(Object e) {
    if (!mounted) return;
    setState(() {
      _hasData = false;
      _hasError = true;
      _isLoading = false;
    });

    if (e.toString().contains('SocketException')) {
      debugPrint('SocketException: Error de conexión.');
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
      return;
    }

    if (e.toString().contains('TimeoutException')) {
      debugPrint('TimeoutException: Tiempo de espera excedido.');
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
      return;
    }

    if (e.toString().contains('No hay datos disponibles')) {
      if (!mounted) return;
      setState(() {
        _hasData = false;
        _hasError = true;
        _isLoading = false;
      });

      debugPrint('No hay datos disponibles.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => TrackingErrorPage(
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
    debugPrint('Error inesperado al obtener datos: $e');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => TrackingErrorPage(
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

  void cancelLoading() {
    isCancelled = true;
  }

  Future<void> _determinePosition() async {
    if (!mounted) return;

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Los servicios de ubicación están desactivados.');

      showTopSnackBar(
        Overlay.of(context),
        _buildErrorSnackBar(
          context,
          "Los servicios de ubicación están desactivados. Por favor, actívalos.",
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        Geolocator.openLocationSettings();
      });

      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Permiso de ubicación denegado.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Los permisos de ubicación están permanentemente denegados.');
      return;
    }

    Position position = await Geolocator.getCurrentPosition();

    if (!mounted) return;
    setState(() {
      mapCenter = LatLng(position.latitude, position.longitude);
    });

    debugPrint('Ubicación actual: ${position.latitude}, ${position.longitude}');
  }

  Widget _buildErrorSnackBar(BuildContext context, String message) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Material(
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
                message,
                style: TextStyle(
                  fontSize: screenWidth * 0.034,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    isCancelled = true;
    _isUpdating = false;
    super.dispose();
  }

  void _showCarInfo(BuildContext context, Map<String, dynamic> device) {
    Map<String, dynamic> deviceInfo = {
      'id': device['id'],
      'status_servidor': device['status_servidor'],
      'lat': device['lat'],
      'lng': device['lng'],
      'ignStatus': device['ignStatus'],
      'dir': device['dir'],
      'timApagado': device['timApagado'],
      'timOper': device['timOper'],
      'placas': device['placas'],
      'make': device['make'],
      'model': device['model'],
      'year': device['year'],
      'FechaConsulta': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
    };

    String deviceInfoJson = jsonEncode(deviceInfo);
    debugPrint('Datos del dispositivo en formato JSON:');
    debugPrint(deviceInfoJson);

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final ignStatus = device['ignStatus'] ?? 0;
    final BatStatus = device['BatStatus'] ?? 0;
    int timOper = int.tryParse(device['timOper'].toString()) ?? 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSection(
                  context,
                  title: 'Información del vehículo',
                  children: [
                    _buildInfoRow(Icons.car_rental, 'Placas', device['placas']),
                    _buildInfoRow(
                        Icons.directions_car, 'Marca', device['make']),
                    _buildInfoRow(
                        Icons.model_training, 'Modelo', device['model']),
                    _buildInfoRow(
                        Icons.calendar_today, 'Año', device['year'].toString()),
                  ],
                ),
                SizedBox(height: 15),
                _buildSection(
                  context,
                  title: 'Batería',
                  children: [
                    _buildInfoRow(Icons.battery_charging_full, 'Nivel de carga',
                        '${device['batc']} %'),
                    _buildInfoRow(Icons.battery_std, 'Vida de la batería',
                        '${device['bath']} %'),
                  ],
                ),
                SizedBox(height: 15),
                if (ignStatus == 0)
                  _buildSection(
                    context,
                    title: 'Estado',
                    children: [
                      Text(
                        'El vehículo está detenido hace ${deviceTimeElapsed[device['id'].toString()] ?? "calculando..."}',
                        style: TextStyle(
                          fontSize: screenWidth * 0.031,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: 15),
                _buildSection(
                  context,
                  title: 'Fecha y Hora',
                  children: [
                    _buildInfoRow(
                      Icons.access_time,
                      'Fecha y Hora',
                      DateFormat('yyyy-MM-dd HH:mm:ss').format(
                        device['fechaHora'].add(Duration(hours: timOper)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0886B5),
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor: Colors.grey.withOpacity(0.3),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cerrar',
                style: TextStyle(
                  fontSize: screenWidth * 0.030,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSection(BuildContext context,
      {required String title, required List<Widget> children}) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const ui.Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: screenWidth * 0.032,
              color: const ui.Color.fromARGB(255, 0, 0, 0),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFF0886B5), size: 15),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: screenWidth * 0.031,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: screenWidth * 0.030,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showVehicleMenu(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.4,
          minChildSize: 0.3,
          maxChildSize: 0.5,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 7,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Vehículos disponibles (${devices.length})', // Muestra el total
                    style: TextStyle(
                        fontSize: screenWidth * 0.040,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: ListView.builder(
                      // Más eficiente para listas largas
                      controller: scrollController,
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        final driveStat = device['ignStatus'] ?? 0;
                        final bool isGreen = driveStat == 1;
                        final iconColor = isGreen ? Colors.green : Colors.grey;
                        final String vehicleId = device['id'].toString();

                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: screenWidth * 0.79,
                            margin: const EdgeInsets.symmetric(
                                vertical: 1, horizontal: 1),
                            child: Card(
                              color: Colors.white,
                              elevation: 5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 2),
                                leading: Icon(Icons.directions_car,
                                    color: iconColor, size: 22),
                                title: Text(
                                  device['economico'] ?? 'Sin nombre',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.032,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                trailing: Icon(
                                  isGreen
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: iconColor,
                                  size: 22,
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  setState(() {
                                    _selectedVehicleId = vehicleId;
                                  });

                                  LatLng newPos = LatLng(
                                    double.tryParse(device['lat'].toString()) ??
                                        19.4326,
                                    double.tryParse(device['lng'].toString()) ??
                                        -99.1332,
                                  );

                                  _mapController.animateCamera(
                                    CameraUpdate.newLatLng(newPos),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double appBarHeight = 30.0;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: ui.Color.fromARGB(255, 0, 0, 0),
              size: 19,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Stack(
        children: [
          if (!_hasError && _hasData)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: mapCenter,
                zoom: 15.0,
              ),
              markers: _selectedVehicleId == null
                  ? {}
                  : _markers
                      .where((marker) =>
                          marker.markerId.value == _selectedVehicleId)
                      .toSet(),
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                _moveCameraToUserLocation();
              },
            ),
          if (_isLoading)
            Center(
              child: Lottie.asset(
                'assets/loading.json',
                width: screenWidth * 0.2,
                height: screenWidth * 0.2,
                repeat: true,
              ),
            )
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showVehicleMenu(context),
        child: const Icon(Icons.menu),
        backgroundColor: const Color(0xFF0886B5),
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _moveCameraToUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      LatLng userLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        mapCenter = userLocation;
      });

      double zoomLevel = 15.0;

      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(userLocation, zoomLevel),
      );
    } catch (e) {
      debugPrint("Error al obtener ubicación: $e");

      double defaultZoomLevel = 10.0;
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(mapCenter, defaultZoomLevel),
      );
    }
  }
}
