import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mark_v3/models/Custodia_/custodia_models.dart';
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
                    myLocationEnabled: true,
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

  const CustodiaRondinMapCard({
    super.key,
    required this.rondin,
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

  @override
  void initState() {
    super.initState();
    _buildRondinMap();
  }

  @override
  void didUpdateWidget(covariant CustodiaRondinMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _buildRondinMap();
  }

  void _buildRondinMap() {
    final markers = <Marker>{};
    final circles = <Circle>{};
    final polygons = <Polygon>{};
    final coords = <LatLng>[];

    for (int i = 0; i < widget.rondin.puntos.length; i++) {
      final p = widget.rondin.puntos[i];
      if (p.lat == 0.0 && p.lng == 0.0) continue;
      final pos = LatLng(p.lat, p.lng);
      coords.add(pos);

      // Color de marcador según avance del punto
      final double hue = p.completado
          ? BitmapDescriptor.hueGreen
          : (p.llego ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueAzure);

      markers.add(
        Marker(
          markerId: MarkerId('rondin_pt_${p.id}'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: '${i + 1}. ${p.nombre}',
            snippet: p.completado
                ? 'Completado ✓'
                : (p.llego ? 'Presente en punto' : 'Hora plan: ${p.hora}'),
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
              fillColor: (p.completado
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF0284C7))
                  .withOpacity(0.12),
              strokeColor: p.completado
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF0284C7),
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
            fillColor: (p.completado
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF0284C7))
                .withOpacity(0.12),
            strokeColor: p.completado
                ? const Color(0xFF16A34A)
                : const Color(0xFF0284C7),
            strokeWidth: 1,
          ),
        );
      }
    }

    final polylines = <Polyline>{};
    if (coords.length > 1) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('rondin_sequence'),
          points: coords,
          color: const Color(0xFF0284C7).withOpacity(0.7),
          width: 3,
          patterns: [PatternItem.dash(12), PatternItem.gap(6)],
        ),
      );
    }

    setState(() {
      _markers = markers;
      _circles = circles;
      _polygons = polygons;
      _polylines = polylines;
      _pointCoords = coords;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _fitRondinBounds());
  }

  void _fitRondinBounds() {
    if (_mapController == null || _pointCoords.isEmpty) return;

    double minLat = _pointCoords.first.latitude;
    double maxLat = _pointCoords.first.latitude;
    double minLng = _pointCoords.first.longitude;
    double maxLng = _pointCoords.first.longitude;

    for (final p in _pointCoords) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    if (minLat == maxLat && minLng == maxLng) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 16.0),
      );
      return;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        42.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    myLocationEnabled: true,
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
                      _fitRondinBounds();
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
}
