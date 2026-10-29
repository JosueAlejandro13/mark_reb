import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mark_v3/models/Custodia_/custodia_models.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/pages/Custodia_/custodia_claves_page.dart';
import 'package:url_launcher/url_launcher.dart';

/// Decodificador estándar de Google Encoded Polyline Algorithm (Polyline5)
/// Documentación Mark V3.1 (Pág. 6): "formato: polyline5, polilinea: ... , corredorM: 500"
class Polyline5Decoder {
  Polyline5Decoder._();

  static List<LatLng> decode(String encoded) {
    if (encoded.isEmpty) return const [];
    final List<LatLng> points = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    try {
      while (index < len) {
        int b;
        int shift = 0;
        int result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20 && index < len);
        final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;

        shift = 0;
        result = 0;
        do {
          if (index >= len) break;
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20 && index < len);
        final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        points.add(LatLng(lat / 1e5, lng / 1e5));
      }
    } catch (e) {
      debugPrint('[Polyline5Decoder] Error decodificando polilínea: $e');
    }
    return points;
  }
}

/// Tarjeta de Mapa de Ruta Interactiva con Polilínea y Puntos de Control (Estilo Apple)
class CustodiaRouteMapCard extends StatefulWidget {
  final CustodiaServicio servicio;

  const CustodiaRouteMapCard({
    super.key,
    required this.servicio,
  });

  @override
  State<CustodiaRouteMapCard> createState() => _CustodiaRouteMapCardState();
}

