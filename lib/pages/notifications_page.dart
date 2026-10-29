import 'package:mark_v3/pages/Routes_/routes_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/providers/Notification_/notifications_provider.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/pages/tasks_page.dart';
import 'package:mark_v3/pages/MaintenancePage.dart';
import 'package:mark_v3/pages/MyVehicle_/MyVehiclePage.dart';
import 'package:mark_v3/pages/Custodia_/custodia_page.dart';
import 'package:mark_v3/services/mark_api_client.dart';

// Re-export NotificationItem para retrocompatibilidad total en main.dart
export 'package:mark_v3/providers/Notification_/notifications_provider.dart' show NotificationItem;

class NotificationsPage extends ConsumerStatefulWidget {
  final String userId;
  final bool showBackButton;

  const NotificationsPage({
    super.key,
    required this.userId,
    this.showBackButton = false,
  });

  static void addNotification(NotificationItem notification, Function updateUI) {
    updateUI();
  }

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(notificationsProvider.notifier).fetchNotifications(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);
    final notifications = state.filteredNotifications;

    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isSmallScreen = mediaQuery.size.width < 360;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        // Fondo gris suave estilo iOS System Grouped Background
        backgroundColor: const Color(0xFFF2F4F7),
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: const Color(0xFF0284C7),
            onRefresh: () => notifier.fetchNotifications(widget.userId),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Header Superior Apple (Large Title + Back Button) ────
                _buildHeader(state, notifier, isSmallScreen),
                const SizedBox(height: 12),

                // ── 2. Segmented Control Apple (Todas / Sin leer / Historial) ─
                _buildFilterTabs(state, notifier, isSmallScreen),
                const SizedBox(height: 12),

