import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/pages/Profile_/EditProfilePage.dart';
import 'package:mark_v3/pages/ServiceStation_/ServiceStationPage.dart';
import 'package:mark_v3/pages/Trackingpage.dart';
import 'package:mark_v3/pages/notifications_page.dart';
import 'package:mark_v3/pages/Routes_/routes_page.dart';
import 'package:mark_v3/providers/home_provider.dart';

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
    final query = homeState.searchQuery.toLowerCase();

    // Filtros reactivos con Riverpod
    final showRoutes = query.isEmpty ||
        'rutas'.contains(query) ||
        'itinerario'.contains(query) ||
        'logistica'.contains(query) ||
        'paradas'.contains(query);

    final showTracking = query.isEmpty ||
        'rastreo'.contains(query) ||
        'gps'.contains(query) ||
        'monitoreo'.contains(query) ||
        'unidades'.contains(query) ||
        'mapa'.contains(query);

    final showRefill = query.isEmpty ||
        'reabastecimiento'.contains(query) ||
        'combustible'.contains(query) ||
        'gasolina'.contains(query) ||
        'estacion'.contains(query) ||
        'carga'.contains(query) ||
        'odometro'.contains(query);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF0886B5),
          onRefresh: () => homeNotifier.refreshHome(widget.userId),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Avatar + Bienvenida + Notificaciones
                _buildHeader(context, homeState),
                const SizedBox(height: 12),

                // Buscador conectado a Riverpod
                _buildSearchBar(context, homeNotifier, query),
                const SizedBox(height: 14),

                // WIDGET PRINCIPAL: Banner Destacado de Rutas (Estilo Moving Day del mockup)
                if (showRoutes) ...[
                  _buildRoutesHeroBanner(context),
                  const SizedBox(height: 16),
                ],

                // SECCIÓN: OPERACIONES EN CAMPO
                if (showTracking || showRefill) ...[
                  _buildSectionHeader(
                    title: 'Operaciones en Campo',
                    subtitle: 'Supervisión en tiempo real y registros',
                  ),
                  const SizedBox(height: 10),
                ],

                // WIDGET DE RASTREO SATELITAL (Estilo Card Financiera / Control Center)
                if (showTracking) ...[
                  _buildTrackingCard(context, homeState, homeNotifier),
                  const SizedBox(height: 12),
                ],

                // WIDGET DE REABASTECIMIENTO DE COMBUSTIBLE
                if (showRefill) ...[
                  _buildFuelRefillCard(context),
                  const SizedBox(height: 16),
                ],

                // SECCIÓN: ACCESOS RÁPIDOS / SERVICIOS (Estilo Services del mockup)
                _buildSectionHeader(
                  title: 'Servicios y Accesos',
                  subtitle: 'Gestión directa de tu cuenta y unidades',
                ),
                const SizedBox(height: 10),
                _buildServicesRow(context, query),
                const SizedBox(height: 85),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- HEADER: Perfil + Saludo + Notificaciones ---
  Widget _buildHeader(BuildContext context, HomeState state) {
    return Row(
      children: [
        // Avatar con borde moderno
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: const Color(0xFF0886B5).withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/person.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.person,
                color: Color(0xFF0886B5),
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Saludo y Nombre
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Bienvenido de nuevo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('👋', style: TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 1),
              Builder(
                builder: (context) {
                  String displayName = widget.usuario.trim();
                  if (displayName.contains('@')) {
                    displayName = displayName.split('@').first;
                  }
                  if (displayName.isNotEmpty) {
                    displayName = displayName[0].toUpperCase() + displayName.substring(1);
                  } else {
                    displayName = 'Colaborador';
                  }
                  return Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Botón de Notificaciones
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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
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
                    top: 8,
                    right: 9,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
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

  // --- BUSCADOR REACTIVO CON RIVERPOD ---
  Widget _buildSearchBar(
    BuildContext context,
    HomeNotifier notifier,
    String activeQuery,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: Colors.grey[500], size: 20),
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
                cursorColor: const Color(0xFF0886B5),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF0F172A),
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
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 13, color: Colors.black54),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(Icons.tune_rounded, color: Colors.grey[600], size: 16),
            ),
        ],
      ),
    );
  }

  // --- WIDGET PRINCIPAL: RUTAS (Banner Hero) ---
  Widget _buildRoutesHeroBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF7ED), // Durazno suave
            Color(0xFFFFEDD5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFFED7AA).withOpacity(0.8),
          width: 1.0,
        ),
      ),
      child: Stack(
        children: [
          // Imagen / Ilustración más compacta
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tag superior
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 3,
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
                          color: Color(0xFFEA580C),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Itinerario & Logística',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFC2410C),
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
                    'Gestión de Rutas',
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
                    'Consulta tus paradas asignadas, tiempos y clientes de hoy.',
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

                // Botón Call To Action: "Ir a rutas ➔"
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RoutesPage(
                            idCollaborator: widget.idCollaborator,
                            idMainAccount: widget.idMainAccount,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFEA580C),
                            Color(0xFFC2410C),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEA580C).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ir a rutas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                          ),
                          SizedBox(width: 6),
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

  // --- ENCABEZADOS DE SECCIÓN ---
  Widget _buildSectionHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.grey[500],
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // --- WIDGET RASTREO (Tracking Card - Reactivo con Riverpod) ---
  Widget _buildTrackingCard(
    BuildContext context,
    HomeState state,
    HomeNotifier notifier,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TrackingPage(userId: widget.userId),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila Superior: Título de Categoría + Badge Estado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0886B5).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFF0886B5),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
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
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Badge de Estado en Vivo (conectado a Riverpod)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: state.isGpsActive
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(16),
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
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),

                // Sub-widgets informativos
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: Colors.black.withOpacity(0.03)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Icon(
                                Icons.check_circle_outline_rounded,
                                color: Color(0xFF16A34A),
                                size: 14,
                              ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: Colors.black.withOpacity(0.03)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Icon(
                                Icons.navigation_rounded,
                                color: Color(0xFF0284C7),
                                size: 14,
                              ),
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

                // Botón Acción Primaria de Rastreo
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0886B5),
                    borderRadius: BorderRadius.circular(12),
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
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
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

  // --- WIDGET REABASTECIMIENTO DE COMBUSTIBLE ---
  Widget _buildFuelRefillCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
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
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.local_gas_station_rounded,
                            color: Color(0xFFD97706),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
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
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Chip de categoría
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.ev_station_rounded, color: Color(0xFFB45309), size: 11),
                          SizedBox(width: 4),
                          Text(
                            'Estación',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB45309),
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
                  'Registra la carga de combustible, kilometraje de odómetro y comprobantes de la estación.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),

                // Tags de Características
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

                // Botón Acción
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 16),
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
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
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

  // --- FILA DE SERVICIOS / ACCESOS RÁPIDOS ---
  Widget _buildServicesRow(BuildContext context, String filterQuery) {
    final services = [
      {
        'title': 'Rutas',
        'icon': Icons.alt_route_rounded,
        'color': const Color(0xFFEA580C),
        'bg': const Color(0xFFFFF7ED),
        'page': RoutesPage(
          idCollaborator: widget.idCollaborator,
          idMainAccount: widget.idMainAccount,
        ),
      },
      {
        'title': 'Rastreo',
        'icon': Icons.pin_drop_rounded,
        'color': const Color(0xFF0886B5),
        'bg': const Color(0xFFE0F2FE),
        'page': TrackingPage(userId: widget.userId),
      },
      {
        'title': 'Carga',
        'icon': Icons.local_gas_station_rounded,
        'color': const Color(0xFFD97706),
        'bg': const Color(0xFFFEF3C7),
        'page': ServiceStationForm(
          idMainAccount: widget.idMainAccount,
          idCollaborator: widget.idCollaborator,
        ),
      },
      {
        'title': 'Perfil',
        'icon': Icons.person_rounded,
        'color': const Color(0xFF7C3AED),
        'bg': const Color(0xFFF3E8FF),
        'page': EditProfilePage(
          idCollaborator: widget.idCollaborator,
          idMainAccount: widget.idMainAccount,
        ),
      },
      {
        'title': 'Avisos',
        'icon': Icons.notifications_active_rounded,
        'color': const Color(0xFF0284C7),
        'bg': const Color(0xFFF0F9FF),
        'page': NotificationsPage(
          userId: widget.userId,
          showBackButton: true,
        ),
      },
    ];

    final filtered = filterQuery.isEmpty
        ? services
        : services
            .where((s) => (s['title'] as String)
                .toLowerCase()
                .contains(filterQuery.toLowerCase()))
            .toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: (filtered.isEmpty ? services : filtered).map((service) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => service['page'] as Widget,
                    ),
                  );
                },
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: service['bg'] as Color,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        service['icon'] as IconData,
                        color: service['color'] as Color,
                        size: 21,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      service['title'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
