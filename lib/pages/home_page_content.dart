import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';
import 'package:mark_v3/pages/ServiceStation_/ServiceStationPage.dart';
import 'package:mark_v3/pages/Trackingpage.dart';
import 'package:mark_v3/pages/notifications_page.dart';
import 'package:mark_v3/pages/Routes_/routes_page.dart';
import 'package:mark_v3/providers/Home_/home_provider.dart';
import 'package:mark_v3/providers/Routes_/routes_provider.dart';
import 'package:mark_v3/providers/Profile_/profile_provider.dart';
import 'package:mark_v3/services/mark_api_client.dart';

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

  @override
  void initState() {
    super.initState();
    _searchFocusNode.skipTraversal = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.unfocus();
      }
    });
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
    final session = routesState.session;
    final rol = (session?.rol ?? '').trim().toLowerCase();
    final isPreventa =
        session?.isPreventa == true || rol == 'preventa' || rol == 'vendedor';
    final isChofer = rol == 'chofer' || (!isPreventa && rol.isNotEmpty);

    final rutas = routesState.dayPackage?.rutas ?? const [];
    final DriverRoute? activeRoute = rutas.where((r) => r.isActiva).firstOrNull;

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
    // 1. Chofer: SOLO se muestra si tiene una ruta activa (activeRoute != null).
    // 2. Preventa u otro rol: se muestra el acceso de Preventa / Pedidos.
    final bool showHeroBanner = isPreventa
        ? showRoutes
        : (isChofer && activeRoute != null && showRoutes);

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
                      else if (activeRoute != null)
                        _buildActiveRouteHeroBanner(context, activeRoute),
                      const SizedBox(height: 20),
                    ],

                    // SECCIÓN: OPERACIONES EN CAMPO
                    if (showTracking || showRefill) ...[
                      _buildSectionHeader(
                        title: 'OPERACIONES EN CAMPO',
                        subtitle:
                            'Supervisión telemática en tiempo real y registros',
                      ),
                      const SizedBox(height: 9),
                    ],

                    // WIDGET DE RASTREO SATELITAL (Estilo Apple Control Center Card)
                    if (showTracking) ...[
                      _buildTrackingCard(context, homeState, homeNotifier),
                      const SizedBox(height: 14),
                    ],

                    // WIDGET DE REABASTECIMIENTO DE COMBUSTIBLE (Estilo Apple Card)
                    if (showRefill) ...[
                      _buildFuelRefillCard(context),
                      const SizedBox(height: 20),
                    ],

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
              Row(
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

  // --- WIDGET PRINCIPAL: RUTA ACTIVA (Estilo Apple Live Activity Card) ---
  Widget _buildActiveRouteHeroBanner(
      BuildContext context, DriverRoute activeRoute) {
    final totalStops = activeRoute.totalClientStops;
    final doneStops = activeRoute.visitedClientStops;
    final progress =
        totalStops > 0 ? (doneStops / totalStops).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).toInt();

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
                // Tag superior: Ruta activa en curso (Apple Live Activity Chip)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.5, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.06),
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
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.55),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Ruta en Curso · Activa',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF047857),
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Continuar ruta',
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

  // --- WIDGET RASTREO (Estilo Apple Control Center Card) ---
  Widget _buildTrackingCard(
    BuildContext context,
    HomeState state,
    HomeNotifier notifier,
  ) {
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TrackingPage(userId: widget.userId),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila Superior: Squircle Icon + Títulos + Badge Apple
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Squircle Ícono estilo iOS
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF0284C7),
                                Color(0xFF38BDF8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(11),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF0284C7).withOpacity(0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.satellite_alt_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MONITOREO DE UNIDADES',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Rastreo Satelital',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Badge de Estado estilo Apple
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: state.isGpsActive
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fiber_manual_record,
                            color: state.isGpsActive
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                            size: 8,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            state.isGpsActive ? 'GPS Activo' : 'GPS Inactivo',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: state.isGpsActive
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Descripción
                Text(
                  'Visualiza la posición de tu unidad en tiempo real, geocercas y alertas operativas en mapa.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),

                // Sub-widgets informativos estilo cápsula Apple
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0).withOpacity(0.7),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF16A34A),
                              size: 16,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Transmisión',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    state.transmissionStatus,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0).withOpacity(0.7),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.navigation_rounded,
                              color: Color(0xFF0284C7),
                              size: 16,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Zona Operativa',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    state.activeZone,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Botón Acción Primaria al estilo Apple
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9.5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0284C7),
                        Color(0xFF0369A1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Ver mapa de rastreo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      SizedBox(width: 5),
                      Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 14),
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

  // --- WIDGET REABASTECIMIENTO DE COMBUSTIBLE (Estilo Apple Card) ---
  Widget _buildFuelRefillCard(BuildContext context) {
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
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Squircle Ícono
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF0891B2),
                                Color(0xFF06B6D4),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(11),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF0891B2).withOpacity(0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.local_gas_station_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CONTROL DE FLOTA',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Reabastecimiento',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Chip Apple de categoría
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.ev_station_rounded,
                              color: Color(0xFF0284C7), size: 11),
                          SizedBox(width: 4),
                          Text(
                            'Estación',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Descripción
                const Text(
                  'Registra la carga de combustible, kilometraje de odómetro y comprobantes de la estación.',
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
                      icon: Icons.confirmation_number_outlined,
                      label: 'Registro de Ticket',
                    ),
                    _buildFeatureTag(
                      icon: Icons.speed_rounded,
                      label: 'Lectura de Odómetro',
                    ),
                    _buildFeatureTag(
                      icon: Icons.water_drop_outlined,
                      label: 'Litros Cargados',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Botón Acción estilo Apple
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1E34),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A1E34).withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Registrar carga de combustible',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      SizedBox(width: 5),
                      Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 14),
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
}
