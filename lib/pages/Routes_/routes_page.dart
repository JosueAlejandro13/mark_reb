import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';
import 'package:mark_v3/pages/Routes_/cedi_warehouse_page.dart';
import 'package:mark_v3/pages/Routes_/order_delivery_page.dart';
import 'package:mark_v3/pages/Routes_/client_visit_page.dart';
import 'package:mark_v3/providers/Routes_/routes_provider.dart';
import 'package:mark_v3/pages/Routes_/driver_sync_widgets.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mark_v3/services/ConnectionTracking_/TrackingCon_service.dart';

/// Pantalla Principal "Mi Día" — Integración completa con deliveryPHP/operacion/api.php (MarkV3.1)
class RoutesPage extends ConsumerStatefulWidget {
  final String idCollaborator;
  final String idMainAccount;

  const RoutesPage({
    super.key,
    required this.idCollaborator,
    required this.idMainAccount,
  });

  @override
  ConsumerState<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends ConsumerState<RoutesPage>
    with SingleTickerProviderStateMixin {
  late TabController _mainTabController;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(routesProvider.notifier).initializeModule();
    });
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    super.dispose();
  }

  Future<void> _selectDayDate(String currentDateStr) async {
    final now = DateTime.now();
    DateTime initial = now;
    try {
      initial = DateTime.parse(currentDateStr);
    } catch (_) {}

    // Regla: "Máximo 7 días antes o después"
    final first = now.subtract(const Duration(days: 7));
    final last = now.add(const Duration(days: 7));
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0284C7),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final formatted = DateFormat('yyyy-MM-dd').format(picked);
      await ref.read(routesProvider.notifier).changeDate(formatted);
    }
  }

  void _openManualAuthModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DriverCredentialsSheet(),
    );
  }

  void _openRejectedTray() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RejectedActionsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routesProvider);

    // Mostrar avisos recientes del servidor cuando lleguen de una sincronización en segundo plano
    ref.listen<RoutesState>(routesProvider, (prev, next) {
      if (next.recentNotices.isNotEmpty &&
          prev?.recentNotices != next.recentNotices) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final notices = next.recentNotices;
            ref.read(routesProvider.notifier).clearRecentNotices();

            final hasCritical = notices.any((n) => n.isCriticalRedAlert);
            final hasWarning = notices.any((n) => n.nivel == 'aviso');
            final text = notices.map((n) => n.displayTexto).join('\n');

            final isPositiveStatus = notices.any((n) {
              final lower = n.texto.toLowerCase();
              return lower.contains('iniciada') ||
                  lower.contains('cerrada') ||
                  lower.contains('finalizada') ||
                  lower.contains('éxito') ||
                  lower.contains('exito');
            });

            if (hasCritical) {
              SnackbarTop.showError(context, text, title: 'Error');
            } else if (isPositiveStatus) {
              SnackbarTop.showSuccess(context, text, title: 'Correcto');
            } else if (hasWarning) {
              SnackbarTop.showWarning(context, text, title: 'Aviso');
            } else {
              SnackbarTop.showInfo(context, text, title: 'Información');
            }
          }
        });
      }
    });

    final session = state.session;
    final isPreventa = session?.isPreventa == true;
    final permisos = session?.permisos ?? const DriverPermissions();
    final showRoutesTab = !isPreventa && permisos.rutas;
    final showOrdersTab =
        permisos.pedidos || permisos.clientesNuevos || isPreventa;

    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isSmallScreen = mediaQuery.size.width < 360;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF8FAFC),
          surfaceTintColor: Colors.transparent,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          toolbarHeight: 62,
          centerTitle: false,
          automaticallyImplyLeading: false,
          leadingWidth: Navigator.canPop(context) ? 54 : 0,
          titleSpacing: Navigator.canPop(context) ? 12 : 16,
          leading: Navigator.canPop(context)
              ? Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Center(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Color(0xFF0F172A),
                              size: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isPreventa ? 'Preventa' : 'Mi Día — Operación',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                isPreventa
                    ? 'Gestión de clientes, catálogo y pedidos'
                    : 'Rutas asignadas y entregas del día',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          actions: const [],
          bottom: (showRoutesTab && showOrdersTab)
              ? TabBar(
                  controller: _mainTabController,
                  indicatorColor: const Color(0xFF0284C7),
                  indicatorWeight: 2.5,
                  labelColor: const Color(0xFF0284C7),
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  tabs: [
                    Tab(
                      height: 48,
                      iconMargin: const EdgeInsets.only(bottom: 2),
                      icon: const Icon(Icons.route_rounded, size: 19),
                      text:
                          'Mis Rutas (${state.dayPackage?.fecha == state.selectedDate ? (state.dayPackage?.rutas.length ?? 0) : 0})',
                    ),
                    const Tab(
                      height: 48,
                      iconMargin: EdgeInsets.only(bottom: 2),
                      icon: Icon(Icons.storefront_rounded, size: 19),
                      text: 'Pedidos y Clientes',
                    ),
                  ],
                )
              : null,
        ),
        body: Column(
          children: [
            Expanded(
              child: (state.isLoading &&
                      (state.dayPackage == null ||
                          state.dayPackage?.fecha != state.selectedDate))
                  ? _buildRoutesLoadingSkeleton()
                  : (showRoutesTab && showOrdersTab)
                      ? TabBarView(
                          controller: _mainTabController,
                          children: [
                            _buildRoutesListTab(state),
                            OrdersAndNewClientsView(
                              topDateBar: _buildTopDateAndActionsBar(state),
                              authBanner: state.requiresManualAuth
                                  ? _buildAuthBanner(state)
                                  : null,
                              visitRouteIdForOutOfRoute:
                                  (state.dayPackage?.fecha ==
                                          state.selectedDate)
                                      ? state.dayPackage?.rutas
                                          .where((r) => r.isVisitRoute)
                                          .map((r) => r.idRuta)
                                          .firstOrNull
                                      : null,
                            ),
                          ],
                        )
                      : showRoutesTab
                          ? _buildRoutesListTab(state)
                          : OrdersAndNewClientsView(
                              topDateBar: _buildTopDateAndActionsBar(state),
                              authBanner: state.requiresManualAuth
                                  ? _buildAuthBanner(state)
                                  : null,
                            ),
            ),

            // BARRA DE ESTADO DE COLA SIN CONEXIÓN Y SINCRONIZACIÓN (FOOTER INFERIOR)
            const DriverSyncStatusBar(),
          ],
        ),
      ),
    );
  }

  /// Skeleton animado estilo Apple para la carga de rutas del día.
  Widget _buildRoutesLoadingSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: List.generate(3, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera skeleton
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      const AppShimmerBox(
                          width: 38, height: 38, borderRadius: 10),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            AppShimmerBox.text(width: 150, height: 14),
                            SizedBox(height: 6),
                            AppShimmerBox.text(width: 90, height: 11),
                          ],
                        ),
                      ),
                      const AppShimmerBox(
                          width: 72, height: 22, borderRadius: 8),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                // Cuerpo skeleton
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chips de info skeleton
                      Row(
                        children: const [
                          AppShimmerBox(
                              width: 120, height: 24, borderRadius: 7),
                          SizedBox(width: 8),
                          AppShimmerBox(width: 90, height: 24, borderRadius: 7),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Fila de progreso
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          AppShimmerBox.text(width: 160, height: 11),
                          AppShimmerBox(width: 36, height: 16, borderRadius: 6),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const AppShimmerBox(
                          width: double.infinity, height: 7, borderRadius: 10),
                      const SizedBox(height: 14),
                      // Botones skeleton
                      Row(
                        children: const [
                          Expanded(
                            child: AppShimmerBox(
                                width: double.infinity,
                                height: 44,
                                borderRadius: 12),
                          ),
                          SizedBox(width: 8),
                          AppShimmerBox(
                              width: 80, height: 44, borderRadius: 12),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTopDateAndActionsBar(RoutesState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Selector de fecha interactivo tipo chip/tarjeta ejecutiva
          InkWell(
            onTap: () => _selectDayDate(state.selectedDate),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 15,
                    color: Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.selectedDate,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),

          // Botón de sincronización con margen independiente
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              padding: const EdgeInsets.all(9),
              minimumSize: const Size(38, 38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: state.isSyncing
                ? null
                : () async {
                    await ref
                        .read(routesProvider.notifier)
                        .syncPendingQueueAndRefreshDay(
                          forceRefreshDay: true,
                          isUserInitiated: true,
                        );
                  },
            icon: state.isSyncing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: Center(
                      child: LoadingAnimationWidget.threeRotatingDots(
                        color: const Color(0xFF0284C7),
                        size: 16,
                      ),
                    ),
                  )
                : const Icon(Icons.sync_rounded, size: 18),
            tooltip: 'Sincronizar cola y actualizar día',
          ),
        ],
      ),
    );
  }

  Widget _buildAuthBanner(RoutesState state) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_person_rounded,
              color: Color(0xFFB45309), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.authError ??
                  'Sesión expirada en el servidor. Su cola local está segura.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _openManualAuthModal,
            child: const Text(
              'Conectar',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFFB45309),
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutesListTab(RoutesState state) {
    if (state.dayPackage != null &&
        state.dayPackage!.fecha != state.selectedDate) {
      return _buildRoutesLoadingSkeleton();
    }
    final pkg = state.dayPackage;
    final rutas = pkg?.rutas ?? const [];

    if (rutas.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFF0284C7),
        onRefresh: () => ref
            .read(routesProvider.notifier)
            .syncPendingQueueAndRefreshDay(forceRefreshDay: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _buildTopDateAndActionsBar(state),
            if (state.requiresManualAuth) _buildAuthBanner(state),
            const SizedBox(height: 40),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  Icons.alt_route_rounded,
                  size: 36,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sin rutas asignadas para ${state.selectedDate}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Deslice hacia abajo para consultar de nuevo el paquete del día o elija otra fecha en el calendario superior.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF0284C7),
      onRefresh: () => ref
          .read(routesProvider.notifier)
          .syncPendingQueueAndRefreshDay(forceRefreshDay: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: rutas.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTopDateAndActionsBar(state),
                if (state.requiresManualAuth) _buildAuthBanner(state),
                const SizedBox(height: 6),
              ],
            );
          }
          final route = rutas[index - 1];
          // En móvil: navegar a pantalla completa al tocar
          return _buildRouteCard(
            route,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RouteDetailAndMapPage(idRuta: route.idRuta),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRouteCard(
    DriverRoute route, {
    VoidCallback? onTap,
    bool isHighlighted = false,
  }) {
    final totalStops = route.totalClientStops;
    final doneStops = route.visitedClientStops;
    final progress = totalStops > 0 ? (doneStops / totalStops) : 0.0;
    final distKm = route.geometria != null && route.geometria!.distanciaM > 0
        ? (route.geometria!.distanciaM / 1000).toStringAsFixed(1)
        : null;
    final durMin = route.geometria != null && route.geometria!.duracionS > 0
        ? (route.geometria!.duracionS / 60).round()
        : null;

    final isDone = progress >= 1.0;
    final progressColor =
        isDone ? const Color(0xFF10B981) : const Color(0xFF0284C7);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFFF0F9FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFF0284C7).withOpacity(0.5)
              : const Color(0xFFE2E8F0),
          width: isHighlighted ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? const Color(0xFF0284C7).withOpacity(0.08)
                : Colors.black.withOpacity(0.02),
            blurRadius: isHighlighted ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap ??
              () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          RouteDetailAndMapPage(idRuta: route.idRuta),
                    ),
                  ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cabecera ─────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Center(
                        child: Icon(
                          route.isVisitRoute
                              ? Icons.storefront_rounded
                              : Icons.local_shipping_rounded,
                          color: const Color(0xFF0284C7),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            route.nombre,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            route.modalidadNombre,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Builder(
                      builder: (_) {
                        Color bg;
                        Color border;
                        Color text;
                        switch (route.operationalRoute) {
                          case 1:
                            bg = const Color(0xFFF0FDF4);
                            border = const Color(0xFFBBF7D0);
                            text = const Color(0xFF047857);
                            break;
                          case 2:
                            bg = const Color(0xFFF1F5F9);
                            border = const Color(0xFFCBD5E1);
                            text = const Color(0xFF475569);
                            break;
                          case 3:
                            bg = const Color(0xFFFEF3C7);
                            border = const Color(0xFFFCD34D);
                            text = const Color(0xFF92400E);
                            break;
                          case 0:
                          default:
                            if (route.operacional) {
                              bg = const Color(0xFFF0FDF4);
                              border = const Color(0xFFBBF7D0);
                              text = const Color(0xFF047857);
                            } else {
                              bg = const Color(0xFFFFFBEB);
                              border = const Color(0xFFFDE68A);
                              text = const Color(0xFFB45309);
                            }
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: border),
                          ),
                          child: Text(
                            route.operationalStatusText,
                            style: TextStyle(
                              color: text,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ── Cuerpo ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 12, 15, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chips de info
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (route.vehiculo != null)
                          _buildInfoChip(
                            Icons.directions_car_filled_rounded,
                            '${route.vehiculo!.economico} (${route.vehiculo!.placas})',
                            iconColor: const Color(0xFF0284C7),
                            bg: const Color(0xFFF0F9FF),
                            borderColor: const Color(0xFFBAE6FD),
                            textColor: const Color(0xFF0369A1),
                          ),
                        if (route.cedi != null && route.cedi!.nombre.isNotEmpty)
                          _buildInfoChip(
                            Icons.warehouse_rounded,
                            route.cedi!.nombre,
                            iconColor: const Color(0xFF475569),
                            bg: const Color(0xFFF8FAFC),
                            borderColor: const Color(0xFFE2E8F0),
                            textColor: const Color(0xFF334155),
                          ),
                        if (distKm != null)
                          _buildInfoChip(
                            Icons.navigation_rounded,
                            '$distKm km${durMin != null ? " · ~$durMin min" : ""}',
                            iconColor: const Color(0xFFEA580C),
                            bg: const Color(0xFFFFF7ED),
                            borderColor: const Color(0xFFFFEDD5),
                            textColor: const Color(0xFFC2410C),
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Progreso
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Paradas de cliente: $doneStops de $totalStops completadas',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDone
                                ? const Color(0xFFF0FDF4)
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${(progress * 100).round()}%',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: progressColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF0284C7),
                                  Color(0xFF0369A1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF0284C7).withOpacity(0.28),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RouteDetailAndMapPage(
                                        idRuta: route.idRuta),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.map_rounded, size: 16),
                              label: const Text(
                                'Ver Recorrido y Paradas',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!route.isVisitRoute) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CediOperationsPage(idRuta: route.idRuta),
                                ),
                              );
                            },
                            icon: const Icon(Icons.qr_code_scanner_rounded,
                                size: 15, color: Color(0xFF0284C7)),
                            label: const Text('CEDI',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    IconData icon,
    String text, {
    Color? iconColor,
    Color? bg,
    Color? borderColor,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor ?? const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor ?? const Color(0xFF0284C7)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor ?? const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PANTALLA DE DETALLE DE RUTA: MAPA CON POLILÍNEA (polyline5) + PARADAS EN ORDEN
// =============================================================================

class RouteDetailAndMapPage extends ConsumerStatefulWidget {
  final int idRuta;

  /// Si es `true`, la página está embebida en un layout de split view (tablet)
  /// y no debe mostrar un botón de retroceso propio ni navegación push/pop.
  final bool isEmbedded;

  const RouteDetailAndMapPage({
    super.key,
    required this.idRuta,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<RouteDetailAndMapPage> createState() =>
      _RouteDetailAndMapPageState();
}

class _RouteDetailAndMapPageState extends ConsumerState<RouteDetailAndMapPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  GoogleMapController? _mapController;
  bool _mapExpanded = false;
  bool _isExecutingRouteAction = false;
  final Map<int, bool> _stopExpandedOverride = {};
  final MapType _mapType = MapType.normal;
  final bool _showTraffic = false;
  bool _showJourneyEstimates = true;
  final bool _showMapControls = true;
  bool _isTopBarCollapsed = false;
  late AnimationController _pulseController;
  bool _isTrackingLocation = false;
  bool _isTrackingVehicle = false;
  StreamSubscription<Position>? _liveGpsSub;
  final Set<int> _autoLlegadaTriggered = {};
  bool _isAutoLlegadaInProgress = false;

  BitmapDescriptor? _personMarkerIcon;
  BitmapDescriptor? _truckMarkerIcon;
  LatLng? _vehicleLocation;
  double _vehicleDirection = 0.0;
  bool _vehicleIsActive = false;
  Timer? _vehicleTelemetryTimer;
  int? _lastVehicIdTracked;

  @override
  void initState() {
    super.initState();
    // Esta pantalla (Detalle de Ruta y Mapa) sí soporta horizontal y vertical (ideal para tablet/split-view)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startContinuousGpsStream();
      _loadMapIcons();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vehicleTelemetryTimer?.cancel();
    // Rebloquear toda la app en vertical al salir de la pantalla de ruta/mapa
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _liveGpsSub?.cancel();
    _liveGpsSub = null;
    _pulseController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Al volver de Google Maps / Waze al destino, refrescar GPS de inmediato y validar llegada
      _startContinuousGpsStream();
    }
  }

  Future<void> _loadMapIcons() async {
    try {
      // 1. Icono de persona / chofer para reemplazar el punto azul
      final personData = await rootBundle.load('assets/person_marker.png');
      final personCodec = await ui.instantiateImageCodec(
        personData.buffer.asUint8List(),
        targetHeight: 90,
      );
      final personFi = await personCodec.getNextFrame();
      final personBytes =
          await personFi.image.toByteData(format: ui.ImageByteFormat.png);
      if (personBytes != null) {
        _personMarkerIcon =
            BitmapDescriptor.fromBytes(personBytes.buffer.asUint8List());
      }

      // 2. Icono de vehículo en ruta (top-down 360°, Verde Esmeralda de alta visibilidad)
      final truckData = await rootBundle.load('assets/truck_top_green.png');
      final truckCodec = await ui.instantiateImageCodec(
        truckData.buffer.asUint8List(),
        targetWidth: 80,
      );
      final truckFi = await truckCodec.getNextFrame();
      final truckBytes =
          await truckFi.image.toByteData(format: ui.ImageByteFormat.png);
      if (truckBytes != null) {
        _truckMarkerIcon =
            BitmapDescriptor.fromBytes(truckBytes.buffer.asUint8List());
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error cargando iconos para mapa de rutas: $e');
    }
  }

  void _startVehicleTrackingTimer(int vehicId) {
    if (_lastVehicIdTracked == vehicId && _vehicleTelemetryTimer != null) {
      return;
    }
    _lastVehicIdTracked = vehicId;
    _vehicleTelemetryTimer?.cancel();
    _fetchRouteVehicleTelemetry(vehicId);
    _vehicleTelemetryTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _fetchRouteVehicleTelemetry(vehicId);
    });
  }

  Future<void> _fetchRouteVehicleTelemetry(int vehicId) async {
    try {
      final data =
          await TrackingconService().obtenerTracking(vehicId.toString());
      if (data.isNotEmpty && mounted) {
        final v = data.first;
        final lat = double.tryParse(v['lat']?.toString() ?? '0') ?? 0.0;
        final lng = double.tryParse(v['lng']?.toString() ?? '0') ?? 0.0;
        final dir = double.tryParse(v['dir']?.toString() ?? '0') ?? 0.0;
        final ign = (v['ignStatus'] ?? 0) == 1;

        if (lat != 0.0 && lng != 0.0) {
          final newLoc = LatLng(lat, lng);
          setState(() {
            _vehicleLocation = newLoc;
            _vehicleDirection = dir;
            _vehicleIsActive = ign;
          });

          // Actualizar posición telemétrica del vehículo en el provider para distancias reactivas
          ref.read(routesProvider.notifier).updateVehiclePosition(lat, lng);

          // Verificar si el vehículo o teléfono entró en geocerca de llegada
          _checkAutoLlegada();

          // Si el seguimiento del vehículo está activo, seguir con la cámara
          if (_isTrackingVehicle) {
            _animateCameraToLatLng(newLoc);
          }
        }
      }
    } catch (_) {}
  }

  /// Inicia el stream continuo de GPS para:
  /// 1. Actualizar las distancias en tiempo real de cada parada (ej. 17.6km -> 200m).
  /// 2. Auto-marcar llegada por geocerca cuando el chofer entra en rango (<= 300m).
  /// 3. Seguir la ubicación en el mapa si el botón de tracking está activo.
  Future<void> _startContinuousGpsStream() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      // Obtener posición inicial de inmediato para refrescar distancias al entrar
      try {
        final initialPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 3),
        );
        if (mounted) {
          ref.read(routesProvider.notifier).updatePosition(initialPos);
          if (_isTrackingLocation) {
            _animateCameraToPosition(initialPos);
          }
          _checkAutoLlegada();
        }
      } catch (_) {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null && mounted) {
          ref.read(routesProvider.notifier).updatePosition(lastPos);
          if (_isTrackingLocation) {
            _animateCameraToPosition(lastPos);
          }
          _checkAutoLlegada();
        }
      }

      // Stream continuo con filtro de 5 metros
      _liveGpsSub?.cancel();
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      _liveGpsSub = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        (Position pos) {
          if (!mounted) return;
          // 1. Actualizar distancia en tiempo real en el provider (recalcula tarjetas)
          ref.read(routesProvider.notifier).updatePosition(pos);

          // 2. Si el botón de centrado está activo, seguir con la cámara
          if (_isTrackingLocation) {
            _animateCameraToPosition(pos);
          }

          // 3. Revisar si entró a la geocerca de alguna parada para auto-marcar llegada
          _checkAutoLlegada();
        },
        onError: (err) {
          debugPrint('Aviso en stream de GPS continuo: $err');
        },
      );
    } catch (e) {
      debugPrint('Excepción al iniciar stream de GPS: $e');
    }
  }

  /// Verifica si la unidad (prioridad vehículo anti-trampas o celular) ha entrado en la geocerca (< distAviso, ej 300m)
  /// y dispara registrarLlegada automáticamente
  void _checkAutoLlegada() {
    if (_isAutoLlegadaInProgress) return;

    final route = ref.read(routesProvider).findRoute(widget.idRuta);
    if (route == null || !route.isActiva) return;

    final config =
        ref.read(routesProvider).dayPackage?.config ?? const DayConfig();
    final double maxDistance =
        (config.distAviso > 0 ? config.distAviso : 300).toDouble();

    for (final stop in route.paradas) {
      if (!stop.isClientStop) continue;
      if (stop.visitada) continue;
      final client = stop.cliente;
      if (client == null || (client.lat == 0 && client.lng == 0)) continue;

      // Evitar re-disparar si ya se procesó o está en curso para esta parada
      if (_autoLlegadaTriggered.contains(stop.idParada)) continue;

      // Cálculo de distancia híbrido inteligente (prioridad vehículo anti-trampas)
      final dist = ref
          .read(routesProvider.notifier)
          .calculateDistanceMeters(client.lat, client.lng);

      if (dist != null && dist <= maxDistance) {
        _autoLlegadaTriggered.add(stop.idParada);
        _triggerAutoLlegada(route, stop, client, dist);
        break; // Procesar una sola parada a la vez
      }
    }
  }

  Future<void> _triggerAutoLlegada(
    DriverRoute route,
    RouteStop stop,
    RouteClient client,
    double dist,
  ) async {
    _isAutoLlegadaInProgress = true;
    try {
      await ref.read(routesProvider.notifier).registrarLlegada(
            idRuta: route.idRuta,
            idParada: stop.idParada,
          );
      if (!mounted) return;
      ref.read(routesProvider.notifier).clearRecentNotices();
      final distText = dist >= 1000
          ? '${(dist / 1000).toStringAsFixed(1)} km'
          : '${dist.round()} m';
      SnackbarTop.showSuccess(
        context,
        'Llegaste a $distText de ${client.nombre}',
        title: '¡Llegaste!',
        style: SnackbarTopStyle.appleCard,
      );
    } catch (e) {
      debugPrint('Error en registro automático de llegada: $e');
      _autoLlegadaTriggered.remove(stop.idParada);
    } finally {
      _isAutoLlegadaInProgress = false;
    }
  }

  Future<void> _toggleLocationTracking() async {
    if (_isTrackingLocation) {
      _stopLocationTracking();
      return;
    }

    setState(() {
      _isTrackingLocation = true;
      _isTrackingVehicle = false;
    });

    final lastPos = ref.read(routesProvider).lastKnownPosition;
    if (lastPos != null) {
      _animateCameraToPosition(lastPos);
    } else {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 4),
        );
        if (mounted) {
          ref.read(routesProvider.notifier).updatePosition(pos);
          _animateCameraToPosition(pos);
        }
      } catch (_) {}
    }
  }

  Future<void> _toggleVehicleTracking(DriverRoute route) async {
    if (_isTrackingVehicle) {
      _stopVehicleTracking();
      return;
    }

    final vehicId = route.vehiculo?.id;
    if (vehicId == null || vehicId <= 0) {
      SnackbarTop.showInfo(
        context,
        'Esta ruta no tiene un vehículo asignado con telemetría',
        title: 'Vehículo no asignado',
      );
      return;
    }

    setState(() {
      _isTrackingVehicle = true;
      _isTrackingLocation = false;
    });

    if (_vehicleLocation != null) {
      _animateCameraToLatLng(_vehicleLocation!);
    }

    _startVehicleTrackingTimer(vehicId);
    await _fetchRouteVehicleTelemetry(vehicId);
    if (mounted && _isTrackingVehicle && _vehicleLocation != null) {
      _animateCameraToLatLng(_vehicleLocation!);
    }
  }

  Future<void> _animateCameraToLatLng(LatLng target,
      {double defaultZoom = 16.5}) async {
    final ctrl = _mapController;
    if (ctrl == null) return;
    try {
      final currentZoom = await ctrl.getZoomLevel();
      final effectiveZoom = (currentZoom < 14.0) ? defaultZoom : currentZoom;
      ctrl.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: effectiveZoom,
          ),
        ),
      );
    } catch (_) {
      ctrl.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: defaultZoom,
          ),
        ),
      );
    }
  }

  void _animateCameraToPosition(Position position) {
    _animateCameraToLatLng(LatLng(position.latitude, position.longitude));
  }

  void _stopLocationTracking() {
    if (mounted && _isTrackingLocation) {
      setState(() {
        _isTrackingLocation = false;
      });
    }
  }

  void _stopVehicleTracking() {
    if (mounted && _isTrackingVehicle) {
      setState(() {
        _isTrackingVehicle = false;
      });
    }
  }

  /// Abre pantallas secundarias bloqueadas estrictamente en vertical
  /// y restaura la orientación horizontal/vertical al regresar al mapa/detalle.
  Future<T?> _pushLockedPortrait<T>(Widget page) async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    if (!mounted) return null;
    final result = await Navigator.of(context).push<T>(
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    return result;
  }

  void _fitMapToRoute(DriverRoute route) {
    if (_isTrackingLocation) {
      _stopLocationTracking();
    }
    if (_isTrackingVehicle) {
      _stopVehicleTracking();
    }
    final ctrl = _mapController;
    if (ctrl == null) return;

    final points = <LatLng>[];

    // 1. Coordenadas de todas las paradas
    for (final s in route.paradas) {
      if (s.stopLat != null &&
          s.stopLng != null &&
          (s.stopLat != 0 || s.stopLng != 0)) {
        points.add(LatLng(s.stopLat!, s.stopLng!));
      }
    }

    // 2. Coordenadas de CEDI
    if (route.cedi != null && (route.cedi!.lat != 0 || route.cedi!.lng != 0)) {
      points.add(LatLng(route.cedi!.lat, route.cedi!.lng));
    }

    // 3. Límites de geometría
    final geoBounds = route.geometria?.limites?.toLatLngBounds();
    if (geoBounds != null) {
      points.add(geoBounds.southwest);
      points.add(geoBounds.northeast);
    }

    if (points.length >= 2) {
      double minLat = points.first.latitude;
      double maxLat = points.first.latitude;
      double minLng = points.first.longitude;
      double maxLng = points.first.longitude;
      for (final p in points) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      ctrl.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          24,
        ),
      );
    } else if (points.length == 1) {
      ctrl.animateCamera(CameraUpdate.newLatLngZoom(points.first, 14.5));
    }
  }

  /// Construye las polilíneas del mapa según la sugerencia de la Ronda 29:
  /// "dibujar primero la línea completa en un color tenue y, conforme el chofer cierra paradas,
  /// resaltar el tramo que falta. Para eso basta con cortar la polilínea decodificada en el punto más cercano a la última parada cerrada."
  Set<Polyline> _buildPolylines(DriverRoute route) {
    final decoded = route.geometria?.decodePolyline() ?? const [];
    if (decoded.length < 2) return const {};

    // Buscar la última parada visitada con coordenadas
    LatLng? lastVisitedCoord;
    for (final s in route.paradas) {
      if (s.visitada &&
          s.stopLat != null &&
          s.stopLng != null &&
          (s.stopLat != 0 || s.stopLng != 0)) {
        lastVisitedCoord = LatLng(s.stopLat!, s.stopLng!);
      }
    }

    int splitIndex = 0;
    if (lastVisitedCoord != null) {
      double bestDist = double.infinity;
      for (int i = 0; i < decoded.length; i++) {
        final dLat = decoded[i].latitude - lastVisitedCoord.latitude;
        final dLng = decoded[i].longitude - lastVisitedCoord.longitude;
        final d2 = (dLat * dLat) + (dLng * dLng);
        if (d2 < bestDist) {
          bestDist = d2;
          splitIndex = i;
        }
      }
    }

    final Set<Polyline> polylines = {
      Polyline(
        polylineId: const PolylineId('full_route_dimmed'),
        points: decoded,
        width: 5,
        color: const Color(0xFF94A3B8),
      ),
    };

    final remainingPoints = decoded.sublist(splitIndex);
    if (remainingPoints.length >= 2) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('remaining_route_active'),
          points: remainingPoints,
          width: 6,
          color: const Color(0xFF0284C7),
        ),
      );
    }

    return polylines;
  }

  static final Map<String, BitmapDescriptor> _numberedMarkerCache = {};
  bool _isPreloadingMarkers = false;

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
    canvas.drawShadow(pinPath, Colors.black.withOpacity(0.38), 5.0, true);

    // Fondo del pin con el color correspondiente (Verde visitada / Azul pendiente)
    final Paint pinPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, pinPaint);

    // Borde blanco exterior
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(pinPath, borderPaint);

    // Círculo blanco interior para el número
    final Paint innerCirclePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r * 0.72, innerCirclePaint);

    // Texto con el número de parada (1, 2, 3...)
    final double fontSize =
        text.length >= 3 ? 14.0 : (text.length == 2 ? 18.0 : 22.0);

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(
          width.toInt(),
          height.toInt(),
        );
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      return BitmapDescriptor.defaultMarker;
    }
    return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
  }

  Future<void> _preloadNumberedMarkers(DriverRoute route) async {
    if (_isPreloadingMarkers) return;
    _isPreloadingMarkers = true;
    try {
      final futures = <Future<void>>[];

      // CEDI
      if (route.cedi != null &&
          (route.cedi!.lat != 0 || route.cedi!.lng != 0)) {
        const cediKey = 'CEDI_${0xFF7C3AED}';
        if (!_numberedMarkerCache.containsKey(cediKey)) {
          futures.add(() async {
            final icon = await _drawNumberedMarker(
              text: 'C',
              color: const Color(0xFF7C3AED),
            );
            _numberedMarkerCache[cediKey] = icon;
          }());
        }
      }

      // Paradas
      for (final stop in route.paradas) {
        Color color;
        if (stop.isRecargaStop) {
          color = const Color(0xFFEA580C);
        } else if (stop.isCombustibleStop) {
          color = const Color(0xFFD97706);
        } else if (stop.visitada) {
          color = const Color(0xFF059669);
        } else {
          color = const Color(0xFF0284C7);
        }

        final text = '${stop.orden}';
        final key = '${text}_${color.value}';

        if (!_numberedMarkerCache.containsKey(key)) {
          futures.add(() async {
            final icon = await _drawNumberedMarker(
              text: text,
              color: color,
            );
            _numberedMarkerCache[key] = icon;
          }());
        }
      }

      if (futures.isNotEmpty) {
        await Future.wait(futures);
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error generando marcadores numerados: $e');
    } finally {
      _isPreloadingMarkers = false;
    }
  }

  Set<Marker> _buildMarkers(DriverRoute route) {
    final Set<Marker> markers = {};
    bool missingAny = false;

    // 1. Iniciar sondeo de telemetría del vehículo asignado a la ruta
    if (route.vehiculo != null && route.vehiculo!.id > 0) {
      _startVehicleTrackingTimer(route.vehiculo!.id);
    }

    // 2. Marcador del Vehículo en el mapa (Top-down 360°, Verde Esmeralda de alta visibilidad)
    if (_vehicleLocation != null && route.vehiculo != null) {
      markers.add(
        Marker(
          markerId: MarkerId('route_vehicle_${route.vehiculo!.id}'),
          position: _vehicleLocation!,
          icon: _truckMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: _vehicleDirection,
          zIndex: 9,
          infoWindow: InfoWindow(
            title: '${route.vehiculo!.economico} (${route.vehiculo!.placas})',
            snippet: 'Vehículo de ruta',
          ),
        ),
      );
    }

    // 3. Marcador de Persona (Chofer) en reemplazo del punto azul
    final currentPos = ref.watch(routesProvider).lastKnownPosition;
    if (currentPos != null &&
        currentPos.latitude != 0.0 &&
        currentPos.longitude != 0.0) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver_person_marker'),
          position: LatLng(currentPos.latitude, currentPos.longitude),
          icon: _personMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          anchor: const Offset(0.5, 0.96),
          zIndex: 10,
          infoWindow: const InfoWindow(
            title: 'Mi ubicación',
            snippet: 'Chofer / Conductor',
          ),
        ),
      );
    }

    if (route.cedi != null && (route.cedi!.lat != 0 || route.cedi!.lng != 0)) {
      const cediKey = 'CEDI_${0xFF7C3AED}';
      final icon = _numberedMarkerCache[cediKey];
      if (icon == null) missingAny = true;

      markers.add(
        Marker(
          markerId: MarkerId('cedi_${route.cedi!.id}'),
          position: LatLng(route.cedi!.lat, route.cedi!.lng),
          icon: icon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet,
              ),
          anchor: const Offset(0.5, 0.94),
          infoWindow: InfoWindow(
            title: 'CEDI: ${route.cedi!.nombre}',
            snippet: 'Centro de distribución',
          ),
        ),
      );
    }

    for (final stop in route.paradas) {
      double? lat = stop.cliente?.lat;
      double? lng = stop.cliente?.lng;
      String title = stop.cliente != null
          ? '#${stop.orden} · ${stop.cliente!.nombre}'
          : '';
      String snippet = stop.llegadaEstimada.isNotEmpty
          ? 'Est: ${stop.llegadaEstimada} · ${stop.visitada ? "Visitada" : "Pendiente"}'
          : (stop.visitada ? 'Visitada' : 'Pendiente');

      Color color;
      if (stop.isRecargaStop &&
          stop.recarga != null &&
          (stop.recarga!.lat != 0 || stop.recarga!.lng != 0)) {
        lat = stop.recarga!.lat;
        lng = stop.recarga!.lng;
        title = '#${stop.orden} · Recarga: ${stop.recarga!.nombre}';
        snippet = stop.llegadaEstimada.isNotEmpty
            ? 'Est: ${stop.llegadaEstimada} · Carga de producto'
            : 'Carga de producto';
        color = const Color(0xFFEA580C);
      } else if (stop.isCombustibleStop &&
          stop.combustible != null &&
          (stop.combustible!.lat != 0 || stop.combustible!.lng != 0)) {
        lat = stop.combustible!.lat;
        lng = stop.combustible!.lng;
        title = '#${stop.orden} · Combustible: ${stop.combustible!.nombre}';
        snippet = stop.llegadaEstimada.isNotEmpty
            ? 'Est: ${stop.llegadaEstimada} · Estación de combustible'
            : 'Estación de combustible';
        color = const Color(0xFFD97706);
      } else {
        color =
            stop.visitada ? const Color(0xFF059669) : const Color(0xFF0284C7);
      }

      if (lat == null || (lat == 0 && (lng == null || lng == 0))) continue;

      final text = '${stop.orden}';
      final key = '${text}_${color.value}';
      final icon = _numberedMarkerCache[key];
      if (icon == null) {
        missingAny = true;
      }

      markers.add(
        Marker(
          markerId: MarkerId('stop_${stop.idParada}'),
          position: LatLng(lat, lng!),
          icon: icon ??
              BitmapDescriptor.defaultMarkerWithHue(
                stop.visitada
                    ? BitmapDescriptor.hueGreen
                    : BitmapDescriptor.hueAzure,
              ),
          anchor: const Offset(0.5, 0.94),
          infoWindow: InfoWindow(
            title: title,
            snippet: snippet,
          ),
        ),
      );
    }

    if (missingAny && !_isPreloadingMarkers) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _preloadNumberedMarkers(route);
      });
    }

    return markers;
  }

  BuildContext? _loadingDialogContext;

  void _showAppleLoadingDialog({
    required String title,
    required String subtitle,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.25),
      builder: (ctx) {
        _loadingDialogContext = ctx;
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LoadingAnimationWidget.threeRotatingDots(
                  color: const Color(0xFF0284C7),
                  size: 30,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _dismissAppleLoadingDialog() {
    if (_loadingDialogContext != null) {
      if (Navigator.canPop(_loadingDialogContext!)) {
        Navigator.pop(_loadingDialogContext!);
      }
      _loadingDialogContext = null;
    }
  }

  Future<void> _handleSalida(DriverRoute route) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final mediaQuery = MediaQuery.of(ctx);
        final isLandscape = mediaQuery.orientation == Orientation.landscape;
        final screenHeight = mediaQuery.size.height;

        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          insetPadding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: isLandscape ? 12 : 24,
          ),
          titlePadding: EdgeInsets.fromLTRB(
            20,
            isLandscape ? 14 : 20,
            20,
            isLandscape ? 6 : 10,
          ),
          contentPadding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            isLandscape ? 10 : 16,
          ),
          actionsPadding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            isLandscape ? 10 : 16,
          ),
          title: const Row(
            children: [
              Icon(
                Icons.directions_car_filled_rounded,
                color: Color(0xFF0284C7),
                size: 22,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Confirmar salida',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: isLandscape ? screenHeight * 0.45 : double.infinity,
            ),
            child: const SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Text(
                '¿Confirmas que ya saliste del CEDI a ruta?\n\n'
                'Esta hora quedará registrada oficialmente como tu hora oficial de salida e iniciará el seguimiento del vigilante.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 38),
              ),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Aún en CEDI',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 38),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Sí, ya salí del CEDI',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    setState(() => _isExecutingRouteAction = true);
    _showAppleLoadingDialog(
      title: 'Iniciando ruta...',
      subtitle: 'Registrando salida y posición GPS con el servidor',
    );
    try {
      final res =
          await ref.read(routesProvider.notifier).registrarSalida(route.idRuta);
      _dismissAppleLoadingDialog();
      if (!mounted) return;
      ref.read(routesProvider.notifier).clearRecentNotices();
      final msg = res.avisos.isNotEmpty
          ? res.avisos.map((a) => a.displayTexto).join('\n')
          : 'Ruta iniciada correctamente.';
      SnackbarTop.showSuccess(
        context,
        msg,
        title: 'Correcto',
      );
    } catch (e) {
      _dismissAppleLoadingDialog();
      if (!mounted) return;
      SnackbarTop.showError(
        context,
        'No se pudo iniciar la ruta: $e',
        title: 'Error de salida',
        style: SnackbarTopStyle.appleCard,
      );
    } finally {
      if (mounted) setState(() => _isExecutingRouteAction = false);
    }
  }

  Future<void> _handleFinRuta(
    DriverRoute route, {
    bool confirmarDiferencia = false,
  }) async {
    // Si es la primera solicitud (no reintento por diferencia de paquetes),
    // mostramos advertencia previa al chofer si aún tiene pendientes.
    if (!confirmarDiferencia) {
      int pendingStops = 0;
      int pendingDeliveries = 0;
      int pendingPickups = 0;

      for (final stop in route.paradas) {
        if (stop.tipo == 'inicio' || stop.tipo == 'fin') continue;
        if (!stop.visitada) pendingStops++;
        for (final g in stop.entregar) {
          if (g.estado != 4 && g.estado != 8) pendingDeliveries++;
        }
        for (final g in stop.recoger) {
          if (g.estado == 0) pendingPickups++;
        }
      }

      final hasPendingWork =
          pendingStops > 0 || pendingDeliveries > 0 || pendingPickups > 0;

      final confirmEnd = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final mediaQuery = MediaQuery.of(ctx);
          final isLandscape = mediaQuery.orientation == Orientation.landscape;
          final screenHeight = mediaQuery.size.height;

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            insetPadding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: isLandscape ? 12 : 24,
            ),
            titlePadding: EdgeInsets.fromLTRB(
              20,
              isLandscape ? 14 : 20,
              20,
              isLandscape ? 6 : 10,
            ),
            contentPadding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              isLandscape ? 8 : 12,
            ),
            actionsPadding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              isLandscape ? 10 : 16,
            ),
            title: Row(
              children: [
                Icon(
                  hasPendingWork
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  color: hasPendingWork
                      ? const Color(0xFFD97706)
                      : const Color(0xFF059669),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasPendingWork
                        ? '¿Terminar ruta con pendientes?'
                        : '¿Terminar ruta?',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 440,
                maxHeight: isLandscape ? screenHeight * 0.48 : double.infinity,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasPendingWork) ...[
                      const Text(
                        '¿Estás seguro de que deseas terminar la ruta? Aún tienes trabajo pendiente:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (pendingStops > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  '• $pendingStops parada(s) sin visitar',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            if (pendingDeliveries > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  '• $pendingDeliveries paquete(s) por entregar',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            if (pendingPickups > 0)
                              Text(
                                '• $pendingPickups paquete(s) por recoger',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Las paradas que no hayas visitado quedarán registradas automáticamente como no atendidas.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Has completado todas las paradas de esta ruta. ¿Deseas dar por finalizada la jornada de esta ruta?',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 38),
                ),
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasPendingWork
                      ? const Color(0xFFD97706)
                      : const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 38),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  hasPendingWork ? 'Sí, Terminar Ruta' : 'Finalizar Ruta',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (confirmEnd != true) {
        return;
      }
    }

    setState(() => _isExecutingRouteAction = true);
    _showAppleLoadingDialog(
      title: 'Finalizando ruta...',
      subtitle: 'Comprobando paquetes y reportando al CEDI',
    );
    try {
      final res = await ref.read(routesProvider.notifier).registrarFinRuta(
            idRuta: route.idRuta,
            confirmarDiferencia: confirmarDiferencia,
          );
      _dismissAppleLoadingDialog();
      if (!mounted) return;

      // Regla: "Fin de ruta: si el chofer aún trae paquetes el servidor contesta PENDIENTES con los folios.
      // La app muestra la lista; si el chofer confirma, reenvía con confirmarDiferencia: true y uuid nuevo."
      if (res.needsConfirmDifference && !confirmarDiferencia) {
        final msg = res.avisos.map((a) => a.texto).join('\n');
        final bool isVisitasPendientes = res.hasVisitasPendientes ||
            res.avisos.any((a) =>
                a.codigo == 'VISITAS_PENDIENTES' || a.codigo == 'NO_VISITADAS');

        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final mediaQuery = MediaQuery.of(ctx);
            final isLandscape = mediaQuery.orientation == Orientation.landscape;
            final screenHeight = mediaQuery.size.height;

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              insetPadding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: isLandscape ? 12 : 24,
              ),
              titlePadding: EdgeInsets.fromLTRB(
                20,
                isLandscape ? 14 : 20,
                20,
                isLandscape ? 6 : 10,
              ),
              contentPadding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                isLandscape ? 8 : 12,
              ),
              actionsPadding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                isLandscape ? 10 : 16,
              ),
              title: Text(
                isVisitasPendientes
                    ? 'Visitas pendientes de resultado'
                    : 'Paquetes pendientes en CEDI',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 440,
                  maxHeight:
                      isLandscape ? screenHeight * 0.45 : double.infinity,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    isVisitasPendientes
                        ? '$msg\n\nTienes paradas con llegada pero sin resultado de visita registrado.\nSi cierras la ruta ahora, quedarán marcadas como incidencia (Motivo 39).\n\n¿Deseas regresar a registrarlas o confirmar cierre con visitas pendientes?'
                        : (msg.isNotEmpty
                            ? '$msg\n\n¿Desea ir al CEDI a descargarlos o confirmar terminar la ruta con paquetes pendientes?'
                            : 'Aún existen paquetes sin descargar en el CEDI. ¿Desea confirmar el fin de ruta?'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 38),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text(
                    'Ir a CEDI / Revisar',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 38),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text(
                    'Confirmar y Terminar',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            );
          },
        );
        if (confirm == true && mounted) {
          await _handleFinRuta(route, confirmarDiferencia: true);
        }
        return;
      }

      ref.read(routesProvider.notifier).clearRecentNotices();
      final msg = res.avisos.isNotEmpty
          ? res.avisos.map((a) => a.displayTexto).join('\n')
          : 'Ruta cerrada correctamente.';
      SnackbarTop.showSuccess(
        context,
        msg,
        title: 'Correcto',
      );
    } catch (e) {
      _dismissAppleLoadingDialog();
      if (!mounted) return;
      SnackbarTop.showError(
        context,
        'No se pudo terminar la ruta: $e',
        title: 'Error de fin de ruta',
        style: SnackbarTopStyle.appleCard,
      );
    } finally {
      if (mounted) setState(() => _isExecutingRouteAction = false);
    }
  }

  Future<void> _launchPhoneCall(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  static const String _kNavDefaultAppKey = 'nav_default_app';
  static const String _kNavLastSelectedKey = 'nav_last_selected';
  static const String _kNavCountKey = 'nav_consecutive_count';

  Future<void> _launchNavigation(RouteClient client,
      {bool forceChooser = false}) async {
    await _handleNavigation(
      lat: client.lat,
      lng: client.lng,
      label: client.nombre,
      address: client.direccion,
      forceChooser: forceChooser,
    );
  }

  Future<void> _launchNavigationCoords(double lat, double lng,
      [String label = '', bool forceChooser = false]) async {
    await _handleNavigation(
      lat: lat,
      lng: lng,
      label: label.isNotEmpty ? label : 'Punto de ruta',
      forceChooser: forceChooser,
    );
  }

  Future<void> _handleNavigation({
    required double lat,
    required double lng,
    required String label,
    String address = '',
    bool forceChooser = false,
  }) async {
    if (!forceChooser) {
      final prefs = await SharedPreferences.getInstance();
      final defaultApp = prefs.getString(_kNavDefaultAppKey);
      if (defaultApp != null && defaultApp.isNotEmpty) {
        // App predeterminada activa: abrimos de inmediato sin mostrar el selector
        await _executeNavigationApp(
          app: defaultApp,
          lat: lat,
          lng: lng,
          label: label,
          address: address,
        );
        return;
      }
    }

    if (!mounted) return;
    await _showNavigationChooser(
      context: context,
      lat: lat,
      lng: lng,
      label: label,
      address: address,
    );
  }

  Future<void> _onNavigationAppChosen({
    required BuildContext context,
    required String app,
    required double lat,
    required double lng,
    required String label,
    String address = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (app == 'system') {
      // Al elegir "Detectar con mi celular", se fija como predeterminado
      // para que en las siguientes pulsaciones de "Ir" no vuelva a salir el modal.
      await prefs.setString(_kNavDefaultAppKey, 'system');
      if (context.mounted) {
        SnackbarTop.showInfo(
          context,
          'Selector del dispositivo fijado como predeterminado.',
          title: 'Navegación',
        );
      }
    } else {
      // Si es Google Maps o Waze:
      final lastSelected = prefs.getString(_kNavLastSelectedKey);
      final count = prefs.getInt(_kNavCountKey) ?? 0;

      if (lastSelected == app) {
        final newCount = count + 1;
        await prefs.setInt(_kNavCountKey, newCount);
        if (newCount >= 2) {
          // Si se seleccionó 2 veces consecutivas, se establece como la app predeterminada!
          await prefs.setString(_kNavDefaultAppKey, app);
          final appName = app == 'waze' ? 'Waze' : 'Google Maps';
          if (context.mounted) {
            SnackbarTop.showSuccess(
              context,
              '¡$appName fijado como tu app predeterminada!',
              title: 'Navegación predeterminada',
            );
          }
        }
      } else {
        // Nueva selección: registrar como última seleccionada y reiniciar contador
        await prefs.setString(_kNavLastSelectedKey, app);
        await prefs.setInt(_kNavCountKey, 1);
      }
    }

    await _executeNavigationApp(
      app: app,
      lat: lat,
      lng: lng,
      label: label,
      address: address,
    );
  }

  Future<void> _executeNavigationApp({
    required String app,
    required double lat,
    required double lng,
    required String label,
    String address = '',
  }) async {
    if (app == 'maps') {
      Uri uri;
      if (lat != 0 || lng != 0) {
        uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
        );
      } else {
        uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address.isNotEmpty ? address : label)}',
        );
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (app == 'waze') {
      Uri wazeUri;
      if (lat != 0 || lng != 0) {
        wazeUri = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
      } else {
        wazeUri = Uri.parse(
          'waze://?q=${Uri.encodeComponent(address.isNotEmpty ? address : label)}&navigate=yes',
        );
      }
      if (await canLaunchUrl(wazeUri)) {
        await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
      } else {
        final wazeWeb = lat != 0 || lng != 0
            ? Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes')
            : Uri.parse(
                'https://waze.com/ul?q=${Uri.encodeComponent(address.isNotEmpty ? address : label)}&navigate=yes');
        await launchUrl(wazeWeb, mode: LaunchMode.externalApplication);
      }
    } else {
      // 'system'
      Uri geoUri;
      if (lat != 0 || lng != 0) {
        geoUri = Uri.parse(
          'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(label)})',
        );
      } else {
        geoUri = Uri.parse(
          'geo:0,0?q=${Uri.encodeComponent(address.isNotEmpty ? address : label)}',
        );
      }
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      } else {
        final fallback = lat != 0 || lng != 0
            ? Uri.parse(
                'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
              )
            : Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address.isNotEmpty ? address : label)}',
              );
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _showNavigationChooser({
    required BuildContext context,
    required double lat,
    required double lng,
    required String label,
    String address = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final currentDefault = prefs.getString(_kNavDefaultAppKey);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final mediaQuery = MediaQuery.of(ctx);
        final isLandscape = mediaQuery.orientation == Orientation.landscape;
        final screenHeight = mediaQuery.size.height;

        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight:
                  isLandscape ? screenHeight * 0.90 : screenHeight * 0.85,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    18,
                    isLandscape ? 10 : 16,
                    18,
                    isLandscape ? 16 : 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin:
                              EdgeInsets.only(bottom: isLandscape ? 10 : 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.navigation_rounded,
                              size: 20, color: Color(0xFF0284C7)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Navegar a $label',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          address,
                          style: const TextStyle(
                              fontSize: 11.5, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Indicador de app predeterminada actual si existe
                      if (currentDefault != null &&
                          currentDefault.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 15, color: Color(0xFF16A34A)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Predeterminada: ${currentDefault == "waze" ? "Waze" : "Google Maps"}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () async {
                                  await prefs.remove(_kNavDefaultAppKey);
                                  await prefs.remove(_kNavLastSelectedKey);
                                  await prefs.remove(_kNavCountKey);
                                  if (context.mounted) {
                                    Navigator.of(ctx).pop();
                                    SnackbarTop.showInfo(
                                      context,
                                      'Se restableció la app de navegación.',
                                      title: 'Navegación',
                                    );
                                  }
                                },
                                child: const Text(
                                  'Restablecer',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      const Text(
                        'Selecciona tu aplicación de navegación:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Si eliges la misma app 2 veces seguidas, se fijará como tu favorita automática.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Opción Google Maps
                          Expanded(
                            child: Material(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  _onNavigationAppChosen(
                                    context: context,
                                    app: 'maps',
                                    lat: lat,
                                    lng: lng,
                                    label: label,
                                    address: address,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: currentDefault == 'maps'
                                          ? const Color(0xFF0284C7)
                                          : const Color(0xFFE2E8F0),
                                      width: currentDefault == 'maps' ? 1.8 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.08),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                          border: Border.all(
                                              color: const Color(0xFFF1F5F9),
                                              width: 1.5),
                                        ),
                                        alignment: Alignment.center,
                                        child: ShaderMask(
                                          shaderCallback: (bounds) =>
                                              const SweepGradient(
                                            center: Alignment.center,
                                            colors: [
                                              Color(0xFF4285F4), // Azul Google
                                              Color(0xFFEA4335), // Rojo Google
                                              Color(
                                                  0xFFFBBC05), // Amarillo Google
                                              Color(0xFF34A853), // Verde Google
                                              Color(
                                                  0xFF4285F4), // Azul Google (cierre)
                                            ],
                                            stops: [0.0, 0.3, 0.6, 0.85, 1.0],
                                          ).createShader(bounds),
                                          child: const FaIcon(
                                            FontAwesomeIcons.google,
                                            size: 24,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Google Maps',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Opción Waze
                          Expanded(
                            child: Material(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  _onNavigationAppChosen(
                                    context: context,
                                    app: 'waze',
                                    lat: lat,
                                    lng: lng,
                                    label: label,
                                    address: address,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: currentDefault == 'waze'
                                          ? const Color(0xFF0284C7)
                                          : const Color(0xFFE2E8F0),
                                      width: currentDefault == 'waze' ? 1.8 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(
                                              0xFF33CCFF), // Celeste oficial Waze
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF33CCFF)
                                                  .withOpacity(0.4),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: const FaIcon(
                                          FontAwesomeIcons.waze,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Waze',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingRouteTopBar({
    required BuildContext context,
    required DriverRoute route,
    required bool isSmallScreen,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: _isTopBarCollapsed ? 6 : 10,
        vertical: _isTopBarCollapsed ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón Atrás: solo visible cuando no está embebido en split view de tablet
          if (!widget.isEmbedded) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () => Navigator.pop(context),
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
            if (!_isTopBarCollapsed) const SizedBox(width: 10),
            if (_isTopBarCollapsed) const SizedBox(width: 6),
          ],

          // Título y Estado de Ruta (se oculta al retraerse)
          if (!_isTopBarCollapsed) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    route.nombre,
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
                      FadeTransition(
                        opacity: _pulseController,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: route.isTerminada
                                ? const Color(0xFF64748B)
                                : (route.isActiva
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFD97706)),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${route.modalidadNombre} · ${route.visitedClientStops}/${route.totalClientStops} paradas',
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
          ],

          // Botón para retraer / expandir la barra
          if (!widget.isEmbedded)
            Material(
              color: Colors.transparent,
              child: Tooltip(
                message: _isTopBarCollapsed
                    ? 'Mostrar detalles de ruta'
                    : 'Ocultar detalles de ruta',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    setState(() {
                      _isTopBarCollapsed = !_isTopBarCollapsed;
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 17,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Chip flotante con la distancia y tiempo estimado del recorrido estilo Apple,
  /// con botón para cerrarlo/ocultarlo durante la sesión actual de la pantalla.
  Widget _buildJourneyEstimatesChip(DriverRoute route) {
    if (!_showJourneyEstimates ||
        route.geometria == null ||
        route.geometria!.distanciaM <= 0) {
      return const SizedBox.shrink();
    }

    final distKm = (route.geometria!.distanciaM / 1000).toStringAsFixed(1);
    final durMin = (route.geometria!.duracionS / 60).round();

    return Material(
      color: Colors.transparent,
      child: Container(
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
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _fitMapToRoute(route),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.route_rounded,
                        size: 13,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '$distKm km',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Text(
                      ' · ',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$durMin min est.',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 1,
              height: 14,
              color: const Color(0xFFE2E8F0),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: 'Ocultar estimación',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _showJourneyEstimates = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingRouteMapControls({
    required BuildContext context,
    required DriverRoute route,
  }) {
    if (!_showMapControls) return const SizedBox.shrink();

    return Container(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Botón Seguir / Centrar Vehículo (Verde Esmeralda)
          _buildMapControlButton(
            icon: _isTrackingVehicle
                ? Icons.local_shipping_rounded
                : Icons.local_shipping_outlined,
            tooltip: _isTrackingVehicle
                ? 'Siguiendo vehículo (Activo)'
                : 'Seguir vehículo',
            isActive: _isTrackingVehicle,
            activeColor: const Color(0xFF16A34A),
            iconColor: _isTrackingVehicle
                ? const Color(0xFF16A34A)
                : const Color(0xFF15803D),
            onTap: () => _toggleVehicleTracking(route),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // 2. Botón Seguir / Centrar GPS del Celular / Chofer (Azul Océano)
          _buildMapControlButton(
            icon: _isTrackingLocation
                ? Icons.person_pin_circle_rounded
                : Icons.person_pin_circle_outlined,
            tooltip: _isTrackingLocation
                ? 'Siguiendo GPS celular (Activo)'
                : 'Seguir GPS celular',
            isActive: _isTrackingLocation,
            activeColor: const Color(0xFF0284C7),
            iconColor: _isTrackingLocation
                ? const Color(0xFF0284C7)
                : const Color(0xFF0284C7),
            onTap: _toggleLocationTracking,
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // 3. Encuadrar recorrido completo
          _buildMapControlButton(
            icon: Icons.zoom_out_map_rounded,
            tooltip: 'Encuadrar recorrido',
            isActive: false,
            onTap: () => _fitMapToRoute(route),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // 4. Expandir / Reducir mapa
          _buildMapControlButton(
            icon: _mapExpanded
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            tooltip: _mapExpanded ? 'Reducir mapa' : 'Ampliar mapa',
            isActive: _mapExpanded,
            onTap: () {
              setState(() {
                _mapExpanded = !_mapExpanded;
              });
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
    Color? iconColor,
    Color? activeColor,
  }) {
    final effectiveColor = activeColor ?? const Color(0xFF0284C7);
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive
                  ? effectiveColor.withOpacity(0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isActive
                  ? effectiveColor
                  : (iconColor ?? const Color(0xFF334155)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingBottomControls({
    required BuildContext context,
    required DriverRoute route,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (route.isFinalizada) ...[
            Expanded(
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: route.isCerradaPorMotor
                      ? const Color(0xFFFFFBEB)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: route.isCerradaPorMotor
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFFBBF7D0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      route.isCerradaPorMotor
                          ? Icons.lock_clock_rounded
                          : Icons.check_circle_rounded,
                      size: 15,
                      color: route.isCerradaPorMotor
                          ? const Color(0xFFD97706)
                          : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      route.isCerradaPorMotor
                          ? 'Cerrada por motor'
                          : 'Ruta terminada',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: route.isCerradaPorMotor
                            ? const Color(0xFF92400E)
                            : const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (!route.isActiva) ...[
            Expanded(
              child: SizedBox(
                height: 38,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  onPressed: _isExecutingRouteAction
                      ? null
                      : () => _handleSalida(route),
                  child: _isExecutingRouteAction
                      ? Center(
                          child: LoadingAnimationWidget.threeRotatingDots(
                            color: Colors.white,
                            size: 20,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 18),
                            SizedBox(width: 5),
                            Text(
                              'Iniciar Ruta',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: SizedBox(
                height: 38,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  onPressed: _isExecutingRouteAction
                      ? null
                      : () => _handleFinRuta(route),
                  child: _isExecutingRouteAction
                      ? Center(
                          child: LoadingAnimationWidget.threeRotatingDots(
                            color: Colors.white,
                            size: 20,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.flag_rounded, size: 16),
                            SizedBox(width: 5),
                            Text(
                              'Terminar Ruta',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],

          // Botón CEDI (rutas de reparto)
          if (!route.isVisitRoute) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 38,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF0F9FF),
                  foregroundColor: const Color(0xFF0284C7),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFFBAE6FD), width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                onPressed: () {
                  _pushLockedPortrait(
                    CediOperationsPage(
                      idRuta: route.idRuta,
                      initialTab: route.cediCargar.isNotEmpty &&
                              route.cediDescargar.isEmpty
                          ? 1
                          : 0,
                    ),
                  );
                },
                icon: const Icon(Icons.warehouse_rounded,
                    size: 16, color: Color(0xFF0284C7)),
                label: const Text(
                  'CEDI',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],

          // Botón Fuera de Ruta (rutas de visita)
          if (route.isVisitRoute) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 38,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF0F9FF),
                  foregroundColor: const Color(0xFF0284C7),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFFBAE6FD), width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => Container(
                      height: MediaQuery.of(context).size.height * 0.82,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                              child: Column(
                                children: [
                                  Center(
                                    child: Container(
                                      width: 38,
                                      height: 4,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFCBD5E1),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Seleccionar Cliente (Visita fuera de ruta)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: OrdersAndNewClientsView(
                                visitRouteIdForOutOfRoute: route.idRuta,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add_business_rounded,
                    size: 15, color: Color(0xFF0284C7)),
                label: const Text(
                  'Fuera de Ruta',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Layout horizontal / tablet: lista de paradas a la izquierda y mapa interactivo a la derecha.
  Widget _buildLandscapeLayout({
    required BuildContext context,
    required DriverRoute route,
    required DayConfig config,
    required LatLng initialCenter,
    required MediaQueryData mediaQuery,
  }) {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── PANEL IZQUIERDO: Rutas, Inicio, Clientes, Paradas ──
              SizedBox(
                width: (mediaQuery.size.width * 0.46).clamp(340.0, 520.0),
                child: Column(
                  children: [
                    // Barra superior con botón atrás, título y estado de conexión
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        mediaQuery.padding.left + 10,
                        mediaQuery.padding.top + 8,
                        10,
                        8,
                      ),
                      child: _buildFloatingRouteTopBar(
                        context: context,
                        route: route,
                        isSmallScreen: false,
                      ),
                    ),

                    // Lista de paradas de la ruta (Inicio, Clientes, Descanso, Fin)
                    Expanded(
                      child: RefreshIndicator(
                        color: const Color(0xFF0284C7),
                        onRefresh: () async {
                          await ref
                              .read(routesProvider.notifier)
                              .syncPendingQueueAndRefreshDay(
                                forceRefreshDay: true,
                                isUserInitiated: true,
                              );
                        },
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            mediaQuery.padding.left + 10,
                            4,
                            10,
                            16,
                          ),
                          itemCount: route.paradas.length,
                          itemBuilder: (context, index) {
                            final stop = route.paradas[index];
                            final isLast = index == route.paradas.length - 1;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildStopCard(
                                  route,
                                  stop,
                                  config,
                                ),
                                if (!isLast)
                                  _buildTimelineConnectorBetweenCards(),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Divisor vertical
              Container(
                width: 1,
                color: const Color(0xFFE2E8F0),
              ),

              // ── PANEL DERECHO: Mapa interactivo a toda altura con controles ──
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: initialCenter,
                          zoom: 12,
                        ),
                        padding: EdgeInsets.only(
                          top: mediaQuery.padding.top + 54,
                          right: 56,
                          bottom: 64,
                          left: 14,
                        ),
                        mapType: _mapType,
                        trafficEnabled: _showTraffic,
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        polylines: _buildPolylines(route),
                        markers: _buildMarkers(route),
                        onMapCreated: (ctrl) {
                          _mapController = ctrl;
                          _preloadNumberedMarkers(route);
                          Future.delayed(const Duration(milliseconds: 350), () {
                            if (mounted) _fitMapToRoute(route);
                          });
                        },
                      ),
                    ),

                    // Chip flotante de distancia y tiempo (esquina superior izquierda del mapa)
                    if (_showJourneyEstimates &&
                        route.geometria != null &&
                        route.geometria!.distanciaM > 0)
                      Positioned(
                        top: mediaQuery.padding.top + 8,
                        left: 12,
                        child: _buildJourneyEstimatesChip(route),
                      ),

                    // Controles flotantes del mapa (capas, tráfico, centrar)
                    // En modo horizontal los centramos verticalmente en el lateral derecho
                    if (_showMapControls)
                      Positioned(
                        right: 12,
                        top: 0,
                        bottom: 64,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _buildFloatingRouteMapControls(
                            context: context,
                            route: route,
                          ),
                        ),
                      ),

                    // Controles inferiores flotantes (Iniciar / Terminar ruta, CEDI)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: _buildFloatingBottomControls(
                        context: context,
                        route: route,
                        isSmallScreen: false,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Barra de estado de cola sin conexión y sincronización
        const DriverSyncStatusBar(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routesProvider);
    final route = state.findRoute(widget.idRuta);
    final config = state.dayPackage?.config ?? const DayConfig();

    if (route == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ruta')),
        body: const Center(child: Text('Ruta no disponible.')),
      );
    }

    final initialCenter =
        route.cedi != null && (route.cedi!.lat != 0 || route.cedi!.lng != 0)
            ? LatLng(route.cedi!.lat, route.cedi!.lng)
            : const LatLng(19.4326, -99.1332);

    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isSmallScreen = mediaQuery.size.width < 360;
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isWide = isLandscape || mediaQuery.size.width >= 600;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: isWide
            ? _buildLandscapeLayout(
                context: context,
                route: route,
                config: config,
                initialCenter: initialCenter,
                mediaQuery: mediaQuery,
              )
            : Column(
                children: [
                  // 1. MAPA DEL RECORRIDO CON BARRA FLOTANTE Y CONTROLES (Estilo TrackingPage)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: _mapExpanded
                        ? MediaQuery.of(context).size.height * 0.74
                        : (MediaQuery.of(context).size.height * 0.40)
                            .clamp(280.0, 360.0),
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: initialCenter,
                              zoom: 12,
                            ),
                            padding: EdgeInsets.only(
                              top: mediaQuery.padding.top + 60,
                              right: 56,
                              bottom: 82,
                              left: 14,
                            ),
                            mapType: _mapType,
                            trafficEnabled: _showTraffic,
                            myLocationEnabled: false,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            polylines: _buildPolylines(route),
                            markers: _buildMarkers(route),
                            onMapCreated: (ctrl) {
                              _mapController = ctrl;
                              _preloadNumberedMarkers(route);
                              Future.delayed(const Duration(milliseconds: 350),
                                  () {
                                if (mounted) _fitMapToRoute(route);
                              });
                            },
                          ),
                        ),

                        // Barra Superior Flotante y Estimación de Recorrido estilo Apple
                        Positioned(
                          top: mediaQuery.padding.top + 8,
                          left: isSmallScreen ? 10 : 14,
                          right: _isTopBarCollapsed
                              ? null
                              : (isSmallScreen ? 10 : 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildFloatingRouteTopBar(
                                context: context,
                                route: route,
                                isSmallScreen: isSmallScreen,
                              ),
                              if (!_isTopBarCollapsed &&
                                  _showJourneyEstimates &&
                                  route.geometria != null &&
                                  route.geometria!.distanciaM > 0) ...[
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildJourneyEstimatesChip(route),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Controles Laterales Flotantes
                        if (_showMapControls)
                          Positioned(
                            right: isSmallScreen ? 8 : 12,
                            top: mediaQuery.padding.top + 68,
                            child: _buildFloatingRouteMapControls(
                              context: context,
                              route: route,
                            ),
                          ),

                        // Controles Inferiores Flotantes (Recorrido y Acciones Operativas)
                        Positioned(
                          left: isSmallScreen ? 10 : 14,
                          right: isSmallScreen ? 10 : 14,
                          bottom: 10,
                          child: _buildFloatingBottomControls(
                            context: context,
                            route: route,
                            isSmallScreen: isSmallScreen,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. LISTA DE PARADAS EN ORDEN (inicio, cliente, descanso, combustible, recarga, fin)
                  Expanded(
                    child: RefreshIndicator(
                      color: const Color(0xFF0284C7),
                      onRefresh: () async {
                        await ref
                            .read(routesProvider.notifier)
                            .syncPendingQueueAndRefreshDay(
                              forceRefreshDay: true,
                              isUserInitiated: true,
                            );
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        itemCount: route.paradas.length,
                        itemBuilder: (context, index) {
                          final stop = route.paradas[index];
                          final isLast = index == route.paradas.length - 1;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildStopCard(
                                route,
                                stop,
                                config,
                              ),
                              if (!isLast)
                                _buildTimelineConnectorBetweenCards(),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  // BARRA DE ESTADO DE COLA SIN CONEXIÓN Y SINCRONIZACIÓN (FOOTER INFERIOR DE RUTA)
                  const DriverSyncStatusBar(),
                ],
              ),
      ),
    );
  }

  Future<void> _confirmAndRegisterLlegada({
    required BuildContext context,
    required DriverRoute route,
    required RouteStop stop,
    required RouteClient client,
    required double? distMeters,
    required bool isFar,
    required String distanciaText,
  }) async {
    if (stop.visitada) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final mediaQuery = MediaQuery.of(ctx);
        final isLandscape = mediaQuery.orientation == Orientation.landscape;
        final screenHeight = mediaQuery.size.height;

        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 540,
              maxHeight:
                  isLandscape ? screenHeight * 0.92 : screenHeight * 0.85,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    isLandscape ? 10 : 16,
                    20,
                    isLandscape ? 14 : 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          margin:
                              EdgeInsets.only(bottom: isLandscape ? 10 : 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: isLandscape ? 36 : 42,
                            height: isLandscape ? 36 : 42,
                            decoration: BoxDecoration(
                              color: isFar
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFDCFCE7),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFar
                                  ? Icons.warning_amber_rounded
                                  : Icons.where_to_vote_rounded,
                              color: isFar
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF166534),
                              size: isLandscape ? 20 : 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '¿Confirmar llegada?',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  client.nombre,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isLandscape ? 10 : 14),

                      // Tarjeta de aviso de distancia
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: isLandscape ? 8 : 12,
                        ),
                        decoration: BoxDecoration(
                          color: isFar
                              ? const Color(0xFFFFFBEB)
                              : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isFar
                                ? const Color(0xFFFCD34D)
                                : const Color(0xFFBBF7D0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isFar
                                  ? Icons.info_outline_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 18,
                              color: isFar
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF15803D),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isFar
                                    ? 'Aviso: Tu GPS indica que aún estás a $distanciaText del cliente. ¿Confirmas que ya llegaste al punto?'
                                    : 'Confirmas que te encuentras en las instalaciones del cliente.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isFar
                                      ? const Color(0xFF92400E)
                                      : const Color(0xFF166534),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isLandscape ? 12 : 18),

                      // Botón Deslizable para Confirmar Llegada (Estilo Swipe como en MyInspectVehiclePage)
                      _SwipeToConfirmLlegadaButton(
                        label: 'Desliza para confirmar llegada',
                        themeColor: isFar
                            ? const Color(0xFFD97706)
                            : const Color(0xFF0F766E),
                        onConfirmed: () async {
                          Navigator.of(ctx).pop(true);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      _showAppleLoadingDialog(
        title: 'Registrando llegada...',
        subtitle: 'Validando ubicación con ${client.nombre}',
      );
      try {
        final res = await ref.read(routesProvider.notifier).registrarLlegada(
              idRuta: route.idRuta,
              idParada: stop.idParada,
            );
        _dismissAppleLoadingDialog();
        if (!mounted) return;
        ref.read(routesProvider.notifier).clearRecentNotices();
        final msg = res.avisos.isNotEmpty
            ? res.avisos.map((a) => a.displayTexto).join('\n')
            : 'Llegada a ${client.nombre} registrada.';
        SnackbarTop.showSuccess(
          context,
          msg,
          title: 'Correcto',
        );
      } catch (e) {
        _dismissAppleLoadingDialog();
        if (!mounted) return;
        SnackbarTop.showError(
          context,
          'No se pudo registrar la llegada: $e',
          title: 'Error de llegada',
          style: SnackbarTopStyle.appleCard,
        );
      }
    }
  }

  Widget _buildTimelineConnectorBetweenCards() {
    return SizedBox(
      height: 10,
      child: CustomPaint(
        painter: const _BetweenCardsConnectorPainter(
          circleCenterX: 23.0,
          lineColor: Color(0xFFCBD5E1),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildStopCard(
    DriverRoute route,
    RouteStop stop,
    DayConfig config,
  ) {
    if (!stop.isClientStop) {
      return _buildNonClientStopTile(
        route,
        stop,
      );
    }

    final client =
        stop.cliente ?? const RouteClient(id: 0, nombre: 'Cliente de parada');
    String direccionText = client.direccion.trim();
    if (direccionText.isEmpty &&
        stop.recarga != null &&
        stop.recarga!.nombre.isNotEmpty) {
      direccionText = stop.recarga!.nombre;
    }
    if (direccionText.isEmpty &&
        stop.combustible != null &&
        stop.combustible!.nombre.isNotEmpty) {
      direccionText = stop.combustible!.nombre;
    }
    final distMeters = ref
        .read(routesProvider.notifier)
        .calculateDistanceMeters(client.lat, client.lng);
    final isFar = distMeters != null && distMeters > config.distAviso;
    // La advertencia de fuera de rango solo aplica si el usuario la marcó desde la app (no si fue automática por GPS del camión)
    final bool isManualFarArrival = !stop.visitaCerrada &&
        stop.visitada &&
        stop.visitaOrigen != 'gps' &&
        isFar;
    final String distanciaText = distMeters != null
        ? (isFar
            ? (distMeters >= 1000
                ? '${(distMeters / 1000).toStringAsFixed(1)} km (> ${config.distAviso}m)'
                : '${distMeters.round()} m (> ${config.distAviso}m)')
            : 'En sitio (${distMeters.round()} m)')
        : '';

    final bool isCompleted = _isStopCompleted(stop);
    final bool isExpanded =
        _stopExpandedOverride[stop.idParada] ?? !isCompleted;

    if (!isExpanded) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                _stopExpandedOverride[stop.idParada] = true;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${stop.orden}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          client.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (direccionText.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            direccionText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCompleted) ...[
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 12,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              isCompleted
                                  ? (stop.entregar.isNotEmpty
                                      ? '${stop.entregar.length} paquete(s) entregado(s)'
                                      : (stop.recoger.isNotEmpty
                                          ? '${stop.recoger.length} paquete(s) recogido(s)'
                                          : 'Parada completada'))
                                  : (stop.entregar.isNotEmpty
                                      ? '${stop.entregar.length} paquete(s) por entregar'
                                      : (stop.recoger.isNotEmpty
                                          ? '${stop.recoger.length} paquete(s) por recoger'
                                          : 'Pendiente de visita')),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isCompleted
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (stop.unsyncedLocal) ...[
                    const SizedBox(width: 4),
                    const Tooltip(
                      message: 'Pendiente de sincronizar con el servidor',
                      child: Icon(
                        Icons.cloud_upload_rounded,
                        size: 14,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ],
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado de Parada
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text(
                      '${stop.orden}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.nombre,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (direccionText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1.5, right: 3),
                              child: Icon(
                                Icons.place_outlined,
                                size: 12,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                direccionText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (client.contacto.isNotEmpty ||
                          client.telefono.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${client.contacto} ${client.telefono}'.trim(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (stop.unsyncedLocal) ...[
                          const Tooltip(
                            message: 'Pendiente de sincronizar con el servidor',
                            child: Icon(
                              Icons.cloud_upload_rounded,
                              size: 14,
                              color: Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (stop.llegadaEstimada.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              stop.llegadaEstimada,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        const SizedBox(width: 2),
                        IconButton(
                          icon: const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Colapsar tarjeta',
                          onPressed: () {
                            setState(() {
                              _stopExpandedOverride[stop.idParada] = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            // Fila de Estado y Acciones Rápidas
            const SizedBox(height: 9),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!stop.visitada) ...[
                        // Alerta de distancia arriba y teléfono (solo antes de llegar)
                        Row(
                          children: [
                            if (distMeters != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: isFar
                                      ? const Color(0xFFFFF7ED)
                                      : const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: isFar
                                        ? const Color(0xFFFED7AA)
                                        : const Color(0xFFBBF7D0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isFar
                                          ? Icons.warning_amber_rounded
                                          : Icons.near_me_rounded,
                                      size: 13,
                                      color: isFar
                                          ? const Color(0xFFEA580C)
                                          : const Color(0xFF16A34A),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      distanciaText,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: isFar
                                            ? const Color(0xFFC2410C)
                                            : const Color(0xFF15803D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (client.telefono.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              IconButton.filledTonal(
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(28, 28),
                                  padding: EdgeInsets.zero,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () =>
                                    _launchPhoneCall(client.telefono),
                                icon: const Icon(Icons.phone_rounded,
                                    size: 14, color: Color(0xFF334155)),
                                tooltip: 'Llamar a ${client.telefono}',
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Botón Marcar Llegada estilo Apple
                        SizedBox(
                          width: double.infinity,
                          height: 34,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            onPressed: () => _confirmAndRegisterLlegada(
                              context: context,
                              route: route,
                              stop: stop,
                              client: client,
                              distMeters: distMeters,
                              isFar: isFar,
                              distanciaText: distanciaText,
                            ),
                            icon: const Icon(Icons.location_on_rounded,
                                size: 15, color: Colors.white),
                            label: const Text(
                              'Marcar Llegada',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Ya llegó: chip de llegada confirmada (o advertencia si se marcó fuera de rango) + botón de llamada
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: stop.visitaCerrada
                                    ? const Color(0xFFECFDF5)
                                    : (isManualFarArrival
                                        ? const Color(0xFFFFFBEB)
                                        : const Color(0xFFECFDF5)),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: stop.visitaCerrada
                                      ? const Color(0xFFA7F3D0)
                                      : (isManualFarArrival
                                          ? const Color(0xFFFDE68A)
                                          : const Color(0xFFA7F3D0)),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    stop.visitaCerrada
                                        ? Icons.check_circle_rounded
                                        : (isManualFarArrival
                                            ? Icons.warning_amber_rounded
                                            : Icons.check_circle_rounded),
                                    size: 13,
                                    color: stop.visitaCerrada
                                        ? const Color(0xFF047857)
                                        : (isManualFarArrival
                                            ? const Color(0xFFB45309)
                                            : const Color(0xFF047857)),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    stop.visitaCerrada
                                        ? 'Visita concluida'
                                        : (isManualFarArrival
                                            ? 'Llegó a ${distMeters != null ? (distMeters >= 1000 ? "${(distMeters / 1000).toStringAsFixed(1)} km" : "${distMeters.round()} m") : ""} del destino'
                                            : 'Llegada registrada'),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: stop.visitaCerrada
                                          ? const Color(0xFF047857)
                                          : (isManualFarArrival
                                              ? const Color(0xFFB45309)
                                              : const Color(0xFF047857)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (client.telefono.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              IconButton.filledTonal(
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(28, 28),
                                  padding: EdgeInsets.zero,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () =>
                                    _launchPhoneCall(client.telefono),
                                icon: const Icon(Icons.phone_rounded,
                                    size: 14, color: Color(0xFF334155)),
                                tooltip: 'Llamar a ${client.telefono}',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Mostrar botón IR si no ha llegado, O si el usuario marcó llegada manualmente desde el teléfono pero está fuera de rango (> distAviso)
                if (!isCompleted &&
                    (!stop.visitada ||
                        (isManualFarArrival && !stop.visitaCerrada))) ...[
                  const SizedBox(width: 10),

                  // Botón Navegar ("IR") estilo Apple Squircle
                  Tooltip(
                    message:
                        'Ir con Maps o Waze (Mantén presionado para cambiar app)',
                    child: Material(
                      color: const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(12),
                      elevation: 0,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _launchNavigation(client),
                        onLongPress: () =>
                            _launchNavigation(client, forceChooser: true),
                        child: Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.navigation_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(height: 1),
                              Text(
                                'IR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // SECCIÓN DE GUÍAS / RECOJOS / VISITAS
            if (stop.recoger.isNotEmpty || stop.entregar.isNotEmpty) ...[
              const SizedBox(height: 9),
              if (stop.recoger.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.download_rounded,
                        size: 13, color: Color(0xFF0284C7)),
                    const SizedBox(width: 5),
                    const Text(
                      'PAQUETES POR RECOGER',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0284C7),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...stop.recoger.map(
                  (g) => _buildGuiaActionRow(
                    route: route,
                    stop: stop,
                    client: client,
                    guia: g,
                    isPickup: true,
                  ),
                ),
              ],
              if (stop.entregar.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      route.isVisitRoute
                          ? Icons.storefront_rounded
                          : Icons.upload_rounded,
                      size: 13,
                      color: const Color(0xFF059669),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      route.isVisitRoute
                          ? 'VISITA AL CLIENTE'
                          : 'PAQUETES POR ENTREGAR',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...stop.entregar.map(
                  (g) => _buildGuiaActionRow(
                    route: route,
                    stop: stop,
                    client: client,
                    guia: g,
                    isPickup: false,
                  ),
                ),
              ],
            ],

            // Si es ruta de visitas y el arreglo entregar[] viniera vacío, permitir atender visita igual
            if (route.isVisitRoute && stop.entregar.isEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 34,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  onPressed: () {
                    _pushLockedPortrait(
                      VisitRecordPage(
                        idRuta: route.idRuta,
                        idParada: stop.idParada,
                        client: client,
                      ),
                    );
                  },
                  icon: const Icon(Icons.storefront_rounded, size: 15),
                  label: const Text(
                    'Atender Visita',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNonClientStopTile(
    DriverRoute route,
    RouteStop stop,
  ) {
    IconData icon = Icons.place_rounded;
    Color iconColor = const Color(0xFF475569);
    Color bgTint = const Color(0xFFF8FAFC);
    String label = stop.tipo.toUpperCase();
    String? subtitle;
    bool allowLlegada = false;

    switch (stop.tipo) {
      case 'inicio':
        icon = Icons.play_arrow_rounded;
        iconColor = const Color(0xFF10B981);
        bgTint = const Color(0xFFECFDF5);
        label = 'Inicio de Ruta';
        allowLlegada = true;
        break;
      case 'descanso':
        icon = Icons.coffee_rounded;
        iconColor = const Color(0xFFD97706);
        bgTint = const Color(0xFFFFFBEB);
        label = 'Parada de Descanso';
        allowLlegada = true;
        break;
      case 'combustible':
        icon = Icons.local_gas_station_rounded;
        iconColor = const Color(0xFFEA580C);
        bgTint = const Color(0xFFFFF7ED);
        label = stop.combustible?.nombre.isNotEmpty == true
            ? stop.combustible!.nombre
            : 'Carga de Combustible';
        subtitle = 'Estación de combustible';
        break;
      case 'recarga':
        icon = Icons.sync_alt_rounded;
        iconColor = const Color(0xFF0284C7);
        bgTint = const Color(0xFFF0F9FF);
        label = stop.recarga?.nombre.isNotEmpty == true
            ? stop.recarga!.nombre
            : 'Recarga de Producto';
        subtitle = 'Recarga de inventario';
        break;
      case 'otro':
        icon = Icons.place_outlined;
        iconColor = const Color(0xFF64748B);
        bgTint = const Color(0xFFF8FAFC);
        label = 'Parada adicional';
        subtitle = 'Sin acciones requeridas';
        break;
      case 'fin':
        icon = Icons.flag_rounded;
        iconColor = const Color(0xFF64748B);
        bgTint = const Color(0xFFF1F5F9);
        label = 'Fin de Ruta';
        allowLlegada = true;
        break;
    }

    final hasCoords = stop.stopLat != null &&
        stop.stopLng != null &&
        (stop.stopLat != 0 || stop.stopLng != 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgTint,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: iconColor.withOpacity(0.22),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 16),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '#${stop.orden} · $label',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),
          if (stop.llegadaEstimada.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  stop.llegadaEstimada,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ),
          if (hasCoords) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: 'Ir al punto (Mantén presionado para cambiar app)',
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF0F9FF),
                  foregroundColor: const Color(0xFF0284C7),
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFFBAE6FD), width: 1),
                  ),
                ),
                onPressed: () => _launchNavigationCoords(
                  stop.stopLat!,
                  stop.stopLng!,
                  stop.stopName,
                ),
                onLongPress: () => _launchNavigationCoords(
                  stop.stopLat!,
                  stop.stopLng!,
                  stop.stopName,
                  true,
                ),
                icon: const Icon(Icons.navigation_rounded,
                    size: 13, color: Color(0xFF0284C7)),
                label: const Text(
                  'Ir',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
            ),
          ],
          if (allowLlegada && !stop.visitada && stop.idParada > 0) ...[
            const SizedBox(width: 6),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF0FDF4),
                foregroundColor: const Color(0xFF15803D),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFBBF7D0), width: 1),
                ),
              ),
              onPressed: () async {
                _showAppleLoadingDialog(
                  title: 'Registrando llegada...',
                  subtitle: 'Confirmando parada con el servidor',
                );
                try {
                  final res =
                      await ref.read(routesProvider.notifier).registrarLlegada(
                            idRuta: route.idRuta,
                            idParada: stop.idParada,
                          );
                  _dismissAppleLoadingDialog();
                  if (!context.mounted) return;
                  ref.read(routesProvider.notifier).clearRecentNotices();
                  final msg = res.avisos.isNotEmpty
                      ? res.avisos.map((a) => a.displayTexto).join('\n')
                      : 'Llegada registrada con éxito.';
                  SnackbarTop.showSuccess(
                    context,
                    msg,
                    title: 'Correcto',
                  );
                } catch (e) {
                  _dismissAppleLoadingDialog();
                  if (!context.mounted) return;
                  SnackbarTop.showError(
                    context,
                    'Error al registrar llegada: $e',
                    style: SnackbarTopStyle.appleCard,
                  );
                }
              },
              child: const Text(
                'Llegada',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF15803D),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isStopCompleted(RouteStop stop) {
    final hasEntregar = stop.entregar.isNotEmpty;
    final hasRecoger = stop.recoger.isNotEmpty;

    if (hasEntregar || hasRecoger) {
      final allEntregasDone = !hasEntregar ||
          stop.entregar.every((g) => g.estado == 4 || g.estado == 8);
      final allRecojosDone = !hasRecoger ||
          stop.recoger.every((g) => g.estado >= 1 && g.estado != 0);
      return allEntregasDone && allRecojosDone;
    }

    // Ronda 146: En paradas de cliente sin guías, se requiere visita registrada
    if (stop.isClientStop) {
      return stop.visitaCerrada;
    }

    return stop.visitada;
  }

  Widget _buildGuiaActionRow({
    required DriverRoute route,
    required RouteStop stop,
    required RouteClient client,
    required GuiaItem guia,
    required bool isPickup,
  }) {
    final isVisit = guia.isVisitGuia || route.isVisitRoute;

    Color statusColor = const Color(0xFF475569);
    if (guia.estado == 4 ||
        (isPickup && guia.estado >= 1 && guia.estado != 8)) {
      statusColor = const Color(0xFF059669);
    } else if (guia.estado == 8) {
      statusColor = const Color(0xFFDC2626);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      guia.folio,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: statusColor.withOpacity(0.20),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        guia.estadoTexto,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                    if (guia.unsyncedLocal) ...[
                      const SizedBox(width: 4),
                      const Text(
                        '· Sin sinc.',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isVisit
                      ? (guia.items.isNotEmpty
                          ? '${guia.items.length} producto(s) esperados en visita'
                          : 'Guía de visita al cliente')
                      : '${guia.bultos} bulto(s) · ${guia.pesoKg} kg'
                          '${guia.destinatario != null ? " · Recibe: ${guia.destinatario!.nombre}" : ""}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (guia.estado == 4 ||
              (isPickup && guia.estado >= 1 && guia.estado != 8))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 13, color: Color(0xFF047857)),
                  const SizedBox(width: 4),
                  Text(
                    isVisit
                        ? 'Visitado'
                        : (isPickup ? 'Recogido' : 'Entregado'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            )
          else if (isVisit)
            SizedBox(
              height: 34,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                onPressed: () {
                  _pushLockedPortrait(
                    VisitRecordPage(
                      idRuta: route.idRuta,
                      idParada: stop.idParada,
                      visitGuia: guia,
                      client: client,
                    ),
                  );
                },
                icon: const Icon(Icons.storefront_rounded, size: 14),
                label: const Text(
                  'Visitar',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 34,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPickup
                      ? const Color(0xFF0284C7)
                      : const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                onPressed: () {
                  _pushLockedPortrait(
                    DeliverPage(
                      idRuta: route.idRuta,
                      idParada: stop.idParada,
                      guia: guia,
                      isPickupGuia: isPickup,
                      initialOperation: isPickup
                          ? GuiaOperationType.recojo
                          : GuiaOperationType.entrega,
                    ),
                  );
                },
                icon: Icon(
                  isPickup
                      ? Icons.inventory_2_rounded
                      : Icons.check_circle_rounded,
                  size: 14,
                ),
                label: Text(
                  isPickup ? 'Recoger' : 'Entregar',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Modal estilo Apple para seleccionar el resultado de la visita (Ronda 146)
  Future<void> _showVisitOptionsModal({
    required BuildContext context,
    required DriverRoute route,
    required RouteStop stop,
    required RouteClient client,
  }) async {
    final motivosRonda146 = [
      {
        'codigo': 31,
        'nombre': 'Negocio Cerrado',
        'icono': Icons.lock_outline_rounded
      },
      {
        'codigo': 32,
        'nombre': 'No estaba el encargado',
        'icono': Icons.person_off_outlined
      },
      {
        'codigo': 33,
        'nombre': 'No quiso comprar',
        'icono': Icons.thumb_down_outlined
      },
      {
        'codigo': 34,
        'nombre': 'No tenía dinero',
        'icono': Icons.money_off_csred_outlined
      },
      {
        'codigo': 35,
        'nombre': 'Todavía tenía producto',
        'icono': Icons.inventory_2_outlined
      },
      {
        'codigo': 36,
        'nombre': 'Cerró el negocio (definitivo)',
        'icono': Icons.store_mall_directory_outlined
      },
      {
        'codigo': 37,
        'nombre': 'No encontré el negocio',
        'icono': Icons.location_off_outlined
      },
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFECFDF5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront_rounded,
                          color: Color(0xFF059669), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Registrar Visita (Ronda 146)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            client.nombre,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Opción 1: Con Venta / Pedido
                Material(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _pushLockedPortrait(
                        VisitRecordPage(
                          idRuta: route.idRuta,
                          idParada: stop.idParada,
                          client: client,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.shopping_bag_outlined,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Visita con Venta o Pedido',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                                Text(
                                  'Capturar productos vendidos o registrar pedido',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: Color(0xFF059669)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                const Row(
                  children: [
                    Icon(Icons.camera_alt_outlined,
                        size: 14, color: Color(0xFF0284C7)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'O cerrar sin venta (requiere foto del negocio):',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Lista de motivos 31 al 37
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: motivosRonda146.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final item = motivosRonda146[i];
                      final codigo = item['codigo'] as int;
                      final nombre = item['nombre'] as String;
                      final icono = item['icono'] as IconData;

                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        tileColor: const Color(0xFFF8FAFC),
                        leading: Icon(icono,
                            size: 18, color: const Color(0xFF64748B)),
                        title: Text(
                          '$codigo. $nombre',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        trailing: const Icon(Icons.check_circle_outline_rounded,
                            size: 16, color: Color(0xFF94A3B8)),
                        onTap: () async {
                          Navigator.of(ctx).pop();

                          // Ronda 146: El servidor exige foto del negocio para reportar motivos de no venta
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 85,
                          );

                          if (picked == null) {
                            if (!mounted) return;
                            SnackbarTop.showError(
                              context,
                              'Se requiere una foto del negocio como evidencia para reportar: $nombre',
                              title: 'Foto Obligatoria',
                            );
                            return;
                          }

                          _showAppleLoadingDialog(
                            title: 'Registrando visita...',
                            subtitle: 'Guardando evidencia y motivo: $nombre',
                          );
                          try {
                            final photoUuid = await ref
                                .read(routesProvider.notifier)
                                .registerLocalPhoto(File(picked.path));

                            await ref
                                .read(routesProvider.notifier)
                                .registrarVisita(
                              idRuta: route.idRuta,
                              idParada: stop.idParada,
                              motivo: codigo,
                              fotosUuids: [photoUuid],
                            );
                            _dismissAppleLoadingDialog();
                            if (!mounted) return;
                            SnackbarTop.showSuccess(
                              context,
                              'Visita a ${client.nombre} cerrada con foto (Motivo: $nombre).',
                              title: 'Visita Registrada',
                            );
                          } catch (e) {
                            _dismissAppleLoadingDialog();
                            if (!mounted) return;
                            SnackbarTop.showError(
                              context,
                              'Error registrando visita: $e',
                              title: 'Error de Visita',
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =========================================================================
// WIDGET DESLIZABLE PARA CONFIRMAR LLEGADA (SWIPE TO CONFIRM)
// =========================================================================
class _SwipeToConfirmLlegadaButton extends StatefulWidget {
  final Future<void> Function() onConfirmed;
  final String label;
  final Color themeColor;

  const _SwipeToConfirmLlegadaButton({
    required this.onConfirmed,
    this.label = 'Desliza para confirmar llegada',
    this.themeColor = const Color(0xFF0F766E),
  });

  @override
  State<_SwipeToConfirmLlegadaButton> createState() =>
      _SwipeToConfirmLlegadaButtonState();
}

class _SwipeToConfirmLlegadaButtonState
    extends State<_SwipeToConfirmLlegadaButton>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  late AnimationController _animController;
  late Animation<double> _resetAnimation;
  bool _isFinished = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        setState(() {
          _dragPosition = _resetAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _reset() {
    if (!mounted) return;
    _resetAnimation = Tween<double>(
      begin: _dragPosition,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward(from: 0.0);
    _isFinished = false;
  }

  @override
  Widget build(BuildContext context) {
    const double height = 50.0;
    const double handlePadding = 4.0;
    const double handleSize = height - (handlePadding * 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag =
            constraints.maxWidth - handleSize - (handlePadding * 2);

        return Container(
          height: height,
          width: constraints.maxWidth,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Barra de relleno con el color temático que sigue el arrastre
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: (_dragPosition + handleSize + handlePadding * 2)
                    .clamp(0.0, constraints.maxWidth),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.themeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),

              // Texto central con flecha indicativa
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: 44, right: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: widget.themeColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_double_arrow_right_rounded,
                        color: widget.themeColor,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              // Agarradera / Handle circular deslizable
              Positioned(
                left: handlePadding + _dragPosition,
                top: handlePadding,
                child: GestureDetector(
                  onHorizontalDragUpdate: _isLoading || _isFinished
                      ? null
                      : (details) {
                          if (_animController.isAnimating) return;
                          setState(() {
                            _dragPosition = (_dragPosition + details.delta.dx)
                                .clamp(0.0, maxDrag);
                          });
                        },
                  onHorizontalDragEnd: _isLoading || _isFinished
                      ? null
                      : (details) async {
                          if (_animController.isAnimating) return;
                          // Umbral de activación al 75%
                          if (_dragPosition >= maxDrag * 0.75) {
                            setState(() {
                              _dragPosition = maxDrag;
                              _isFinished = true;
                              _isLoading = true;
                            });
                            try {
                              await widget.onConfirmed();
                            } finally {
                              if (mounted) {
                                setState(() => _isLoading = false);
                                _reset();
                              }
                            }
                          } else {
                            _reset();
                          }
                        },
                  child: Container(
                    width: handleSize,
                    height: handleSize,
                    decoration: BoxDecoration(
                      color: widget.themeColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.themeColor.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? LoadingAnimationWidget.threeRotatingDots(
                              color: Colors.white,
                              size: 18,
                            )
                          : const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
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
}

// =============================================================================
// PINTOR DE LÍNEA CONECTORA ENTRE CARTAS (ENTRE PARADAS 0, 1, 2, 3...)
// =============================================================================

class _BetweenCardsConnectorPainter extends CustomPainter {
  final double circleCenterX;
  final Color lineColor;

  const _BetweenCardsConnectorPainter({
    this.circleCenterX = 23.0,
    this.lineColor = const Color(0xFFCBD5E1),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Línea vertical sutil que une las cartas estilo Apple HIG
    canvas.drawLine(
      Offset(circleCenterX, 0),
      Offset(circleCenterX, size.height),
      paint,
    );

    // Pequeño nodo circular sutil en el punto medio del conector
    final nodePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(circleCenterX, size.height / 2),
      2.0,
      nodePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BetweenCardsConnectorPainter oldDelegate) {
    return oldDelegate.circleCenterX != circleCenterX ||
        oldDelegate.lineColor != lineColor;
  }
}

// =============================================================================
// MODAL DE CONEXI�N / RENOVACI�N DE TOKEN (SIN BORRAR LA COLA PENDIENTE)
// =============================================================================

class _DriverCredentialsSheet extends ConsumerStatefulWidget {
  const _DriverCredentialsSheet();

  @override
  ConsumerState<_DriverCredentialsSheet> createState() =>
      _DriverCredentialsSheetState();
}

class _DriverCredentialsSheetState
    extends ConsumerState<_DriverCredentialsSheet> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routesProvider);
    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tirador superior estilo iOS
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Encabezado con avatar squircle y botón de cerrar 'X'
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: const Color(0xFFBAE6FD)),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.sync_lock_rounded,
                              color: Color(0xFF0284C7),
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Conectar con Servidor',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 1),
                              Text(
                                'Servidor de Operación',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Su cola de acciones locales se conserva intacta y se enviará al iniciar sesión:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                    if (state.authError != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFECACA),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFDC2626),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                state.authError!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF991B1B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextField(
                      controller: _userCtrl,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Usuario de la plataforma',
                        labelStyle: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                          color: Color(0xFF0284C7),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        labelStyle: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                          color: Color(0xFF0284C7),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 18,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
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
                    const SizedBox(height: 18),
                    LoadingActionButton(
                      text: 'Obtener Token y Sincronizar',
                      icon: Icons.login_rounded,
                      isLoading: state.isLoading,
                      onPressed: () async {
                        final ok = await ref
                            .read(routesProvider.notifier)
                            .loginWithCredentials(
                              _userCtrl.text,
                              _passCtrl.text,
                            );
                        if (ok && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          backgroundColor: const Color(0xFFF8FAFC),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cerrar',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