class _CustodiaRouteMapCardState extends State<CustodiaRouteMapCard> {
  GoogleMapController? _mapController;
  List<LatLng> _routePoints = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Circle> _circles = {};
  bool _isLoadingMap = true;
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    _buildMapData();
    _fetchUserLocation();
  }

  @override
  void didUpdateWidget(covariant CustodiaRouteMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.servicio.ruta?.polilinea != widget.servicio.ruta?.polilinea ||
        oldWidget.servicio.estado != widget.servicio.estado) {
      _buildMapData();
    }
  }

  Future<void> _fetchUserLocation() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null && mounted) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (_) {}
  }

  void _buildMapData() {
    final srv = widget.servicio;
    final ruta = srv.ruta;

    if (ruta == null || ruta.polilinea.isEmpty) {
      setState(() {
        _routePoints = [];
        _markers = {};
        _polylines = {};
        _circles = {};
        _isLoadingMap = false;
      });
      return;
    }

    final decoded = Polyline5Decoder.decode(ruta.polilinea);
    final markers = <Marker>{};
    final circles = <Circle>{};

    // 1. Marcador Origen
    if (srv.origen != null && srv.origen!.lat != 0.0) {
      final originPos = LatLng(srv.origen!.lat, srv.origen!.lng);
      markers.add(
        Marker(
          markerId: const MarkerId('origen'),
          position: originPos,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: '🟢 Origen: ${srv.origen!.nombre}',
            snippet: 'Punto de partida',
          ),
        ),
      );
    } else if (decoded.isNotEmpty) {
      markers.add(
        Marker(
          markerId: const MarkerId('origen_poly'),
          position: decoded.first,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(
            title: '🟢 Punto de Salida',
          ),
        ),
      );
    }

    // 2. Marcador Destino
    if (srv.destino != null && srv.destino!.lat != 0.0) {
      final destPos = LatLng(srv.destino!.lat, srv.destino!.lng);
      markers.add(
        Marker(
          markerId: const MarkerId('destino'),
          position: destPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: '🏁 Destino: ${srv.destino!.nombre}',
            snippet: 'Llegada autorizada',
          ),
        ),
      );
    } else if (decoded.isNotEmpty) {
      markers.add(
        Marker(
          markerId: const MarkerId('destino_poly'),
          position: decoded.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(
            title: '🏁 Punto de Llegada',
          ),
        ),
      );
    }

    // 3. Puntos de Control y Casetas Autorizadas
    for (int i = 0; i < ruta.puntos.length; i++) {
      final p = ruta.puntos[i];
      if (p.lat == 0.0 && p.lng == 0.0) continue;
      final pos = LatLng(p.lat, p.lng);

      markers.add(
        Marker(
          markerId: MarkerId('pc_${p.id}'),
          position: pos,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: '${i + 1}. ${p.nombre}',
            snippet: p.plan != null && p.plan!.isNotEmpty
                ? 'Plan: ${p.plan} · Radio: ${p.radioM}m'
                : 'Radio: ${p.radioM}m',
          ),
        ),
      );

      // Círculo del radio de control
      circles.add(
        Circle(
          circleId: CircleId('pc_circle_${p.id}'),
          center: pos,
          radius: p.radioM.toDouble(),
          fillColor: const Color(0xFF0284C7).withOpacity(0.12),
          strokeColor: const Color(0xFF0284C7),
          strokeWidth: 1,
        ),
      );
    }

    // 4. Polilíneas de la Ruta y Corredor Seguro (Optimizado para GPU)
    final polylines = <Polyline>{};

    if (decoded.isNotEmpty) {
      // Submuestreo inteligente para el buffer translúcido en rutas largas para evitar sobrecarga en GPU
      List<LatLng> corridorPoints = decoded;
      if (decoded.length > 600) {
        final step = (decoded.length / 350).ceil();
        final sampled = <LatLng>[];
        for (int i = 0; i < decoded.length; i += step) {
          sampled.add(decoded[i]);
        }
        if (sampled.last != decoded.last) {
          sampled.add(decoded.last);
        }
        corridorPoints = sampled;
      }

      // Buffer / Halo translúcido que representa el corredor seguro
      polylines.add(
        Polyline(
          polylineId: const PolylineId('corredor_seguro'),
          points: corridorPoints,
          color: const Color(0xFF0284C7).withOpacity(0.18),
          width: 12,
          jointType: JointType.mitered,
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
        ),
      );

      // Trazo principal de la ruta autorizada
      polylines.add(
        Polyline(
          polylineId: const PolylineId('ruta_principal'),
          points: decoded,
          color: const Color(0xFF0284C7),
          width: 4,
          jointType: JointType.bevel,
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
        ),
      );
    }

    setState(() {
      _routePoints = decoded;
      _markers = markers;
      _polylines = polylines;
      _circles = circles;
      _isLoadingMap = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _fitRouteBounds());
  }

  void _fitRouteBounds() {
    if (_mapController == null) return;
    final allPoints = <LatLng>[..._routePoints];
    for (final m in _markers) {
      allPoints.add(m.position);
    }

    if (allPoints.isEmpty) return;

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (final p in allPoints) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 42.0),
    );
  }

  Future<void> _abrirNavegadorExterno() async {
    final srv = widget.servicio;
    double? destLat;
    double? destLng;

    if (srv.destino != null && srv.destino!.lat != 0.0) {
      destLat = srv.destino!.lat;
      destLng = srv.destino!.lng;
    } else if (_routePoints.isNotEmpty) {
      destLat = _routePoints.last.latitude;
      destLng = _routePoints.last.longitude;
    }

    if (destLat == null || destLng == null) return;

    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=driving');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[CustodiaRouteMapCard] Error al abrir navegador: $e');
    }
  }

  void _abrirMapaPantallaCompleta(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustodiaFullScreenMapPage(
          title: widget.servicio.nombre.isNotEmpty
              ? widget.servicio.nombre
              : 'Ruta de Custodia (${widget.servicio.folio})',
          subtitle:
              'Corredor autorizado ±${widget.servicio.ruta?.corredorM ?? 500}m',
          routePoints: _routePoints,
          markers: _markers,
          polylines: _polylines,
          circles: _circles,
          onNavigate: _abrirNavegadorExterno,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final srv = widget.servicio;
    final ruta = srv.ruta;

    // Si el servicio no ha salido (estado < 3), la ruta es confidencial según doc oficial (Pág. 5)
    if (srv.estado < 3 || ruta == null || ruta.polilinea.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.lock_clock_rounded,
                size: 20,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ruta de traslado protegida',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Por protocolo de seguridad, la polilínea, corredor y puntos de control se trazarán en el mapa cuando el servicio pase al estado "En tránsito".',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final initialCameraPos = _routePoints.isNotEmpty
        ? CameraPosition(target: _routePoints.first, zoom: 12.0)
        : const CameraPosition(target: LatLng(19.4326, -99.1332), zoom: 12.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header del Mapa (Con protección contra overflow)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.map_rounded,
                          size: 16,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Trazado de Ruta y Corredor',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Text(
                    'Corredor ±${ruta.corredorM}m',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenedor del Mapa Google optimizado con EagerGestureRecognizer
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 220,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: initialCameraPos,
                    markers: _markers,
                    polylines: _polylines,
                    circles: _circles,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                    buildingsEnabled: false,
                    indoorViewEnabled: false,
                    tiltGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<OneSequenceGestureRecognizer>(
                          () => EagerGestureRecognizer()),
                    },
                    onMapCreated: (ctrl) {
                      _mapController = ctrl;
                      _fitRouteBounds();
                    },
                  ),

                  // Overlay con Botones de Acción Rápida (Estilo Apple Glass)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Column(
                      children: [
                        _buildGlassButton(
                          icon: Icons.fullscreen_rounded,
                          tooltip: 'Pantalla completa',
                          onTap: () => _abrirMapaPantallaCompleta(context),
                        ),
                        const SizedBox(height: 8),
                        _buildGlassButton(
                          icon: Icons.center_focus_strong_rounded,
                          tooltip: 'Ajustar a la ruta',
                          onTap: _fitRouteBounds,
                        ),
                        const SizedBox(height: 8),
                        _buildGlassButton(
                          icon: Icons.navigation_rounded,
                          tooltip: 'Navegar',
                          color: const Color(0xFF0284C7),
                          iconColor: Colors.white,
                          onTap: _abrirNavegadorExterno,
                        ),
                      ],
                    ),
                  ),

                  // Chip informativo inferior
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_outlined,
                              size: 13, color: Color(0xFF0284C7)),
                          const SizedBox(width: 5),
                          Text(
                            '${ruta.puntos.length} puntos de control en ruta',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              size: 18,
              color: iconColor ?? const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pantalla completa de Mapa de Custodia con detalles de checkpoints y navegación
class CustodiaFullScreenMapPage extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<LatLng> routePoints;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final Set<Circle> circles;
  final VoidCallback? onNavigate;

  const CustodiaFullScreenMapPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.routePoints,
    required this.markers,
    required this.polylines,
    required this.circles,
    this.onNavigate,
  });

  @override
  State<CustodiaFullScreenMapPage> createState() =>
      _CustodiaFullScreenMapPageState();
}

