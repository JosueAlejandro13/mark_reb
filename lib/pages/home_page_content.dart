import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';
import 'package:mark_v3/pages/CentroAtencion_/centro_atencion_card.dart';
import 'package:mark_v3/pages/MyVehicle_/MyVehiclePage.dart';
import 'package:mark_v3/pages/Routes_/routes_page.dart';
import 'package:mark_v3/pages/ServiceStation_/ServiceStationPage.dart';
import 'package:mark_v3/pages/Trackingpage.dart';
import 'package:mark_v3/pages/inspeccion/SeleccionPlantillasPage.dart';
import 'package:mark_v3/pages/notifications_page.dart';
import 'package:mark_v3/pages/tasks_page.dart';
import 'package:mark_v3/providers/Home_/home_provider.dart';
import 'package:mark_v3/providers/Profile_/profile_provider.dart';
import 'package:mark_v3/providers/Routes_/routes_provider.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/vehicle_report_sheets.dart';

class HomePageContent extends ConsumerStatefulWidget {
  final String usuario;
  final String userId;
  final String idCollaborator;
  final String idMainAccount;

  const HomePageContent({
    super.key,
    required this.usuario,
    required this.userId,
    required this.idCollaborator,
    required this.idMainAccount,
  });

  @override
  ConsumerState<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends ConsumerState<HomePageContent> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(skipTraversal: true);