                // ── 3. Lista de Notificaciones o Estado Vacío ───────────────
                Expanded(
                  child: state.isLoading && state.notifications.isEmpty
                      ? Padding(
                          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 14 : 18),
                          child: AppSkeleton.list(itemCount: 6),
                        )
                      : notifications.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: EdgeInsets.only(
                                left: isSmallScreen ? 14 : 18,
                                right: isSmallScreen ? 14 : 18,
                                top: 4,
                                bottom: 95,
                              ),
                              itemCount: notifications.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 9),
                              itemBuilder: (context, index) {
                                final item = notifications[index];
                                return _buildNotificationCard(
                                  context,
                                  item,
                                  notifier,
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 1. HEADER SUPERIOR ESTILO APPLE (LARGE TITLE) ───────────────────────────
  Widget _buildHeader(
    NotificationsState state,
    NotificationsNotifier notifier,
    bool isSmallScreen,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 14.0 : 18.0,
        vertical: 8.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.showBackButton) ...[
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
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 0.9,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A1E34).withOpacity(0.035),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
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
            const SizedBox(width: 12),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notificaciones',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Avisos y mensajes de tu operación',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          if (state.unreadCount > 0)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => notifier.markAllAsRead(widget.userId),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 0.9,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A1E34).withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.done_all_rounded,
                        color: Color(0xFF0284C7),
                        size: 15,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Marcar todo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                          letterSpacing: -0.1,
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

  // ── 2. SEGMENTED CONTROL ESTILO APPLE (TODAS / SIN LEER / HISTORIAL) ────────
  Widget _buildFilterTabs(
    NotificationsState state,
    NotificationsNotifier notifier,
    bool isSmallScreen,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 14.0 : 18.0),
      child: Container(
        padding: const EdgeInsets.all(3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            _buildTabButton(
              title: 'Todas',
              count: state.notifications.length,
              isSelected: state.selectedTab == 0,
              onTap: () => notifier.changeTab(0),
            ),
            _buildTabButton(
              title: 'Sin leer',
              count: state.unreadCount,
              isSelected: state.selectedTab == 1,
              highlightBadge: state.unreadCount > 0,
              onTap: () => notifier.changeTab(1),
            ),
            _buildTabButton(
              title: 'Historial',
              count: state.notifications.where((n) => n.isRead).length,
              isSelected: state.selectedTab == 2,
              onTap: () => notifier.changeTab(2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required int count,
    required bool isSelected,
    bool highlightBadge = false,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF64748B),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: highlightBadge
                        ? const Color(0xFFEF4444)
                        : (isSelected
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: highlightBadge
                            ? Colors.white
                            : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── 3. TARJETA DE NOTIFICACIÓN APPLE (SQUIRCLE + BORDES HAIRLINE) ───────────
  Widget _buildNotificationCard(
    BuildContext context,
    NotificationItem item,
    NotificationsNotifier notifier,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.isRead
              ? const Color(0xFFE2E8F0).withOpacity(0.85)
              : const Color(0xFF0284C7).withOpacity(0.35),
          width: item.isRead ? 0.9 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A)
                .withOpacity(item.isRead ? 0.025 : 0.045),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            notifier.markAsRead(widget.userId, item.id);
            _showNotificationDetailsModal(context, item, notifier);
          },
          splashColor: const Color(0xFF0284C7).withOpacity(0.06),
          highlightColor: const Color(0xFFF8FAFC),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 13.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícono Squircle con degradado azul o neutro
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: item.isRead
                          ? const [
                              Color(0xFFF1F5F9),
                              Color(0xFFE2E8F0),
                            ]
                          : const [
                              Color(0xFF0284C7),
                              Color(0xFF38BDF8),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: item.isRead
                            ? Colors.black.withOpacity(0.02)
                            : const Color(0xFF0284C7).withOpacity(0.24),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      item.isRead
                          ? Icons.notifications_none_rounded
                          : Icons.notifications_active_rounded,
                      color: item.isRead
                          ? const Color(0xFF64748B)
                          : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 13),

                // Contenido de la notificación
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: item.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (!item.isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 7.5,
                              height: 7.5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF0284C7),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: item.isRead
                              ? const Color(0xFF64748B)
                              : const Color(0xFF334155),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 11.5,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4.5),
                          Text(
                            item.getTimeAgo(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Chevron estilo iOS
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFCBD5E1),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 4. ESTADO VACÍO APPLE ───────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/sindatos.json',
            width: 110,
            height: 110,
            repeat: true,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.notifications_off_outlined,
              size: 50,
              color: Color(0xFFCBD5E1),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Todo al día',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'No tienes notificaciones pendientes en este momento.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── 5. MODAL DE DETALLES ESTILO APPLE BOTTOM SHEET ──────────────────────────
  void _showNotificationDetailsModal(
    BuildContext context,
    NotificationItem item,
    NotificationsNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra superior Apple Grab Handle
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
              const SizedBox(height: 18),

              // Encabezado con ícono y categoría
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Color(0xFF0284C7),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Text(
                    'AVISO OPERATIVO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Título de la notificación
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),

              // Fecha / Tiempo transcurrido
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 12.5,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    item.getTimeAgo(),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Contenedor del mensaje con fondo suave y borde sutil
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 0.9,
                  ),
                ),
                child: Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF334155),
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Botón de acción principal al estilo Apple con Deep Linking (Ronda 133 / Pág. 14)
              if (item.origen != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.of(sheetCtx).pop();
                      _navigateToOrigen(this.context, item);
                    },
                    child: Text(
                      _getActionLabelForOrigen(item.origen),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    child: const Text(
                      'Cerrar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    child: const Text(
                      'Entendido',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _getActionLabelForOrigen(int? origen) {
    switch (origen) {
      case 103:
        return 'Ver Alerta de Vigilante en Ruta';
      case 6:
        return 'Abrir Custodia y Rondines';
      case 15:
        return 'Abrir Tarea Asignada';
      case 2:
        return 'Ver Servicio de Mantenimiento';
      case 1:
        return 'Ver Inspección de Vehículo';
      case 7:
        return 'Ver Tarjeta de Circulación';
      case 8:
        return 'Ver Tenencia';
      case 9:
        return 'Ver Verificación';
      case 10:
        return 'Ver Seguro';
      case 12:
        return 'Ver Pago de Crédito';
      case 3:
      case 5:
        return 'Ver Ficha de Vehículo';
      default:
        return 'Ir al Detalle';
    }
  }

  void _navigateToOrigen(BuildContext ctx, NotificationItem item) {
    final origen = item.origen;
    final idOrigen = item.idOrigen;
    final session = MarkApiClient.instance.currentSession;
    final colabId = session?.chofer.id.toString() ?? '';
    final accId = session?.usuario.idCuenta.toString() ?? '';

    if (origen == 103) {
      Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) => RoutesPage(
            idCollaborator: colabId,
            idMainAccount: accId,
          ),
        ),
      );
      return;
    }

    if (origen == 6 ||
        item.title.toLowerCase().contains('custodia') ||
        item.title.toLowerCase().contains('rondín') ||
        item.description.toLowerCase().contains('custodia')) {
      Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) => const CustodiaPage(),
        ),
      );
      return;
    }

    if (origen == 15) {
      Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) => TasksPage(initialTaskId: idOrigen),
        ),
      );
    } else if (origen == 2) {
      Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) => MaintenancePage(
            vehicle: {
              'idVehic': idOrigen ?? 0,
              'economic': 'Unidad ${idOrigen ?? ''}',
            },
          ),
        ),
      );
    } else if (origen == 1 ||
        origen == 3 ||
        origen == 5 ||
        origen == 7 ||
        origen == 8 ||
        origen == 9 ||
        origen == 10 ||
        origen == 12) {
      Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) => MyVehiclePage(
            userId: widget.userId,
            idCollaborator: colabId,
            idMainAccount: accId,
            inspectionsPermission: '1',
          ),
        ),
      );
    }
  }
}