class _CustodiaFullScreenMapPageState extends State<CustodiaFullScreenMapPage> {
  GoogleMapController? _controller;
  MapType _currentMapType = MapType.normal;
  bool _showTraffic = true;

  @override
  Widget build(BuildContext context) {
    final initialPos = widget.routePoints.isNotEmpty
        ? CameraPosition(target: widget.routePoints.first, zoom: 13.0)
        : const CameraPosition(target: LatLng(19.4326, -99.1332), zoom: 12.0);

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: initialPos,
            mapType: _currentMapType,
            trafficEnabled: _showTraffic,
            markers: widget.markers,
            polylines: widget.polylines,
            circles: widget.circles,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (ctrl) {
              _controller = ctrl;
              _fitBounds();
            },
          ),

          // Header flotante Apple Glass
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    color: const Color(0xFF0F172A),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onNavigate != null)
                    Material(
                      color: const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: widget.onNavigate,
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            children: [
                              Icon(Icons.near_me_rounded,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Navegar',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
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
            ),
          ),

          // Controles flotantes laterales
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            right: 16,
            child: Column(
              children: [
                _buildFloatBtn(
                  icon: _showTraffic
                      ? Icons.traffic_rounded
                      : Icons.traffic_outlined,
                  tooltip: 'Tráfico',
                  active: _showTraffic,
                  onTap: () => setState(() => _showTraffic = !_showTraffic),
                ),
                const SizedBox(height: 10),
                _buildFloatBtn(
                  icon: _currentMapType == MapType.hybrid
                      ? Icons.layers_rounded
                      : Icons.layers_outlined,
                  tooltip: 'Cambiar Capa',
                  onTap: () {
                    setState(() {
                      _currentMapType = _currentMapType == MapType.normal
                          ? MapType.hybrid
                          : MapType.normal;
                    });
                  },
                ),
                const SizedBox(height: 10),
                _buildFloatBtn(
                  icon: Icons.center_focus_strong_rounded,
                  tooltip: 'Centrar Ruta',
                  onTap: _fitBounds,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _fitBounds() {
    if (_controller == null) return;
    final allPoints = <LatLng>[...widget.routePoints];
    for (final m in widget.markers) {
      allPoints.add(m.position);
    }
    if (allPoints.isEmpty) return;

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (final p in allPoints) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    _controller?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50.0,
      ),
    );
  }

  Widget _buildFloatBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0284C7) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: active ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de Mapa para Rondines (Muestra puntos de control, radios y estado de cumplimiento)
class CustodiaRondinMapCard extends StatefulWidget {
  final RondinDia rondin;
  final bool isFloatingHeader;
  final VoidCallback? onBack;
  final VoidCallback? onOpenClaves;
  final bool tieneClaves;
  final bool showTopBar;
  final double? height;

  const CustodiaRondinMapCard({
    super.key,
    required this.rondin,
    this.isFloatingHeader = false,
    this.onBack,
    this.onOpenClaves,
    this.tieneClaves = true,
    this.showTopBar = true,
    this.height,
  });

  @override
  State<CustodiaRondinMapCard> createState() => _CustodiaRondinMapCardState();
}

class _CustodiaRondinMapCardState extends State<CustodiaRondinMapCard> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Circle> _circles = {};
  Set<Polygon> _polygons = {};
  List<LatLng> _pointCoords = [];
  // Caché estática compartida a nivel de sesión de app (igual que en routes_page.dart)
  // para evitar re-renderizar los Canvas de los marcadores en cada apertura.
  static final Map<String, BitmapDescriptor> _numberedMarkerCache = {};
  static BitmapDescriptor? _cachedTruckOffIcon;
  bool _isPreloadingMarkers = false;
  bool _mapExpanded = false;
  bool _showInfoChip = true;
  bool _isTrackingVehicle = false;

  // Icono del vehículo en modo Off y telemetría de rondín
  BitmapDescriptor? _truckOffIcon;
  LatLng? _vehicleLocation;
  double _vehicleDirection = 0.0;
  Timer? _vehicleTelemetryTimer;

  @override
  void initState() {
    super.initState();
    _loadTruckOffIcon();
    _fetchVehiclePosition();
    _startVehicleTelemetryTimer();
    _buildRondinMap();
    _preloadMarkers();
  }

  @override
  void didUpdateWidget(covariant CustodiaRondinMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rondin.unidad != widget.rondin.unidad) {
      _fetchVehiclePosition();
    }
    final pointsChanged = oldWidget.rondin.puntos.length != widget.rondin.puntos.length ||
        oldWidget.rondin.cumplidos != widget.rondin.cumplidos ||
        oldWidget.rondin.puntos != widget.rondin.puntos;
    if (pointsChanged) {
      _buildRondinMap();
      _preloadMarkers();
    }
  }

  @override
  void dispose() {
    _vehicleTelemetryTimer?.cancel();
    super.dispose();
  }

  /// Carga el icono top-down del vehículo en color off (apagado / patrullaje rondín)
  Future<void> _loadTruckOffIcon() async {
    if (_cachedTruckOffIcon != null) {
      if (_truckOffIcon == null && mounted) {
        setState(() {
          _truckOffIcon = _cachedTruckOffIcon;
        });
        _buildRondinMap();
      }
      return;
    }
    try {
      final ByteData data = await rootBundle.load('assets/truck_top_off.png');
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 80,
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ByteData? byteData =
          await fi.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        _cachedTruckOffIcon =
            BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
        if (mounted) {
          setState(() {
            _truckOffIcon = _cachedTruckOffIcon;
          });
          _buildRondinMap();
        }
      }
    } catch (e) {
      debugPrint('[CustodiaRondinMapCard] Error cargando assets/truck_top_off.png: $e');
    }
  }

  void _startVehicleTelemetryTimer() {
    _vehicleTelemetryTimer?.cancel();
    _vehicleTelemetryTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _fetchVehiclePosition();
    });
  }

  Future<void> _fetchVehiclePosition() async {
    try {
      final vehiculos = await MarkApiClient.instance.getVehiculos(silent: true);
      if (vehiculos.isEmpty) return;

      final unidadStr = widget.rondin.unidad.trim().toLowerCase();
      Map<String, dynamic>? match;

      if (unidadStr.isNotEmpty) {
        for (final v in vehiculos) {
          final eco = (v['economico'] ?? v['device_name'] ?? v['nombre'] ?? '')
              .toString()
              .toLowerCase();
          final placas = (v['placas'] ?? '').toString().toLowerCase();
          final idStr = (v['idVehic'] ?? v['id'] ?? '').toString().toLowerCase();

          if ((eco.isNotEmpty && unidadStr.contains(eco)) ||
              (placas.isNotEmpty && unidadStr.contains(placas)) ||
              (idStr.isNotEmpty && unidadStr.contains(idStr))) {
            match = v;
            break;
          }
        }
      }

      // Si no hay match explícito y solo hay un vehículo en la cuenta, asociarlo
      match ??= vehiculos.first;

      final lat = double.tryParse(match['lat']?.toString() ?? '0') ?? 0.0;
      final lng = double.tryParse(match['lng']?.toString() ?? '0') ?? 0.0;
      final dir = double.tryParse(
              match['dir']?.toString() ?? match['course']?.toString() ?? '0') ??
          0.0;

      if (lat != 0.0 && lng != 0.0 && mounted) {
        final newPos = LatLng(lat, lng);
        final posChanged = _vehicleLocation != newPos || _vehicleDirection != dir;
        if (posChanged) {
          setState(() {
            _vehicleLocation = newPos;
            _vehicleDirection = dir;
          });
          _buildRondinMap();
          if (_isTrackingVehicle) {
            _animateCameraToVehicle();
          }
        }
      } else if (_vehicleLocation == null && _pointCoords.isNotEmpty && mounted) {
        // Fallback inicial si no ha reportado GPS
        setState(() {
          _vehicleLocation = _pointCoords.first;
          _vehicleDirection = 0.0;
        });
        _buildRondinMap();
        if (_isTrackingVehicle) {
          _animateCameraToVehicle();
        }
      }
    } catch (e) {
      debugPrint('[CustodiaRondinMapCard] Error obteniendo posición del vehículo: $e');
    }
  }

  /// Genera marcador estilo Apple Maps con pin numerado o con icono check
  static Future<BitmapDescriptor> _drawNumberedMarker({
    required String text,
    required Color color,
  }) async {
    const double width = 76.0;
    const double height = 96.0;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final double cx = width / 2;
    const double cy = 34.0;
    const double r = 30.0;
    const double tipY = 90.0;
    const double dy = tipY - cy;
    final double angle = math.asin((r / dy).clamp(-1.0, 1.0));

    final Path pinPath = Path();
    pinPath.addArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      math.pi / 2 + angle,
      2 * math.pi - 2 * angle,
    );
    pinPath.lineTo(cx, tipY);
    pinPath.close();

    // Sombra exterior suave del pin
    canvas.drawShadow(pinPath, Colors.black.withOpacity(0.35), 5.0, true);

    // Fondo del pin con el color correspondiente (Verde cumplido / Azul ruta / Ámbar)
    final Paint pinPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, pinPaint);

    // Borde blanco exterior de alta definición
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawPath(pinPath, borderPaint);

    // Círculo interior blanco
    final Paint innerCirclePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 18.0, innerCirclePaint);

    // Texto interior (Número o ✓)
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: text == '✓' ? 20.0 : (text.length > 2 ? 13.0 : 16.5),
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
    );

    final ui.Image image =
        await pictureRecorder.endRecording().toImage(width.toInt(), height.toInt());
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
    return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
  }

  Future<void> _preloadMarkers() async {
    if (_isPreloadingMarkers) return;
    _isPreloadingMarkers = true;
    try {
      final futures = <Future<void>>[];
      for (int i = 0; i < widget.rondin.puntos.length; i++) {
        final p = widget.rondin.puntos[i];
        if (p.lat == 0.0 && p.lng == 0.0) continue;
        final bool isDone = p.completado ||
            (widget.rondin.cumplidos > 0 && i < widget.rondin.cumplidos);
        final bool isActive = !isDone &&
            (i == 0 ||
                widget.rondin.puntos[i - 1].completado ||
                (widget.rondin.cumplidos > 0 && (i - 1) < widget.rondin.cumplidos));

        final Color pinColor = isDone
            ? const Color(0xFF16A34A)
            : (isActive
                ? (p.llego ? const Color(0xFFD97706) : const Color(0xFF0284C7))
                : const Color(0xFF64748B));

        final String markerText = isDone ? '✓' : '${i + 1}';
        final String cacheKey = '${markerText}_${pinColor.value}';

        if (!_numberedMarkerCache.containsKey(cacheKey)) {
          futures.add(() async {
            final icon = await _drawNumberedMarker(text: markerText, color: pinColor);
            _numberedMarkerCache[cacheKey] = icon;
          }());
        }
      }

      if (futures.isNotEmpty) {
        await Future.wait(futures);
        if (mounted) {
          _buildRondinMap();
        }
      }
    } catch (e) {
      debugPrint('[CustodiaRondinMapCard] Error generando marcadores: $e');
    } finally {
      _isPreloadingMarkers = false;
    }
  }

  void _buildRondinMap() {
    final markers = <Marker>{};
    final circles = <Circle>{};
    final polygons = <Polygon>{};
    final coords = <LatLng>[];

    // Identificar último punto completado para la división de la ruta
    int lastCompletedIndex = -1;
    for (int i = 0; i < widget.rondin.puntos.length; i++) {
      final p = widget.rondin.puntos[i];
      final isDone = p.completado ||
          (widget.rondin.cumplidos > 0 && i < widget.rondin.cumplidos);
      if (isDone) {
        lastCompletedIndex = i;
      }
    }

    for (int i = 0; i < widget.rondin.puntos.length; i++) {
      final p = widget.rondin.puntos[i];
      if (p.lat == 0.0 && p.lng == 0.0) continue;
      final pos = LatLng(p.lat, p.lng);
      coords.add(pos);

      final bool isDone = p.completado ||
          (widget.rondin.cumplidos > 0 && i < widget.rondin.cumplidos);
      final bool isActive = !isDone &&
          (i == 0 ||
              widget.rondin.puntos[i - 1].completado ||
              (widget.rondin.cumplidos > 0 && (i - 1) < widget.rondin.cumplidos));

      final Color pinColor = isDone
          ? const Color(0xFF16A34A)
          : (isActive
              ? (p.llego ? const Color(0xFFD97706) : const Color(0xFF0284C7))
              : const Color(0xFF64748B));

      final String markerText = isDone ? '✓' : '${i + 1}';
      final String cacheKey = '${markerText}_${pinColor.value}';
      final customIcon = _numberedMarkerCache[cacheKey];

      markers.add(
        Marker(
          markerId: MarkerId('rondin_pt_${p.id}'),
          position: pos,
          icon: customIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                isDone
                    ? BitmapDescriptor.hueGreen
                    : (isActive
                        ? (p.llego
                            ? BitmapDescriptor.hueOrange
                            : BitmapDescriptor.hueAzure)
                        : BitmapDescriptor.hueCyan),
              ),
          anchor: const Offset(0.5, 0.94),
          zIndex: isDone ? 10 : (isActive ? 15 : 5),
          infoWindow: InfoWindow(
            title: '${i + 1}. ${p.nombre}${isDone ? ' ✓' : ''}',
            snippet: isDone
                ? 'Punto Cumplido ✓'
                : (p.llego ? 'Presente en punto' : 'Hora programada: ${p.hora}'),
          ),
        ),
      );

      // Geocerca del punto: Polígono si viene polyline5 o Círculo por radioM
      if (p.poligono != null && p.poligono!.isNotEmpty) {
        final polyPoints = Polyline5Decoder.decode(p.poligono!);
        if (polyPoints.isNotEmpty) {
          polygons.add(
            Polygon(
              polygonId: PolygonId('rondin_poly_${p.id}'),
              points: polyPoints
                  .map((pt) => LatLng(pt.latitude, pt.longitude))
                  .toList(),
              fillColor: (isDone
                      ? const Color(0xFF16A34A)
                      : (isActive ? const Color(0xFF0284C7) : const Color(0xFF64748B)))
                  .withOpacity(0.14),
              strokeColor: isDone
                  ? const Color(0xFF16A34A)
                  : (isActive ? const Color(0xFF0284C7) : const Color(0xFF94A3B8)),
              strokeWidth: 2,
            ),
          );
        }
      } else {
        circles.add(
          Circle(
            circleId: CircleId('rondin_circ_${p.id}'),
            center: pos,
            radius: p.radioM.toDouble(),
            fillColor: (isDone
                    ? const Color(0xFF16A34A)
                    : (isActive ? const Color(0xFF0284C7) : const Color(0xFF64748B)))
                .withOpacity(0.14),
            strokeColor: isDone
                ? const Color(0xFF16A34A)
                : (isActive ? const Color(0xFF0284C7) : const Color(0xFF94A3B8)),
            strokeWidth: 2,
          ),
        );
      }
    }

    // Marcador del Vehículo de Rondín (Top-down 360°, Gris/Off) - Fuera del loop de puntos
    if (_vehicleLocation != null) {
      markers.add(
        Marker(
          markerId: MarkerId('rondin_vehiculo_${widget.rondin.idRondinDia}'),
          position: _vehicleLocation!,
          icon: _truckOffIcon ??
              _cachedTruckOffIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: _vehicleDirection,
          zIndex: 30,
          infoWindow: InfoWindow(
            title: widget.rondin.unidad.isNotEmpty
                ? widget.rondin.unidad
                : 'Vehículo del rondín',
            snippet: 'Patrullaje en curso',
          ),
        ),
      );
    }

    final polylines = <Polyline>{};
    if (coords.length > 1) {
      // 1. TRAMO COMPLETADO: Trazado sólido en VERDE INTENSO (Dual Casing estilo Rutas)
      if (lastCompletedIndex > 0) {
        final completedCoords =
            coords.sublist(0, math.min(lastCompletedIndex + 1, coords.length));
        if (completedCoords.length >= 2) {
          // Borde exterior verde bosque
          polylines.add(
            Polyline(
              polylineId: const PolylineId('rondin_completed_casing'),
              points: completedCoords,
              color: const Color(0xFF14532D),
              width: 6,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
              zIndex: 10,
            ),
          );
          // Núcleo verde esmeralda brillante de punto cumplido
          polylines.add(
            Polyline(
              polylineId: const PolylineId('rondin_completed_core'),
              points: completedCoords,
              color: const Color(0xFF16A34A),
              width: 4,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
              zIndex: 11,
            ),
          );
        }
      }

      // 2. TRAMO PENDIENTE / RESTANTE: Trazado FULL AZUL sin líneas blancas (Dual Casing sólido estilo Rutas)
      final int remainingStart =
          (lastCompletedIndex >= 0) ? lastCompletedIndex : 0;
      if (remainingStart < coords.length - 1) {
        final remainingCoords = coords.sublist(remainingStart);
        if (remainingCoords.length >= 2) {
          // Delineado exterior azul marino profundo de alto contraste
          polylines.add(
            Polyline(
              polylineId: const PolylineId('rondin_remaining_casing'),
              points: remainingCoords,
              color: const Color(0xFF082F49),
              width: 6,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
              zIndex: 5,
            ),
          );
          // Núcleo azul vibrante puro original de ruta (100% full azul, sin líneas blancas punteadas)
          polylines.add(
            Polyline(
              polylineId: const PolylineId('rondin_remaining_core'),
              points: remainingCoords,
              color: const Color(0xFF0284C7),
              width: 4,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
              zIndex: 6,
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _markers = markers;
        _circles = circles;
        _polygons = polygons;
        _polylines = polylines;
        _pointCoords = coords;
      });
    } else {
      _markers = markers;
      _circles = circles;
      _polygons = polygons;
      _polylines = polylines;
      _pointCoords = coords;
    }
  }

  void _toggleVehicleTracking() {
    final nextState = !_isTrackingVehicle;
    setState(() {
      _isTrackingVehicle = nextState;
    });

    if (nextState) {
      if (_vehicleLocation != null) {
        _animateCameraToVehicle();
      } else {
        _fetchVehiclePosition();
      }
    }
  }

  Future<void> _animateCameraToVehicle({double defaultZoom = 16.5}) async {
    final ctrl = _mapController;
    final loc = _vehicleLocation;
    if (ctrl == null || loc == null) return;
    try {
      final currentZoom = await ctrl.getZoomLevel();
      final effectiveZoom = (currentZoom < 14.0) ? defaultZoom : currentZoom;
      ctrl.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: loc, zoom: effectiveZoom),
        ),
      );
    } catch (_) {
      ctrl.animateCamera(
        CameraUpdate.newLatLngZoom(loc, defaultZoom),
      );
    }
  }

  void _fitRondinBounds() {
    if (_isTrackingVehicle && mounted) {
      setState(() {
        _isTrackingVehicle = false;
      });
    }
    final ctrl = _mapController;
    if (ctrl == null) return;
    final allPoints = <LatLng>[..._pointCoords];
    if (_vehicleLocation != null) {
      allPoints.add(_vehicleLocation!);
    }
    if (allPoints.isEmpty) return;

    if (allPoints.length == 1) {
      ctrl.animateCamera(
        CameraUpdate.newLatLngZoom(allPoints.first, 15.0),
      );
      return;
    }

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (final p in allPoints) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    if (minLat == maxLat && minLng == maxLng) {
      ctrl.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 15.0),
      );
      return;
    }

    ctrl.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        36.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFloatingHeader) {
      return _buildFloatingMap(context);
    }

    if (_pointCoords.isEmpty) return const SizedBox.shrink();

    final initialPos = CameraPosition(
      target: _pointCoords.first,
      zoom: 14.5,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.explore_rounded,
                          size: 16, color: Color(0xFF0284C7)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Puntos del Rondín en Mapa',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.rondin.cumplidos}/${widget.rondin.total} cumplidos',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 200,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: initialPos,
                    markers: _markers,
                    polylines: _polylines,
                    circles: _circles,
                    polygons: _polygons,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                    buildingsEnabled: false,
                    indoorViewEnabled: false,
                    tiltGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    onMapCreated: (ctrl) {
                      _mapController = ctrl;
                      Future.delayed(const Duration(milliseconds: 350), () {
                        if (mounted) _fitRondinBounds();
                      });
                    },
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: _fitRondinBounds,
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(Icons.center_focus_strong_rounded,
                              size: 18, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  /// Mapa interactivo de cabecera a toda anchura con barra flotante (Estilo Rutas)
  Widget _buildFloatingMap(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 360;
    final rondin = widget.rondin;

    final initialPos = _pointCoords.isNotEmpty
        ? CameraPosition(target: _pointCoords.first, zoom: 14.5)
        : const CameraPosition(target: LatLng(19.4326, -99.1332), zoom: 12.0);

    final double mapHeight = widget.height ??
        (_mapExpanded
        ? mediaQuery.size.height * 0.72
        : (mediaQuery.size.height * 0.38).clamp(260.0, 340.0));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      height: mapHeight,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: initialPos,
              markers: _markers,
              polylines: _polylines,
              circles: _circles,
              polygons: _polygons,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              buildingsEnabled: false,
              indoorViewEnabled: false,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              padding: EdgeInsets.only(
                top: mediaQuery.padding.top + 60,
                right: 56,
                bottom: 14,
                left: 14,
              ),
              onMapCreated: (ctrl) {
                _mapController = ctrl;
                Future.delayed(const Duration(milliseconds: 350), () {
                  if (mounted) _fitRondinBounds();
                });
              },
            ),
          ),

          // Barra Superior Flotante estilo Apple / Rutas
          if (widget.showTopBar)
          Positioned(
            top: mediaQuery.padding.top + 8,
            left: isSmallScreen ? 10 : 14,
            right: isSmallScreen ? 10 : 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFloatingTopBar(context, isSmallScreen),
                if (_showInfoChip && rondin.unidad.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _buildFloatingInfoChip(context, isSmallScreen),
                ],
              ],
            ),
          ),

          // Controles Laterales Flotantes
          Positioned(
            right: isSmallScreen ? 8 : 12,
            top: mediaQuery.padding.top + 68,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Botón Carro para fijar el carro en el mapa
                _buildFloatingMapButton(
                  icon: _isTrackingVehicle
                      ? Icons.directions_car_rounded
                      : Icons.directions_car_outlined,
                  tooltip: _isTrackingVehicle
                      ? 'Fijando carro (Activo)'
                      : 'Fijar carro en el mapa',
                  isActive: _isTrackingVehicle,
                  activeColor: const Color(0xFF0284C7),
                  onTap: _toggleVehicleTracking,
                ),
                const SizedBox(height: 8),
                // 2. Botón para hacer todo grande como estaba (Encuadrar rondín completo)
                _buildFloatingMapButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Hacer todo grande (Encuadrar rondín)',
                  onTap: _fitRondinBounds,
                ),
                const SizedBox(height: 8),
                // 3. Botón para abrir todo el mapa (Expandir pantalla completa)
                _buildFloatingMapButton(
                  icon: _mapExpanded
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  tooltip: _mapExpanded ? 'Reducir mapa' : 'Abrir todo el mapa',
                  isActive: _mapExpanded,
                  onTap: () {
                    setState(() {
                      _mapExpanded = !_mapExpanded;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Barra de título flotante estilo Apple con fondo translúcido y bordes redondeados
  Widget _buildFloatingTopBar(BuildContext context, bool isSmallScreen) {
    final rondin = widget.rondin;
    final isCompleted = rondin.cumplidos >= rondin.total && rondin.total > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Botón Atrás
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: widget.onBack ?? () => Navigator.maybePop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(11),
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

          // Título y Subtítulo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rondin.nombre.isNotEmpty
                      ? rondin.nombre
                      : 'Rondín de Custodia',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF0284C7),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${rondin.turno.isNotEmpty ? "Turno: ${rondin.turno} · " : ""}${rondin.cumplidos}/${rondin.total} cumplidos',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Botón de Contraseña / Claves de Seguridad de Custodia (CustodiaClavesPage)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: widget.onOpenClaves ??
                  () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CustodiaClavesPage(),
                        ),
                      ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: widget.tieneClaves
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        widget.tieneClaves
                            ? Icons.shield_outlined
                            : Icons.shield_rounded,
                        size: 19,
                        color: widget.tieneClaves
                            ? const Color(0xFF0284C7)
                            : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                  if (!widget.tieneClaves)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
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

  /// Chip flotante de unidad asignada y número de puntos
  Widget _buildFloatingInfoChip(BuildContext context, bool isSmallScreen) {
    final mediaQuery = MediaQuery.of(context);
    final rondin = widget.rondin;
    final maxChipWidth = (mediaQuery.size.width - (isSmallScreen ? 88 : 100))
        .clamp(160.0, 320.0);

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxChipWidth),
        padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.directions_car_rounded,
              size: 13,
              color: Color(0xFF0284C7),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                'Unidad: ${rondin.unidad}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '· ${rondin.total} puntos',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() {
                  _showInfoChip = false;
                });
              },
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Botón individual para controles flotantes laterales sobre el mapa
  Widget _buildFloatingMapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeColor,
  }) {
    final effectiveColor = activeColor ?? const Color(0xFF0284C7);
    return Material(
      color: isActive
          ? effectiveColor.withOpacity(0.12)
          : Colors.white.withOpacity(0.96),
      borderRadius: BorderRadius.circular(11),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: isActive ? effectiveColor : const Color(0xFFE2E8F0),
                width: isActive ? 1.5 : 1.0,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isActive ? effectiveColor : const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }
}
/// Barra de título y estado flotante de Rondín para modo desacoplado / Sheet (Estilo Apple / Rutas)
class CustodiaRondinFloatingTopBar extends StatefulWidget {
  final RondinDia rondin;
  final VoidCallback? onBack;
  final VoidCallback? onOpenClaves;
  final bool tieneClaves;
  final bool isSmallScreen;