  int _tareasPendientesCount = 0;
  List<Map<String, dynamic>> _documentosVencidos = [];
  List<Map<String, dynamic>> _tareasPendientes = [];
  bool _inspeccionPendiente = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.skipTraversal = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.unfocus();
        _cargarDatosPorAtender();
      }
    });
  }

  Future<void> _cargarDatosPorAtender() async {
    if (!mounted) return;

    // Tareas pendientes con detalle
    try {
      final tareas = await MarkApiClient.instance.getTareas(
        estado: 'abierta',
        mias: '1',
      );
      if (mounted) {
        setState(() {
          _tareasPendientes = tareas;
          _tareasPendientesCount = tareas.length;
        });
      }
    } catch (_) {}

    // Documentos vencidos
    try {
      final alertas = await MarkApiClient.instance.getAlertas();
      final vencidos = alertas.where((a) {
        final titulo = (a['titulo'] ?? a['nombre'] ?? a['descripcion'] ?? '')
            .toString()
            .toLowerCase();
        final cat =
            (a['categoria'] ?? a['tipo'] ?? '').toString().toLowerCase();
        final isDoc = cat.contains('doc') ||
            cat.contains('seguro') ||
            titulo.contains('seguro') ||
            titulo.contains('tarjeta') ||
            titulo.contains('poliza') ||
            titulo.contains('póliza') ||
            titulo.contains('licencia');
        final isVencido = titulo.contains('vencid') ||
            (a['estatus'] ?? '').toString().toLowerCase().contains('vencid') ||
            (a['prioridad'] ?? '').toString().toLowerCase() == 'grave';
        return isDoc && isVencido;
      }).toList();

      if (mounted) {
        setState(() {
          _documentosVencidos = vencidos;
        });
      }
    } catch (_) {}

    // Inspección pendiente: verificar si hay plantilla sin completar hoy
    try {
      final routesState = ref.read(routesProvider);
      final rutas = routesState.dayPackage?.rutas ?? const [];
      final activeRoute = rutas.where((r) => r.isActiva).firstOrNull ??
          rutas.where((r) => !r.isFinalizada).firstOrNull ??
          rutas.firstOrNull;

      int? idVehic = activeRoute?.vehiculo?.id;
      if (idVehic == null) {
        final vehiculos =
            await MarkApiClient.instance.getVehiculos(silent: true);
        if (vehiculos.isNotEmpty) {
          idVehic = int.tryParse(
              vehiculos.first['idVehic']?.toString() ?? '');
        }
      }

      if (idVehic != null) {
        final data = await MarkApiClient.instance.getInspecciones(idVehic);
        // Si no hay inspecciones hoy o la lista está vacía → pendiente
        final inspList = data['inspecciones'] ?? data['data'] ?? [];
        final today = DateTime.now();
        bool tieneHoy = false;
        if (inspList is List && inspList.isNotEmpty) {
          tieneHoy = inspList.any((i) {
            final fechaStr = (i['fecha'] ?? i['createdAt'] ?? '').toString();
            if (fechaStr.isEmpty) return false;
            try {
              final fecha = DateTime.parse(fechaStr);
              return fecha.year == today.year &&
                  fecha.month == today.month &&
                  fecha.day == today.day;
            } catch (_) {
              return false;
            }
          });
        }
        if (mounted) {
          setState(() {
            _inspeccionPendiente = !tieneHoy;
            _cargando = false;
          });
        }
      } else {
        if (mounted) setState(() => _cargando = false);
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final homeNotifier = ref.read(homeProvider.notifier);
    final routesState = ref.watch(routesProvider);
    final query = homeState.searchQuery.toLowerCase();

    // Detección de rol y estado de ruta activa
    final apiSession = MarkApiClient.instance.currentSession;
    final session = routesState.session ?? apiSession;
    final rol = (session?.rol ?? '').trim().toLowerCase();
    final isUsuarioOnly = rol == 'usuario';
    final isPreventa =
        session?.isPreventa == true || rol == 'preventa' || rol == 'vendedor';
    final isChofer =
        rol == 'chofer' || (!isPreventa && !isUsuarioOnly && rol.isNotEmpty);

    final rutas = routesState.dayPackage?.rutas ?? const [];
    // Prioridad: ruta activa, luego primera ruta no finalizada, o primera ruta detectada
    final DriverRoute? routeToDisplay = rutas.where((r) => r.isActiva).firstOrNull ??
        rutas.where((r) => !r.isFinalizada).firstOrNull ??
        rutas.firstOrNull;

    // Filtros reactivos con Riverpod
    final showRoutes = query.isEmpty ||
        'rutas'.contains(query) ||
        'itinerario'.contains(query) ||
        'logistica'.contains(query) ||
        'paradas'.contains(query) ||
        'preventa'.contains(query) ||
        'pedidos'.contains(query) ||
        'clientes'.contains(query);

    // Regla de visualización del Banner Hero:
    // 1. Preventa: muestra banner de Preventa.
    // 2. Chofer o con ruta asignada: se muestra SIEMPRE que se detecte una ruta (routeToDisplay != null),
    //    esté activa o no.
    final bool showHeroBanner = isPreventa
        ? showRoutes
        : (routeToDisplay != null && showRoutes);

    final showTracking =
        (query.isEmpty ||
        'rastreo'.contains(query) ||
        'gps'.contains(query) ||
        'monitoreo'.contains(query) ||
        'unidades'.contains(query) ||
        'mapa'.contains(query));

    final showRefill = !isPreventa &&
        (query.isEmpty ||
        'reabastecimiento'.contains(query) ||
        'combustible'.contains(query) ||
        'gasolina'.contains(query) ||
        'estacion'.contains(query) ||
        'carga'.contains(query) ||
        'odometro'.contains(query));

    final showSafetyProtocol = query.isEmpty ||
        'seguridad'.contains(query) ||
        'protocolo'.contains(query) ||
        'buenas'.contains(query) ||
        'practicas'.contains(query) ||
        'vial'.contains(query) ||
        'inspeccion'.contains(query) ||
        'prevencion'.contains(query);

    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: ColoredBox(
          // Fondo estilo iOS System Grouped Background
          color: const Color(0xFFF2F4F7),
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: const Color(0xFF0284C7),
              onRefresh: () async {
                await Future.wait([
                  homeNotifier.refreshHome(widget.userId),
                  ref
                      .read(routesProvider.notifier)
                      .syncPendingQueueAndRefreshDay(forceRefreshDay: true),
                  _cargarDatosPorAtender(),
                ]);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Avatar + Bienvenida + Notificaciones (Estilo Apple)
                    _buildHeader(context, homeState),
                    const SizedBox(height: 12),

                    // Buscador estilo iOS Search Bar
                    _buildSearchBar(context, homeNotifier, query),
                    const SizedBox(height: 16),

                    // WIDGET PRINCIPAL: Banner Hero reactivo (Estilo Apple Card)
                    if (showHeroBanner) ...[
                      if (isPreventa)
                        _buildPreventaHeroBanner(context)
                      else if (routeToDisplay != null)
                        _buildActiveRouteHeroBanner(context, routeToDisplay),
                      const SizedBox(height: 16),
                    ],

                    // SECCIÓN: PENDIENTES
                    _buildSectionHeader(
                      title: 'PENDIENTES',
                      subtitle: 'Elementos que requieren tu atención hoy',
                    ),
                    const SizedBox(height: 10),
                    CentroAtencionCard(
                      userId: widget.userId,
                      idCollaborator: widget.idCollaborator,
                      idMainAccount: widget.idMainAccount,
                    ),
                    const SizedBox(height: 20),

                    // SECCIÓN: OPERACIONES Y UNIDAD (4 Módulos Cuadrados)
                    _buildSectionHeader(
                      title: 'OPERACIONES Y UNIDAD',
                      subtitle:
                          'Supervisión en campo, flota y reportes rápidos',
                    ),
                    const SizedBox(height: 10),

                    // GRID DE TARJETAS CUADRADAS (2x2)
                    Row(
                      children: [
                        Expanded(
                          child: _buildTrackingSquareCard(context, homeState),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFuelSquareCard(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildReportProblemSquareCard(context),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildReportIncidentSquareCard(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Espacio idéntico para la barra de navegación flotante
                    const SizedBox(height: 95),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- HEADER: Perfil + Saludo + Notificaciones (Estilo Apple) ---
  Widget _buildHeader(BuildContext context, HomeState state) {
    final profileState = ref.watch(profileProvider);
    final apiSession = MarkApiClient.instance.currentSession;
    final session = ref.watch(routesProvider).session;

    String realName = '';
    if (apiSession != null && apiSession.usuario.nombre.isNotEmpty) {
      realName = apiSession.usuario.nombre.trim();
    }
    if (realName.isEmpty) {
      realName = session?.chofer.nombre ?? '';
    }
    String parsedName = '';
    if (realName.isNotEmpty) {
      final parts = realName.trim().split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        String first =
            parts[0][0].toUpperCase() + parts[0].substring(1).toLowerCase();
        String last = '';
        if (parts.length == 2) {
          last = parts[1];
        } else if (parts.length == 3) {
          last = parts[1];
        } else if (parts.length >= 4) {
          last = parts[2];
        }

        if (last.isNotEmpty) {
          last = last[0].toUpperCase() + last.substring(1).toLowerCase();
          parsedName = '$first $last';
        } else {
          parsedName = first;
        }
      }
    }

    String displayName =
        parsedName.isNotEmpty ? parsedName : widget.usuario.trim();
    if (parsedName.isEmpty) {
      if (displayName.contains('@')) {
        displayName = displayName.split('@').first;
      }
      if (displayName.isNotEmpty) {
        displayName = displayName[0].toUpperCase() + displayName.substring(1);
      } else {
        displayName = 'Colaborador';
      }
    }

    String getInitials(String name) {
      if (name.isEmpty) return 'US';
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length > 1) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }

    return Row(
      children: [
        // Avatar con borde fino Apple y micro-sombra
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: Colors.white,
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A1E34).withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: profileState.imageFile != null
                ? Image.file(
                    profileState.imageFile!,
                    fit: BoxFit.cover,
                  )
                : (profileState.networkPhotoUrl != null &&
                        profileState.networkPhotoUrl!.isNotEmpty)
                    ? Image.network(
                        profileState.networkPhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFDDF0FF),
                          child: Center(
                            child: Text(
                              getInitials(displayName),
                              style: const TextStyle(
                                color: Color(0xFF0284C7),
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: const Color(0xFFDDF0FF),
                        child: Center(
                          child: Text(
                            getInitials(displayName),
                            style: const TextStyle(
                              color: Color(0xFF0284C7),
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
          ),
        ),
        const SizedBox(width: 12),

        // Saludo y Nombre al estilo Apple Large Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const Text(
                      'BIENVENIDO DE NUEVO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('👋', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),

        // Botón de Notificaciones al estilo Apple Squircle
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationsPage(
                    userId: widget.userId,
                    showBackButton: true,
                  ),
                ),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 0.9,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A1E34).withOpacity(0.035),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFF0F172A),
                    size: 21,
                  ),
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      width: 7.5,
                      height: 7.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- BUSCADOR REACTIVO CON RIVERPOD (Estilo iOS Search Bar) ---
  Widget _buildSearchBar(
    BuildContext context,
    HomeNotifier notifier,
    String activeQuery,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8F0).withOpacity(0.9),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1E34).withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: Color(0xFF94A3B8),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: false,
                cursorColor: const Color(0xFF0284C7),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w500,
                ),
                onChanged: (val) => notifier.updateSearch(val),
                decoration: const InputDecoration(
                  hintText: 'Buscar rutas, unidades o registros...',
                  hintStyle: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),
          if (activeQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                notifier.clearSearch();
              },
              child: Container(
                padding: const EdgeInsets.all(3.5),
                decoration: const BoxDecoration(
                  color: Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 12, color: Color(0xFF475569)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.tune_rounded,
                  color: Color(0xFF64748B), size: 15),
            ),
        ],
      ),
    );
  }

  // --- WIDGET PRINCIPAL: RUTA (Estilo Apple Live Activity Card) ---
  Widget _buildActiveRouteHeroBanner(
      BuildContext context, DriverRoute activeRoute) {
    final totalStops = activeRoute.totalClientStops;
    final doneStops = activeRoute.visitedClientStops;
    final progress =
        totalStops > 0 ? (doneStops / totalStops).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).toInt();
    final isActiva = activeRoute.isActiva;
    final isFinalizada = activeRoute.isFinalizada;

    // Colores y textos según el estado de la ruta
    final Color chipBg = isActiva
        ? const Color(0xFFECFDF5)
        : (isFinalizada ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF));
    final Color chipBorder = isActiva
        ? const Color(0xFFA7F3D0)
        : (isFinalizada ? const Color(0xFFE2E8F0) : const Color(0xFFBFDBFE));
    final Color dotColor = isActiva
        ? const Color(0xFF10B981)
        : (isFinalizada ? const Color(0xFF64748B) : const Color(0xFF0284C7));
    final Color textColor = isActiva
        ? const Color(0xFF047857)
        : (isFinalizada ? const Color(0xFF475569) : const Color(0xFF0369A1));
    final String statusText = isActiva
        ? 'Ruta en Curso · Activa'
        : (isFinalizada ? 'Ruta Finalizada' : 'Ruta Asignada · Programada');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Stack(
        children: [
          // Resplandor sutil ambiental detrás de la ilustración del vehículo
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 125,
              height: 105,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE0F2FE).withOpacity(0.5),
              ),
            ),
          ),

          // Imagen / Ilustración
          Positioned(
            right: -6,
            bottom: -4,
            child: Opacity(
              opacity: 0.95,
              child: Image.asset(
                'assets/cargps.png',
                height: 105,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/car.png',
                  height: 95,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),
          ),

          // Contenido del Banner
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tag superior: Estado de la ruta (Apple Live Activity Chip)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.5, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: chipBorder, width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6.5,
                        height: 6.5,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          boxShadow: isActiva
                              ? [
                                  BoxShadow(
                                    color: dotColor.withOpacity(0.55),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Título: Nombre de la ruta activa
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.54,
                  child: Text(
                    activeRoute.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Subtítulo con paradas y modalidad
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.52,
                  child: Text(
                    '${activeRoute.modalidadNombre} · $doneStops de $totalStops paradas',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Mini barra de progreso estilo Apple
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.48,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Progreso',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            '$percent%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3.5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5.0,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Botón Call To Action: "Continuar ruta ➔"
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RouteDetailAndMapPage(
                            idRuta: activeRoute.idRuta,
                          ),
                        ),
                      );
                      if (context.mounted) {
                        ref
                            .read(routesProvider.notifier)
                            .syncPendingQueueAndRefreshDay();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF0284C7),
                            Color(0xFF0369A1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withOpacity(0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            activeRoute.isActiva ? 'Continuar ruta' : 'Ver ruta',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ],
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
  }

  // --- WIDGET PRINCIPAL: PREVENTA (Estilo Apple Cerulean Card) ---
  Widget _buildPreventaHeroBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF0F9FF),
            Color(0xFFE0F2FE),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFBAE6FD).withOpacity(0.85),
          width: 1.0,
        ),
      ),
      child: Stack(
        children: [
          // Imagen / Ilustración
          Positioned(
            right: -6,
            bottom: -4,
            child: Opacity(
              opacity: 0.95,
              child: Image.asset(
                'assets/cargps.png',
                height: 105,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/car.png',
                  height: 95,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),
          ),

          // Contenido del Banner
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tag superior Apple Pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.6)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0284C7),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Preventa & Pedidos',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0369A1),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Título
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.54,
                  child: const Text(
                    'Toma de Pedidos',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.4,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(height: 5),

                // Subtítulo
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.52,
                  child: Text(
                    'Registra nuevos clientes, consulta el catálogo y genera pedidos en campo.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey[700],
                      height: 1.25,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Botón Call To Action: "Ir a Preventa ➔"
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RoutesPage(
                            idCollaborator: widget.idCollaborator,
                            idMainAccount: widget.idMainAccount,
                          ),
                        ),
                      );
                      if (context.mounted) {
                        ref
                            .read(routesProvider.notifier)
                            .syncPendingQueueAndRefreshDay();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF0284C7),
                            Color(0xFF0369A1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ir a Preventa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                          ),
                          SizedBox(width: 5),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ],
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
  }

  // --- SECCIÓN: POR ATENDER (DOCUMENTOS VENCIDOS, TAREAS E INSPECCIÓN) ---
  Widget _buildPorAtenderSection(BuildContext context) {
    final tieneVencidos = _documentosVencidos.isNotEmpty;
    final hasTareas = _tareasPendientes.isNotEmpty;
    final hayAlgo = tieneVencidos || hasTareas || _inspeccionPendiente;

    if (!hayAlgo && !_cargando) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'POR ATENDER',
          subtitle: 'Elementos que requieren tu atención hoy',
        ),
        const SizedBox(height: 10),

        // Loading shimmer
        if (_cargando)
          _buildPorAtenderShimmer()

        else ...[ 
          // ── DOCUMENTOS VENCIDOS (una fila por documento) ──
          if (tieneVencidos) ...[
            _buildPorAtenderGroupCard(
              context: context,
              icon: Icons.gpp_maybe_rounded,
              iconBg: const Color(0xFFFFF1F2),
              iconColor: const Color(0xFFE11D48),
              borderColor: const Color(0xFFFECDD3),
              title: 'Documentos vencidos',
              count: _documentosVencidos.length,
              countColor: const Color(0xFFE11D48),
              countBg: const Color(0xFFFFF1F2),
              items: _documentosVencidos.take(3).map((doc) {
                final titulo = (doc['titulo'] ?? doc['nombre'] ?? 'Documento').toString();
                final sub = (doc['unidad'] ?? doc['subtitulo'] ?? doc['descripcion'] ?? '').toString();
                return _PorAtenderItem(
                  label: titulo,
                  sublabel: sub.isNotEmpty ? sub : null,
                  isCritical: true,
                );
              }).toList(),
              trailing: _documentosVencidos.length > 3
                  ? '+${_documentosVencidos.length - 3} más'
                  : null,
              onTap: () => _abrirDetalleDocumento(context, _documentosVencidos.first),
            ),
            const SizedBox(height: 10),
          ],

          // ── TAREAS (lista compacta, críticas primero) ──
          if (hasTareas) ...[
            _buildTareasCard(context),
            const SizedBox(height: 10),
          ],

          // ── INSPECCIÓN PENDIENTE ──
          if (_inspeccionPendiente)
            _buildInspeccionCard(context),
        ],
      ],
    );
  }

  // Shimmer placeholder mientras carga
  Widget _buildPorAtenderShimmer() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
          ),
        ),
      ),
    );
  }

  // ── CARD GENÉRICA DE GRUPO (documentos) ──
  Widget _buildPorAtenderGroupCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required Color borderColor,
    required String title,
    required int count,
    required Color countColor,
    required Color countBg,
    required List<_PorAtenderItem> items,
    String? trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: borderColor),
                    ),
                    child: Center(child: Icon(icon, color: iconColor, size: 19)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: countBg,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: countColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Filas de items
              ...items.map((item) => _buildDocItemRow(item, iconColor, borderColor)),
              if (trailing != null) ...[
                const SizedBox(height: 4),
                Text(
                  trailing,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: iconColor.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocItemRow(_PorAtenderItem item, Color accentColor, Color borderColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 8, top: 1),
            decoration: BoxDecoration(
              color: item.isCritical ? accentColor : const Color(0xFFCBD5E1),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: item.isCritical
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF334155),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.sublabel != null && item.sublabel!.isNotEmpty)
                  Text(
                    item.sublabel!,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (item.isCritical)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'VENCIDO',
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                  letterSpacing: 0.3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── CARD DE TAREAS (lista compacta con críticas) ──
  Widget _buildTareasCard(BuildContext context) {
    // Separar críticas de normales
    final criticas = _tareasPendientes.where((t) {
      final prio = (t['prioridad'] ?? t['priority'] ?? '').toString().toLowerCase();
      return prio == 'alta' || prio == 'urgente' || prio == 'critica' || prio == 'crítica';
    }).toList();
    final normales = _tareasPendientes.where((t) {
      final prio = (t['prioridad'] ?? t['priority'] ?? '').toString().toLowerCase();
      return !(prio == 'alta' || prio == 'urgente' || prio == 'critica' || prio == 'crítica');
    }).toList();

    final mostrarItems = [...criticas.take(2), ...normales.take(2 - criticas.take(2).length)];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TasksPage()),
          ).then((_) => _cargarDatosPorAtender());
        },
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: criticas.isNotEmpty
                  ? const Color(0xFFFDE68A)
                  : const Color(0xFFC7D2FE),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (criticas.isNotEmpty
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF6366F1))
                    .withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: criticas.isNotEmpty
                          ? const Color(0xFFFFFBEB)
                          : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: criticas.isNotEmpty
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFFC7D2FE),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        criticas.isNotEmpty
                            ? Icons.priority_high_rounded
                            : Icons.checklist_rounded,
                        color: criticas.isNotEmpty
                            ? const Color(0xFFD97706)
                            : const Color(0xFF4F46E5),
                        size: 19,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tareas pendientes',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (criticas.isNotEmpty)
                          Text(
                            '${criticas.length} crítica${criticas.length > 1 ? 's' : ''} · ${normales.length} normal${normales.length != 1 ? 'es' : ''}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: criticas.isNotEmpty
                          ? const Color(0xFFFFFBEB)
                          : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '${_tareasPendientes.length}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: criticas.isNotEmpty
                            ? const Color(0xFFD97706)
                            : const Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Lista de tareas (máx 3 visibles)
              ...mostrarItems.map((t) {
                final nombre = (t['titulo'] ?? t['nombre'] ?? t['descripcion'] ?? 'Tarea').toString();
                final prio = (t['prioridad'] ?? t['priority'] ?? '').toString().toLowerCase();
                final esCritica = prio == 'alta' || prio == 'urgente' || prio == 'critica' || prio == 'crítica';
                final vence = (t['fechaVencimiento'] ?? t['fecha_limite'] ?? t['due_date'] ?? '').toString();
                return _buildTareaItemRow(nombre, esCritica, vence);
              }),

              if (_tareasPendientes.length > 3) ...[
                const SizedBox(height: 2),
                Text(
                  '+${_tareasPendientes.length - 3} tareas más',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 10),

              // CTA
              Row(
                children: [
                  Text(
                    'Ver todas las tareas',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: criticas.isNotEmpty
                          ? const Color(0xFFD97706)
                          : const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 12,
                    color: criticas.isNotEmpty
                        ? const Color(0xFFD97706)
                        : const Color(0xFF4F46E5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTareaItemRow(String nombre, bool esCritica, String vence) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 8, top: 1),
            decoration: BoxDecoration(
              color: esCritica ? const Color(0xFFD97706) : const Color(0xFF6366F1),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              nombre,
              style: TextStyle(
                fontSize: 12,
                fontWeight: esCritica ? FontWeight.w600 : FontWeight.w500,
                color: const Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (esCritica)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'CRÍTICA',
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFD97706),
                  letterSpacing: 0.3,
                ),
              ),
            )
          else if (vence.isNotEmpty)
            Text(
              _formatVence(vence),
              style: const TextStyle(
                fontSize: 9.5,
                color: Color(0xFFCBD5E1),
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  String _formatVence(String fechaStr) {
    try {
      final fecha = DateTime.parse(fechaStr);
      final hoy = DateTime.now();
      final diff = fecha.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
      if (diff == 0) return 'Hoy';
      if (diff == 1) return 'Mañana';
      if (diff < 0) return 'Vencida';
      return 'en $diff d';
    } catch (_) {
      return '';
    }
  }

  // ── CARD DE INSPECCIÓN PENDIENTE ──
  Widget _buildInspeccionCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _abrirInspeccion(context),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Center(
                  child: Icon(Icons.fact_check_rounded,
                      color: Color(0xFF059669), size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Inspección pendiente',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'HOY',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF047857),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Aún no has realizado el checklist pre-operativo',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF059669), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentosVencidosCard(BuildContext context) {
    final tieneVencidos = _documentosVencidos.isNotEmpty;
    final doc = tieneVencidos ? _documentosVencidos.first : null;

    final tituloDoc = doc?['titulo'] ??
        doc?['nombre'] ??
        'Seguro de unidad vencido';
    final unidadDoc = doc?['unidad'] ??
        doc?['subtitulo'] ??
        'CAM-02 (DMO-202-B) · Venció el 25/10 (hace 5 d)';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _abrirDetalleDocumento(context, doc),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: tieneVencidos
                  ? const Color(0xFFFECDD3)
                  : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: tieneVencidos
                    ? const Color(0xFFF43F5E).withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tieneVencidos
                      ? const Color(0xFFFFF1F2)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: tieneVencidos
                        ? const Color(0xFFFECDD3)
                        : const Color(0xFFBBF7D0),
                  ),
                ),
                child: Center(
                  child: Icon(
                    tieneVencidos
                        ? Icons.warning_amber_rounded
                        : Icons.verified_outlined,
                    color: tieneVencidos
                        ? const Color(0xFFE11D48)
                        : const Color(0xFF16A34A),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            tieneVencidos
                                ? tituloDoc.toString()
                                : 'Documentación al corriente',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: tieneVencidos
                                ? const Color(0xFFE11D48)
                                : const Color(0xFF16A34A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tieneVencidos ? 'VENCIDO' : 'AL DÍA',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tieneVencidos
                          ? unidadDoc.toString()
                          : 'Sin pólizas ni trámites vencidos en tu unidad',
                      style: TextStyle(
                        fontSize: 11,
                        color: tieneVencidos
                            ? const Color(0xFFBE123C)
                            : const Color(0xFF64748B),
                        fontWeight: tieneVencidos
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: tieneVencidos
                    ? const Color(0xFFE11D48)
                    : const Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTareasPorAtenderCard(BuildContext context) {
    final hasTareas = _tareasPendientesCount > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TasksPage(),
            ),
          ).then((_) => _cargarDatosPorAtender());
        },
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasTareas
                  ? const Color(0xFFC7D2FE)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: hasTareas
                    ? const Color(0xFF6366F1).withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.task_alt_rounded,
                        color: Color(0xFF4F46E5),
                        size: 20,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: hasTareas
                          ? const Color(0xFFEEF2FF)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      hasTareas
                          ? '$_tareasPendientesCount activas'
                          : 'Al día',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: hasTareas
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tareas',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    hasTareas
                        ? '$_tareasPendientesCount pendientes'
                        : 'Sin tareas pendientes',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Text(
                    'Ver tareas',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  SizedBox(width: 3),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 12,
                    color: Color(0xFF4F46E5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInspeccionPorAtenderCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _abrirInspeccion(context),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.fact_check_outlined,
                        color: Color(0xFF059669),
                        size: 20,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Pendiente',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inspección',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Checklist pre-operativo',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Text(
                    'Realizar',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF059669),
                    ),
                  ),
                  SizedBox(width: 3),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 12,
                    color: Color(0xFF059669),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirInspeccion(BuildContext context) async {
    final session = MarkApiClient.instance.currentSession;
    final routesState = ref.read(routesProvider);
    final rutas = routesState.dayPackage?.rutas ?? const [];
    final activeRoute = rutas.where((r) => r.isActiva).firstOrNull ??
        rutas.where((r) => !r.isFinalizada).firstOrNull ??
        rutas.firstOrNull;

    Vehicle? targetVehicle;
    if (activeRoute?.vehiculo != null) {
      targetVehicle = Vehicle.fromMap({
        'idVehic': activeRoute!.vehiculo!.id,
        'economico': activeRoute.vehiculo!.economico,
        'placas': activeRoute.vehiculo!.placas,
        'Status': 'Activo',
      });
    } else {
      try {
        final vehiculos =
            await MarkApiClient.instance.getVehiculos(silent: true);
        if (vehiculos.isNotEmpty) {
          targetVehicle = Vehicle.fromMap(vehiculos.first);
        }
      } catch (_) {}
    }

    if (!context.mounted) return;

    if (targetVehicle != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SeleccionPlantillasPage(
            vehicle: targetVehicle!,
            userId: widget.userId,
            idCollaborator: widget.idCollaborator,
            idMainAccount: widget.idMainAccount.isNotEmpty
                ? widget.idMainAccount
                : (session?.usuario.idCuenta.toString() ?? ''),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MyVehiclePage(
            idMainAccount: widget.idMainAccount,
            idCollaborator: widget.idCollaborator,
            userId: widget.userId,
            inspectionsPermission:
                (session?.flota.can('inspeccion', 'crear') ?? true)
                    ? '1'
                    : '0',
          ),
        ),
      );
    }
  }

  void _abrirDetalleDocumento(BuildContext context, Map<String, dynamic>? doc) {
    if (doc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay documentos vencidos registrados.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFE11D48),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Documento Vencido',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          (doc['titulo'] ?? 'Póliza de seguro').toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE11D48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unidad: ${(doc['unidad'] ?? doc['economico'] ?? 'CAM-02 (DMO-202-B)')}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Detalle: ${(doc['descripcion'] ?? doc['mensaje'] ?? 'Venció el 25/10. Requiere atención o renovación administrativa.')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Entendido',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- ENCABEZADOS DE SECCIÓN (Estilo Apple HIG) ---
  Widget _buildSectionHeader(
      {required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // --- MÉTODOS PARA ABRIR REPORTES DE UNIDAD DESDE HOME ---
  Future<void> _abrirReporteFalla(BuildContext context) async {
    final routesState = ref.read(routesProvider);
    final rutas = routesState.dayPackage?.rutas ?? const [];
    final activeRoute = rutas.where((r) => r.isActiva).firstOrNull ??
        rutas.where((r) => !r.isFinalizada).firstOrNull ??
        rutas.firstOrNull;

    int vehicId = activeRoute?.vehiculo?.id ?? 0;
    String vehicName = activeRoute?.vehiculo?.economico ?? '';
    String vehicPlates = activeRoute?.vehiculo?.placas ?? '';

    if (vehicId <= 0) {
      try {
        final vehiculos =
            await MarkApiClient.instance.getVehiculos(silent: true);
        if (vehiculos.isNotEmpty) {
          final first = vehiculos.first;
          vehicId = int.tryParse(
                  (first['idVehic'] ?? first['id'] ?? '0').toString()) ??
              0;
          vehicName = (first['nombre'] ?? first['economico'] ?? 'Mi Unidad')
              .toString();
          vehicPlates = (first['placas'] ?? '').toString();
        }
      } catch (_) {}
    }

    if (!context.mounted) return;

    VehicleReportProblemSheet.show(
      context,
      idVehic: vehicId,
      vehicleName: vehicName.isNotEmpty ? vehicName : 'Mi Unidad',
      plates: vehicPlates,
    );
  }

  Future<void> _abrirReporteIncidencia(BuildContext context) async {
    final routesState = ref.read(routesProvider);
    final rutas = routesState.dayPackage?.rutas ?? const [];
    final activeRoute = rutas.where((r) => r.isActiva).firstOrNull ??
        rutas.where((r) => !r.isFinalizada).firstOrNull ??
        rutas.firstOrNull;

    int vehicId = activeRoute?.vehiculo?.id ?? 0;
    String vehicName = activeRoute?.vehiculo?.economico ?? '';
    String vehicPlates = activeRoute?.vehiculo?.placas ?? '';

    if (vehicId <= 0) {
      try {
        final vehiculos =
            await MarkApiClient.instance.getVehiculos(silent: true);
        if (vehiculos.isNotEmpty) {
          final first = vehiculos.first;
          vehicId = int.tryParse(
                  (first['idVehic'] ?? first['id'] ?? '0').toString()) ??
              0;
          vehicName = (first['nombre'] ?? first['economico'] ?? 'Mi Unidad')
              .toString();
          vehicPlates = (first['placas'] ?? '').toString();
        }
      } catch (_) {}
    }

    if (!context.mounted) return;

    VehicleReportIncidentSheet.show(
      context,
      idVehic: vehicId,
      vehicleName: vehicName.isNotEmpty ? vehicName : 'Mi Unidad',
      plates: vehicPlates,
    );
  }

  // --- 1. TARJETA CUADRADA: RASTREO SATELITAL (TRACKING) ---
  Widget _buildTrackingSquareCard(BuildContext context, HomeState state) {
    return Container(
      constraints: const BoxConstraints(minHeight: 114),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TrackingPage(userId: widget.userId),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(13.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Fila Superior: Icono y Flecha estilo Apple
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.satellite_alt_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 0.9,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_outward_rounded,
                          size: 13.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Centro: Textos
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rastreo Satelital',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 1.5),
                    Text(
                      'Mapa y geocercas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 2. TARJETA CUADRADA: REABASTECIMIENTO DE COMBUSTIBLE ---
  Widget _buildFuelSquareCard(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 114),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ServiceStationForm(
                  idMainAccount: widget.idMainAccount,
                  idCollaborator: widget.idCollaborator,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(13.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Fila Superior: Icono y Flecha estilo Apple
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D9488).withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.local_gas_station_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 0.9,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_outward_rounded,
                          size: 13.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Centro: Textos
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Combustible',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 1.5),
                    Text(
                      'Carga y odómetro',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 3. TARJETA CUADRADA: REPORTAR FALLA O AVERÍA (DETALLES UNIDAD) ---
  Widget _buildReportProblemSquareCard(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 114),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _abrirReporteFalla(context),
          child: Padding(
            padding: const EdgeInsets.all(13.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Fila Superior: Icono naranja y Flecha estilo Apple
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEA580C).withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.build_circle_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 0.9,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_outward_rounded,
                          size: 13.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Centro: Textos
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reportar Falla',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 1.5),
                    Text(
                      'Avería o servicio',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 4. TARJETA CUADRADA: INCIDENCIA / PERCANCE VIAL (DETALLES UNIDAD) ---
  Widget _buildReportIncidentSquareCard(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 114),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _abrirReporteIncidencia(context),
          child: Padding(
            padding: const EdgeInsets.all(13.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Fila Superior: Icono rojo y Flecha estilo Apple
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626).withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.car_crash_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 0.9,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_outward_rounded,
                          size: 13.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Centro: Textos
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incidencia Vial',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 1.5),
                    Text(
                      'Siniestro o percance',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildFeatureTag({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF475569)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET PROTOCOLO DE SEGURIDAD VIAL Y BUENAS PRÁCTICAS (Estilo Apple Card) ---
  Widget _buildSafetyProtocolCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0).withOpacity(0.85),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1E34).withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showSafetyProtocolModal(context),
          splashColor: const Color(0xFF0D9488).withOpacity(0.06),
          highlightColor: const Color(0xFFF8FAFC),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera: Squircle degradado verde azulado + Títulos + Badge
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF0D9488),
                            Color(0xFF14B8A6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D9488).withOpacity(0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.health_and_safety_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SEGURIDAD OPERATIVA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F766E).withOpacity(0.9),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Seguridad Vial y Buenas Prácticas',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFBF1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF0F766E),
                            size: 11,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Protocolo',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Descripción completa sin truncar
                const Text(
                  'Prioriza tu integridad y la de tu equipo. Aplica las normas básicas de prevención antes y durante cada jornada operativa.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),

                // Tags de Características estilo Apple Pills
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildFeatureTag(
                      icon: Icons.checklist_rounded,
                      label: 'Inspección Previa',
                    ),
                    _buildFeatureTag(
                      icon: Icons.speed_rounded,
                      label: 'Velocidad Segura',
                    ),
                    _buildFeatureTag(
                      icon: Icons.phone_disabled_rounded,
                      label: 'Cero Celular',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Botón Acción estilo Apple
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F766E).withOpacity(0.24),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Consultar protocolo de seguridad',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      SizedBox(width: 5),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- MODAL PROTOCOLO DE SEGURIDAD VIAL ESTILO APPLE HIG ---
  void _showSafetyProtocolModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 12,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de arrastre estilo iOS
              Center(
                child: Container(
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cabecera del modal
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.health_and_safety_rounded,
                      color: Color(0xFF0F766E),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Protocolo de Seguridad',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Normas de prevención y buenas prácticas en campo',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Elementos del protocolo
              _buildProtocolItem(
                icon: Icons.fact_check_rounded,
                title: '1. Inspección 360° antes de salir',
                description:
                    'Verifica presión de neumáticos, niveles de fluidos, luces y documentación de la unidad asignada.',
              ),
              const SizedBox(height: 12),
              _buildProtocolItem(
                icon: Icons.airline_seat_recline_normal_rounded,
                title: '2. Cinturón y postura defensiva',
                description:
                    'Uso obligatorio del cinturón de seguridad en todo momento y conservar distancia prudencial de frenado.',
              ),
              const SizedBox(height: 12),
              _buildProtocolItem(
                icon: Icons.phone_disabled_rounded,
                title: '3. Cero distracciones al volante',
                description:
                    'Prohibido manipular el celular durante el trayecto. Para llamadas operativas o navegación, estaciónate en zona segura.',
              ),
              const SizedBox(height: 12),
              _buildProtocolItem(
                icon: Icons.emergency_rounded,
                title: '4. Reporte oportuno de incidencias',
                description:
                    'Ante cualquier anomalía mecánica, siniestro o percance vial, notifica de inmediato a través del módulo de incidencias.',
              ),
              const SizedBox(height: 22),

              // Botón Entendido estilo Apple
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A1E34),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Entendido y Aceptado',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProtocolItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 17,
            color: const Color(0xFF0F766E),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Modelo auxiliar local para items de la sección "Por Atender"
class _PorAtenderItem {
  final String label;
  final String? sublabel;
  final bool isCritical;

  const _PorAtenderItem({
    required this.label,
    this.sublabel,
    this.isCritical = false,
  });
}
