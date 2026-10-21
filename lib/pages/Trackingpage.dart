import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:mark_v3/providers/Tracking_/tracking_provider.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';
import 'package:mark_v3/pages/Error_/TrackingErrorPage.dart';
import 'package:mark_v3/widgets/vehicle_commands_sheet.dart';
import 'package:mark_v3/widgets/vehicle_alerts_sheet.dart';
import 'package:mark_v3/services/mark_api_client.dart';

// Autor: Josue Hernandez - Reboot Completo con Riverpod y Diseño Ejecutivo
class TrackingPage extends ConsumerStatefulWidget {
  final String userId;

  const TrackingPage({super.key, required this.userId});

  @override
  ConsumerState<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends ConsumerState<TrackingPage>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Map<String, BitmapDescriptor> _markerIconCache = {};
  Set<Marker> _markers = {};
  late AnimationController _pulseController;
  bool _initialPositionSet = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trackingProvider.notifier).loadDevices(widget.userId);
      if (MarkApiClient.instance.currentSession == null) {
        MarkApiClient.instance.pingYo().then((_) {
          if (mounted) setState(() {});
        }).catchError((_) {});
      }
    });
  }



  @override
  void dispose() {
    _pulseController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  double _parseCoordinate(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    String s = val.toString().trim();
    if (s.startsWith('+')) {
      s = s.substring(1).trim();
    }
    if (s.endsWith('.')) {
      s = '${s}0';
    }
    return double.tryParse(s) ?? fallback;
  }

  Future<BitmapDescriptor> _getMarkerIcon({
    required bool isGreen,
    required double direction,
  }) async {
    // Normalizar dirección a pasos de 15 grados para optimizar caché
    final int roundedDirection = (direction / 15).round() * 15;
    final String cacheKey = '${isGreen ? "green" : "grey"}_$roundedDirection';

    if (_markerIconCache.containsKey(cacheKey)) {
      return _markerIconCache[cacheKey]!;
    }

    final icon = await _drawCustomMarker(
      isGreen: isGreen,
      direction: direction,
    );
    _markerIconCache[cacheKey] = icon;
    return icon;
  }

  Future<BitmapDescriptor> _drawCustomMarker({
    required bool isGreen,
    required double direction,
  }) async {
    const double size = 96.0;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final primaryColor = isGreen
        ? const Color(0xFF10B981) // Verde esmeralda moderno
        : const Color(0xFF64748B); // Slate profesional
    final ringColor = isGreen
        ? const Color(0xFF10B981).withOpacity(0.25)
        : const Color(0xFF64748B).withOpacity(0.20);

    // Halo exterior de pulso
    final Paint pulsePaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        const Offset(size / 2, size / 2), size * 0.44, pulsePaint);

    // Sombra del marcador
    final Path shadowPath = Path()
      ..addOval(Rect.fromCircle(
        center: const Offset(size / 2, size / 2 + 3),
        radius: size * 0.32,
      ));
    canvas.drawShadow(shadowPath, Colors.black.withOpacity(0.35), 6.0, false);

    // Círculo blanco de fondo
    final Paint whiteBgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        const Offset(size / 2, size / 2), size * 0.32, whiteBgPaint);

    // Círculo principal con color de estado
    final Paint circlePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        const Offset(size / 2, size / 2), size * 0.26, circlePaint);

    // Borde blanco interior
    final Paint innerBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(
        const Offset(size / 2, size / 2), size * 0.26, innerBorderPaint);

    // Flecha / Indicador de dirección orientada
    canvas.save();
    canvas.translate(size / 2, size / 2);
    canvas.rotate((direction * pi) / 180.0);

    final Paint arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final Path arrowPath = Path()
      ..moveTo(0, -size * 0.16)
      ..lineTo(size * 0.11, size * 0.12)
      ..lineTo(0, size * 0.05)
      ..lineTo(-size * 0.11, size * 0.12)
      ..close();

    canvas.drawPath(arrowPath, arrowPaint);
    canvas.restore();

    final ui.Image image = await pictureRecorder.endRecording().toImage(
          size.toInt(),
          size.toInt(),
        );
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      return BitmapDescriptor.defaultMarker;
    }
    return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
  }

  Future<void> _buildMarkers(List<Map<String, dynamic>> devices) async {
    final Set<Marker> newMarkers = {};

    for (final device in devices) {
      final lat = _parseCoordinate(device['lat']);
      final lng = _parseCoordinate(device['lng']);

      if (lat == 0.0 && lng == 0.0) continue;

      final bool isGreen = (device['ignStatus'] ?? 0) == 1;
      final double direction =
          double.tryParse(device['dir']?.toString() ?? '0.0') ?? 0.0;
      final markerId = MarkerId(device['id'].toString());

      final icon = await _getMarkerIcon(
        isGreen: isGreen,
        direction: direction,
      );

      newMarkers.add(
        Marker(
          markerId: markerId,
          position: LatLng(lat, lng),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: 0.0, // La orientación ya se dibujó en el icono
          infoWindow: InfoWindow(
            title: (device['economico'] ??
                    device['eco'] ??
                    device['name'] ??
                    'Vehículo')
                .toString(),
            snippet: isGreen ? 'En marcha' : 'Motor detenido',
            onTap: () => _showVehicleFullDetails(context, device),
          ),
          onTap: () {
            ref
                .read(trackingProvider.notifier)
                .selectVehicle(device['id'].toString());
            _animateCameraToPosition(LatLng(lat, lng), 16.5);
          },
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }

  void _animateCameraToPosition(LatLng position, [double zoom = 16.0]) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: zoom),
      ),
    );
  }

  void _fitAllVehicles(List<Map<String, dynamic>> devices) {
    final validPoints = devices
        .map((d) =>
            LatLng(_parseCoordinate(d['lat']), _parseCoordinate(d['lng'])))
        .where((pos) => pos.latitude != 0.0 && pos.longitude != 0.0)
        .toList();

    if (validPoints.isEmpty) return;

    if (validPoints.length == 1) {
      _animateCameraToPosition(validPoints.first, 15.5);
      return;
    }

    double minLat = validPoints.map((p) => p.latitude).reduce(min);
    double maxLat = validPoints.map((p) => p.latitude).reduce(max);
    double minLng = validPoints.map((p) => p.longitude).reduce(min);
    double maxLng = validPoints.map((p) => p.longitude).reduce(max);

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80.0,
      ),
    );
  }

  Future<void> _centerOnUserLocation() async {
    try {
      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.denied ||
          hasPermission == LocationPermission.deniedForever) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied ||
            req == LocationPermission.deniedForever) {
          _showSnackBar(
            'Permiso de ubicación denegado.',
            isError: true,
          );
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition();
      _animateCameraToPosition(
        LatLng(position.latitude, position.longitude),
        16.0,
      );
    } catch (e) {
      _showSnackBar('No se pudo obtener la ubicación actual: $e',
          isError: true);
    }
  }

  void _showSnackBar(String text, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      SnackbarTop.showError(context, text);
    } else {
      SnackbarTop.showInfo(context, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isSmallScreen = mediaQuery.size.width < 360;

    final trackingState = ref.watch(trackingProvider);
    final notifier = ref.read(trackingProvider.notifier);

    // Reconstruir marcadores si los dispositivos cambiaron
    ref.listen<TrackingState>(trackingProvider, (prev, next) {
      if (prev?.devices != next.devices) {
        _buildMarkers(next.devices);

        // Primera vez que llegan datos, encuadrar la flota
        if (!_initialPositionSet && next.devices.isNotEmpty) {
          _initialPositionSet = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fitAllVehicles(next.devices);
          });
        }

        // Si hay una unidad seleccionada y está en marcha, seguir suavemente con la cámara
        if (next.selectedVehicleId != null) {
          final sel = next.selectedVehicle;
          if (sel != null && (sel['ignStatus'] ?? 0) == 1) {
            final lat = _parseCoordinate(sel['lat']);
            final lng = _parseCoordinate(sel['lng']);
            if (lat != 0.0 && lng != 0.0) {
              _mapController?.animateCamera(
                CameraUpdate.newLatLng(LatLng(lat, lng)),
              );
            }
          }
        }
      }
    });

    final selectedDevice = trackingState.selectedVehicle;

    // Si los dispositivos ya están cargados pero aún no se dibujaron los marcadores
    if (_markers.isEmpty && trackingState.devices.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _markers.isEmpty) {
          _buildMarkers(trackingState.devices);
        }
      });
    }

    // Calcular posición inicial para el mapa
    LatLng initialTarget = const LatLng(19.4326, -99.1332);
    if (trackingState.devices.isNotEmpty) {
      final firstLat = _parseCoordinate(trackingState.devices[0]['lat']);
      final firstLng = _parseCoordinate(trackingState.devices[0]['lng']);
      if (firstLat != 0.0 && firstLng != 0.0) {
        initialTarget = LatLng(firstLat, firstLng);
      }
    }

    if (trackingState.hasError && !trackingState.isLoading) {
      return TrackingErrorPage(
        onRetry: () => notifier.loadDevices(widget.userId),
      );
    }

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        body: Stack(
          children: [
            // MAPA DE GOOGLE PRINCIPAL
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialTarget,
                zoom: 14.5,
              ),
              mapType: trackingState.mapType,
              trafficEnabled: trackingState.showTraffic,
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              padding: EdgeInsets.only(
                top: mediaQuery.padding.top + 72,
                bottom: selectedDevice != null ? 245 : 20,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                if (trackingState.devices.isNotEmpty) {
                  _fitAllVehicles(trackingState.devices);
                }
              },
              onTap: (_) {
                // Al pulsar el mapa, deseleccionar si se quiere ocultar la tarjeta
                if (trackingState.selectedVehicleId != null) {
                  notifier.selectVehicle(null);
                }
              },
            ),

            // BARRA SUPERIOR EJECUTIVA FLOTANTE
            Positioned(
              top: mediaQuery.padding.top + 8,
              left: isSmallScreen ? 10 : 16,
              right: isSmallScreen ? 10 : 16,
              child: _buildFloatingTopBar(
                context,
                trackingState,
                notifier,
                isSmallScreen,
              ),
            ),

            // CONTROLES LATERALES FLOTANTES (Derecha)
            Positioned(
              right: isSmallScreen ? 10 : 16,
              top: mediaQuery.padding.top + 76,
              child: _buildFloatingMapControls(
                context,
                trackingState,
                notifier,
              ),
            ),

            // TARJETA INFERIOR FLOTANTE DE VEHÍCULO SELECCIONADO
            if (selectedDevice != null)
              Positioned(
                left: isSmallScreen ? 10 : 16,
                right: isSmallScreen ? 10 : 16,
                bottom: mediaQuery.padding.bottom + 12,
                child: _buildSelectedVehicleCard(
                  context,
                  selectedDevice,
                  trackingState,
                  notifier,
                  isSmallScreen,
                ),
              ),

            // SKELETON Y LOADING FLOTANTE APPLE
            if (trackingState.isLoading) ...[
              // Shimmer bar flotante superior
              Positioned(
                top: mediaQuery.padding.top + 8,
                left: isSmallScreen ? 10 : 16,
                right: isSmallScreen ? 10 : 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: const [
                      AppShimmerBox(width: 36, height: 36, borderRadius: 12),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppShimmerBox.text(width: 130, height: 14),
                            SizedBox(height: 5),
                            AppShimmerBox.text(width: 190, height: 10),
                          ],
                        ),
                      ),
                      SizedBox(width: 10),
                      AppShimmerBox(width: 48, height: 32, borderRadius: 10),
                    ],
                  ),
                ),
              ),

              // Card de carga central estilo Apple
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppShimmerBox.circular(size: 38),
                      const SizedBox(height: 16),
                      const Text(
                        'Conectando con la flota...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Obteniendo posiciones GPS en tiempo real',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // BARRA SUPERIOR FLOTANTE
  Widget _buildFloatingTopBar(
    BuildContext context,
    TrackingState state,
    TrackingNotifier notifier,
    bool isSmallScreen,
  ) {
    final activeCount = state.movingCount;
    final totalCount = state.devices.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Botón Atrás
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 15,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Título e Indicador En Vivo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Monitoreo en Vivo',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    // Punto pulsante verde
                    FadeTransition(
                      opacity: _pulseController,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      totalCount == 0
                          ? 'Buscando...'
                          : '$totalCount Unidades ($activeCount en marcha)',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Botón Recargar Flota Manual
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                notifier.loadDevices(widget.userId);
                _showSnackBar('Actualizando lista de unidades...');
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: Color(0xFF0284C7),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Botón Lista de Flota
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showFleetModalSheet(context, state, notifier),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.directions_car_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$totalCount',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
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

  // CONTROLES LATERALES FLOTANTES DEL MAPA
  Widget _buildFloatingMapControls(
    BuildContext context,
    TrackingState state,
    TrackingNotifier notifier,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cambiar tipo de mapa
          _buildMapControlButton(
            icon: Icons.layers_rounded,
            tooltip: 'Tipo de Mapa',
            isActive: state.mapType != MapType.normal,
            onTap: () {
              notifier.toggleMapType();
              final label = switch (state.mapType) {
                MapType.normal => 'Vista Híbrida / Satélite',
                MapType.hybrid => 'Vista Terreno',
                _ => 'Vista Estándar',
              };
              _showSnackBar(label);
            },
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Tráfico en vivo
          _buildMapControlButton(
            icon: Icons.traffic_rounded,
            tooltip: 'Tráfico en tiempo real',
            isActive: state.showTraffic,
            onTap: () {
              notifier.toggleTraffic();
              _showSnackBar(
                state.showTraffic
                    ? 'Capa de tráfico desactivada'
                    : 'Capa de tráfico activada',
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Encuadrar toda la flota
          _buildMapControlButton(
            icon: Icons.zoom_out_map_rounded,
            tooltip: 'Ver toda la flota',
            isActive: false,
            onTap: () {
              _fitAllVehicles(state.devices);
              _showSnackBar('Enfocando toda la flota');
            },
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Centrar en ubicación del usuario (GPS)
          _buildMapControlButton(
            icon: Icons.my_location_rounded,
            tooltip: 'Mi ubicación GPS',
            isActive: false,
            onTap: _centerOnUserLocation,
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Alertas de Telemetría GPS de toda la flota
          _buildMapControlButton(
            icon: Icons.notifications_active_rounded,
            tooltip: 'Alertas GPS de la flota',
            isActive: false,
            onTap: () {
              VehicleAlertsSheet.show(
                context,
                title: 'Alertas de Flota',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color:
                  isActive ? const Color(0xFF0284C7) : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  // TARJETA INFERIOR DE VEHÍCULO SELECCIONADO
  Widget _buildSelectedVehicleCard(
    BuildContext context,
    Map<String, dynamic> device,
    TrackingState state,
    TrackingNotifier notifier,
    bool isSmallScreen,
  ) {
    final bool isGreen = (device['ignStatus'] ??
            (device['ignition'] == true ? 1 : 0)) ==
        1;
    final String economico = (device['economico'] ??
            device['eco'] ??
            device['name'] ??
            'Sin nombre')
        .toString();
    final String placas = (device['placas'] ?? device['plates'] ?? '').toString();
    final String make =
        (device['make'] ?? device['marca'] ?? device['brand'] ?? '').toString();
    final String model = (device['model'] ?? device['modelo'] ?? '').toString();
    final rawBat = (device['bateria'] ?? device['batc'] ?? '').toString();
    final String battery;
    if (rawBat.isEmpty || rawBat == '0' || rawBat == '0.0') {
      battery = '--';
    } else if (rawBat.contains('.') ||
        ((double.tryParse(rawBat) ?? 0) <= 24 &&
            (double.tryParse(rawBat) ?? 0) >= 9)) {
      battery = '${rawBat}V';
    } else {
      battery = '$rawBat%';
    }
    final String elapsed =
        state.deviceTimeElapsed[device['id'].toString()] ?? 'En línea';

    final lat = _parseCoordinate(device['lat']);
    final lng = _parseCoordinate(device['lng']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila Superior: Icono de marca, Nombre, Placa, Estado y Cerrar
          Row(
            children: [
              // Avatar de Vehículo
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isGreen
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isGreen
                        ? const Color(0xFF10B981).withOpacity(0.3)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Icon(
                  Icons.directions_car_rounded,
                  color: isGreen
                      ? const Color(0xFF10B981)
                      : const Color(0xFF64748B),
                  size: 24,
                ),
              ),

              const SizedBox(width: 12),

              // Datos principales
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            economico,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (placas.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              placas,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      make.isNotEmpty || model.isNotEmpty
                          ? '$make $model'.trim()
                          : 'Unidad de flota',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Chip de Estado (En marcha / Detenido)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isGreen
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isGreen
                        ? const Color(0xFF10B981).withOpacity(0.3)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isGreen
                            ? const Color(0xFF10B981)
                            : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isGreen ? 'En marcha' : 'Detenido',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isGreen
                            ? const Color(0xFF047857)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Fila de Métricas Rápidas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricPill(
                icon: Icons.power_settings_new_rounded,
                iconColor:
                    isGreen ? const Color(0xFF10B981) : const Color(0xFF64748B),
                label: 'Motor',
                value: isGreen ? 'Encendido' : 'Apagado',
              ),
              Container(width: 1, height: 26, color: const Color(0xFFF1F5F9)),
              _buildMetricPill(
                icon: Icons.battery_charging_full_rounded,
                iconColor: const Color(0xFF0284C7),
                label: 'Batería',
                value: battery,
              ),
              Container(width: 1, height: 26, color: const Color(0xFFF1F5F9)),
              _buildMetricPill(
                icon: Icons.access_time_rounded,
                iconColor: const Color(0xFFF59E0B),
                label: 'Tiempo',
                value: elapsed,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Botones de Acción
          Row(
            children: [
              // Botón Ver Ficha Completa
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: () => _showVehicleFullDetails(context, device),
                    icon: const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFF0284C7),
                    ),
                    label: const Text(
                      'Ficha Completa',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFF0284C7), width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Botón Centrar en Mapa
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (lat != 0.0 && lng != 0.0) {
                        _animateCameraToPosition(LatLng(lat, lng), 17.0);
                      }
                    },
                    icon: const Icon(
                      Icons.navigation_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Centrar en Mapa',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final idVehic = int.tryParse(device['id'].toString()) ?? 0;
                      VehicleCommandsSheet.show(
                        context,
                        idVehic: idVehic,
                        vehicleName: economico,
                        plates: placas,
                      );
                    },
                    icon: const Icon(
                      Icons.power_settings_new_rounded,
                      size: 15,
                      color: Color(0xFFDC2626),
                    ),
                    label: const Text(
                      'Comando',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEF2F2),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final idVehic = int.tryParse(device['id'].toString()) ?? 0;
                      VehicleAlertsSheet.show(
                        context,
                        idVehic: idVehic,
                        title: 'Alertas · $economico',
                      );
                    },
                    icon: const Icon(
                      Icons.warning_amber_rounded,
                      size: 15,
                      color: Color(0xFFD97706),
                    ),
                    label: const Text(
                      'Alertas',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD97706),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFFBEB),
                      side: const BorderSide(color: Color(0xFFFDE68A)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // MODAL BOTTOM SHEET: FLOTA DE VEHÍCULOS
  void _showFleetModalSheet(
    BuildContext context,
    TrackingState state,
    TrackingNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.35,
          maxChildSize: 0.90,
          builder: (_, scrollController) {
            return Consumer(
              builder: (context, ref, _) {
                final curState = ref.watch(trackingProvider);
                final curNotifier = ref.read(trackingProvider.notifier);
                final filtered = curState.filteredDevices;

                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Título del modal
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Flota de Unidades',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${curState.devices.length}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFF64748B),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),

                      // Buscador
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        child: TextFormField(
                          initialValue: curState.searchQuery,
                          onChanged: curNotifier.setSearchQuery,
                          decoration: InputDecoration(
                            hintText: 'Buscar por económico, placas o marca...',
                            hintStyle: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF94A3B8),
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: Color(0xFF0284C7),
                            ),
                            suffixIcon: curState.searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 18,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    onPressed: () =>
                                        curNotifier.setSearchQuery(''),
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF0284C7),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Filtros Rápidos (Todos / En Marcha / Detenidos)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            _buildFilterChip(
                              label: 'Todos (${curState.devices.length})',
                              isSelected: curState.statusFilter == 'all',
                              onTap: () => curNotifier.setStatusFilter('all'),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'En marcha (${curState.movingCount})',
                              isSelected: curState.statusFilter == 'moving',
                              activeColor: const Color(0xFF10B981),
                              onTap: () =>
                                  curNotifier.setStatusFilter('moving'),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Detenidos (${curState.stoppedCount})',
                              isSelected: curState.statusFilter == 'stopped',
                              activeColor: const Color(0xFF64748B),
                              onTap: () =>
                                  curNotifier.setStatusFilter('stopped'),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 6),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),

                      // Lista de Vehículos o Skeleton
                      Expanded(
                        child: curState.isLoading
                            ? ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                itemCount: 5,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, __) =>
                                    _buildFleetSkeletonTile(),
                              )
                            : filtered.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No se encontraron unidades coincidentes.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    controller: scrollController,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final dev = filtered[index];
                                      final bool isGreen =
                                          (dev['ignStatus'] ?? 0) == 1;
                                      final isSelected = dev['id'].toString() ==
                                          curState.selectedVehicleId;

                                      return _buildFleetVehicleTile(
                                        device: dev,
                                        isGreen: isGreen,
                                        isSelected: isSelected,
                                        elapsed: curState.deviceTimeElapsed[
                                                dev['id'].toString()] ??
                                            'En línea',
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          curNotifier.selectVehicle(
                                              dev['id'].toString());

                                          final lat =
                                              _parseCoordinate(dev['lat']);
                                          final lng =
                                              _parseCoordinate(dev['lng']);
                                          if (lat != 0.0 && lng != 0.0) {
                                            _animateCameraToPosition(
                                              LatLng(lat, lng),
                                              16.5,
                                            );
                                          }
                                        },
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
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    Color activeColor = const Color(0xFF0284C7),
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.12)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? activeColor : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildFleetSkeletonTile() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: const [
          AppShimmerBox(width: 38, height: 38, borderRadius: 10),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerBox.text(width: 110, height: 13),
                SizedBox(height: 5),
                AppShimmerBox.text(width: 150, height: 10),
              ],
            ),
          ),
          AppShimmerBox(width: 44, height: 20, borderRadius: 10),
        ],
      ),
    );
  }

  Widget _buildFleetVehicleTile({
    required Map<String, dynamic> device,
    required bool isGreen,
    required bool isSelected,
    required String elapsed,
    required VoidCallback onTap,
  }) {
    final String economico = (device['economico'] ??
            device['eco'] ??
            device['name'] ??
            'Sin nombre')
        .toString();
    final String placas = (device['placas'] ?? device['plates'] ?? '').toString();
    final String make =
        (device['make'] ?? device['marca'] ?? device['brand'] ?? '').toString();
    final String model = (device['model'] ?? device['modelo'] ?? '').toString();
    final String battery = '${device['batc'] ?? device['bateria'] ?? 0}%';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0284C7).withOpacity(0.04)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0284C7)
                  : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Icono de estatus
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isGreen
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.directions_car_rounded,
                  color: isGreen
                      ? const Color(0xFF10B981)
                      : const Color(0xFF94A3B8),
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              // Nombre y detalles
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            economico,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (placas.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(5),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              placas,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$make $model'.trim().isNotEmpty
                          ? '$make $model'.trim()
                          : 'Unidad de flota',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Batería y Estatus
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.battery_charging_full_rounded,
                        size: 14,
                        color: Color(0xFF0886B5),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        battery,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isGreen
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isGreen ? 'En marcha' : 'Detenido',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isGreen
                            ? const Color(0xFF059669)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MODAL BOTTOM SHEET: FICHA COMPLETA DEL VEHÍCULO
  void _showVehicleFullDetails(
    BuildContext context,
    Map<String, dynamic> device,
  ) {
    final bool isGreen = (device['ignStatus'] ??
            (device['ignition'] == true ? 1 : 0)) ==
        1;
    final String economico = (device['economico'] ??
            device['eco'] ??
            device['name'] ??
            'Sin nombre')
        .toString();
    final String placas = (device['placas'] ?? device['plates'] ?? '').toString();
    final String make =
        (device['make'] ?? device['marca'] ?? device['brand'] ?? '').toString();
    final String model = (device['model'] ?? device['modelo'] ?? '').toString();
    final String year = (device['year'] ?? device['anio'] ?? '').toString();
    final String battery = '${device['batc'] ?? device['bateria'] ?? 0}%';
    final String batteryHealth =
        '${device['bath'] ?? device['saludBateria'] ?? 0}%';
    final String latStr = device['lat']?.toString() ?? 'N/A';
    final String lngStr = device['lng']?.toString() ?? 'N/A';
    final String dirStr =
        '${device['dir'] ?? device['rumbo'] ?? device['course'] ?? 0}°';
    final String subAccount = (device['idSubAccount'] ??
            device['idEmpresa'] ??
            device['subcuenta'] ??
            'N/A')
        .toString();

    // Formatear Fecha y Hora
    String fechaHoraStr = 'N/A';
    final rawFecha =
        device['fechaHora'] ?? device['fecha'] ?? device['lastUpdate'];
    if (rawFecha != null && rawFecha.toString().isNotEmpty) {
      try {
        final parsed = DateTime.tryParse(rawFecha.toString());
        if (parsed != null) {
          fechaHoraStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(parsed);
        } else {
          fechaHoraStr = rawFecha.toString();
        }
      } catch (_) {
        fechaHoraStr = rawFecha.toString();
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.70,
          minChildSize: 0.40,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header Ficha
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  economico,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                if (placas.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    child: Text(
                                      placas,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$make $model ($year)'.trim(),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // Contenido con Scroll
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      children: [
                        // Grupo 1: Identificación
                        _buildDetailSectionCard(
                          title: 'IDENTIFICACIÓN DEL VEHÍCULO',
                          icon: Icons.badge_outlined,
                          rows: [
                            _DetailRowItem(
                                label: 'Económico', value: economico),
                            _DetailRowItem(label: 'Placas', value: placas),
                            _DetailRowItem(label: 'Marca', value: make),
                            _DetailRowItem(label: 'Modelo', value: model),
                            _DetailRowItem(label: 'Año', value: year),
                            _DetailRowItem(
                                label: 'SubCuenta ID', value: subAccount),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Grupo 2: Telemetría y Batería
                        _buildDetailSectionCard(
                          title: 'TELEMETRÍA Y SISTEMA ELÉCTRICO',
                          icon: Icons.electric_car_outlined,
                          rows: [
                            _DetailRowItem(
                              label: 'Estado del Motor',
                              value: isGreen
                                  ? 'Encendido / En marcha'
                                  : 'Apagado / Detenido',
                              customColor: isGreen
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF64748B),
                            ),
                            _DetailRowItem(
                              label: 'Nivel de Batería',
                              value: battery,
                              customColor: const Color(0xFF0284C7),
                            ),
                            _DetailRowItem(
                              label: 'Salud de Batería',
                              value: batteryHealth,
                            ),
                            _DetailRowItem(
                              label: 'Dirección Cardinal',
                              value: dirStr,
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Grupo 3: Posicionamiento y Fecha
                        _buildDetailSectionCard(
                          title: 'LOCALIZACIÓN Y TIEMPO',
                          icon: Icons.location_on_outlined,
                          rows: [
                            _DetailRowItem(label: 'Latitud', value: latStr),
                            _DetailRowItem(label: 'Longitud', value: lngStr),
                            _DetailRowItem(
                              label: 'Última Transmisión',
                              value: fechaHoraStr,
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Botón de Centrar
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              final lat = _parseCoordinate(device['lat']);
                              final lng = _parseCoordinate(device['lng']);
                              if (lat != 0.0 && lng != 0.0) {
                                _animateCameraToPosition(
                                  LatLng(lat, lng),
                                  17.0,
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.my_location_rounded,
                              size: 17,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Enfocar en Mapa',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildDetailSectionCard({
    required String title,
    required IconData icon,
    required List<_DetailRowItem> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ...rows.map((row) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF8FAFC)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    row.label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    row.value,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: row.customColor ?? const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DetailRowItem {
  final String label;
  final String value;
  final Color? customColor;

  const _DetailRowItem({
    required this.label,
    required this.value,
    this.customColor,
  });
}