  const CustodiaRondinFloatingTopBar({
    super.key,
    required this.rondin,
    this.onBack,
    this.onOpenClaves,
    this.tieneClaves = true,
    this.isSmallScreen = false,
  });

  @override
  State<CustodiaRondinFloatingTopBar> createState() =>
      _CustodiaRondinFloatingTopBarState();
}

class _CustodiaRondinFloatingTopBarState
    extends State<CustodiaRondinFloatingTopBar> {
  bool _showInfoChip = true;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final rondin = widget.rondin;
    final isCompleted = rondin.cumplidos >= rondin.total && rondin.total > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Botón Atrás
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: widget.onBack ?? () => Navigator.maybePop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(11),
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

              // Título y Subtítulo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rondin.nombre.isNotEmpty
                          ? rondin.nombre
                          : 'Rondín de Custodia',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF0284C7),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${rondin.turno.isNotEmpty ? "Turno: ${rondin.turno} · " : ""}${rondin.cumplidos}/${rondin.total} cumplidos',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Botón de Contraseña / Claves de Seguridad
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: widget.onOpenClaves ??
                      () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CustodiaClavesPage(),
                            ),
                          ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: widget.tieneClaves
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            widget.tieneClaves
                                ? Icons.shield_outlined
                                : Icons.shield_rounded,
                            size: 19,
                            color: widget.tieneClaves
                                ? const Color(0xFF0284C7)
                                : const Color(0xFFD97706),
                          ),
                        ),
                      ),
                      if (!widget.tieneClaves)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Chip flotante de Unidad: Blanco translúcido con botón X para descartar
        if (_showInfoChip && rondin.unidad.isNotEmpty) ...[
          const SizedBox(height: 6),
          Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: (mediaQuery.size.width - (widget.isSmallScreen ? 88 : 100))
                    .clamp(160.0, 320.0),
              ),
              padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.96),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.directions_car_rounded,
                    size: 14,
                    color: Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Unidad: ${rondin.unidad}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '· ${rondin.puntos.length} puntos en ruta',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        _showInfoChip = false;
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
