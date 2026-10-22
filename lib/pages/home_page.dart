import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:mark_v3/pages/MenuPage.dart';
import 'package:mark_v3/providers/Home_/home_provider.dart';
import 'package:mark_v3/providers/Notification_/notifications_provider.dart';
import 'package:mark_v3/providers/Routes_/routes_provider.dart';
import 'package:mark_v3/utils/responsive_utils.dart';
import 'profile_page.dart';
import 'home_page_content.dart';
import 'notifications_page.dart';
import 'package:mark_v3/widgets/modern_floating_nav_bar.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/providers/Profile_/profile_provider.dart';
import 'package:mark_v3/providers/Profile_/edit_profile_provider.dart';

//Autor: Josue Hernandez
class HomePage extends ConsumerStatefulWidget {
  final String userId;
  final String userName;
  final String idCollaborator;
  final String circulationCardPermission;
  final String taxesPermission;
  final String verificationsPermission;
  final String insurancePermission;
  final String creditPermission;
  final String inspectionsPermission;
  final String additionalPermissions;
  final String idMainAccount;
  final String uuid;
  final String creationId;
  final String email;
  final String password;

  const HomePage(
      {super.key,
      required this.userId,
      required this.userName,
      required this.idCollaborator,
      required this.circulationCardPermission,
      required this.taxesPermission,
      required this.verificationsPermission,
      required this.insurancePermission,
      required this.creditPermission,
      required this.inspectionsPermission,
      required this.additionalPermissions,
      required this.uuid,
      required this.idMainAccount,
      required this.creationId,
      required this.email,
      required this.password});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  Timer? _inactivityTimer;
  Timer? _dialogTimer;
  final Duration _timeoutDuration = const Duration(minutes: 100000);
  final Duration _dialogTimeoutDuration = const Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetInactivityTimer();

    // Pre-cargar sesión de Rutas en segundo plano para entrar sin esperas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(routesProvider.notifier).initializeModule(
            fallbackEmail: widget.email,
            fallbackPassword: widget.password,
          );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelInactivityTimer();
    super.dispose();
  }

  Future<void> _handleAppCloseOrBackground() async {}

  Future<void> _handleAppOpenOrBackground() async {}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      debugPrint('App en el primer plano');
      _handleAppOpenOrBackground();
      ref.read(routesProvider.notifier).syncPendingQueueAndRefreshDay();
    } else if (state == AppLifecycleState.inactive) {
      debugPrint('App inactiva temporalmente');
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _handleAppCloseOrBackground();
      debugPrint('App cerrandonse');
    }
  }

  void _resetInactivityTimer() {
    _cancelInactivityTimer();
    _inactivityTimer = Timer(_timeoutDuration, _showInactivityDialog);
  }

  void _cancelInactivityTimer() {
    if (_inactivityTimer != null) {
      _inactivityTimer!.cancel();
    }
    if (_dialogTimer != null) {
      _dialogTimer!.cancel();
    }
  }

  void _showInactivityDialog() {
    final screenWidth = MediaQuery.of(context).size.width;
    bool isLoggingOut = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              title: Text(
                'Inactividad detectada',
                style: TextStyle(
                    fontSize: screenWidth * 0.040,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A)),
              ),
              content: Text(
                'Tu sesión se cerrará pronto por inactividad. ¿Deseas continuar?',
                style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: const Color(0xFF64748B)),
              ),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  onPressed: () {
                    _resetInactivityTimer();
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF475569),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                        fontSize: screenWidth * 0.030,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                LoadingActionButton(
                  text: 'Cerrar Sesión',
                  isLoading: isLoggingOut,
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  height: 38,
                  width: 120,
                  borderRadius: 10,
                  fontSize: screenWidth * 0.030,
                  onPressed: () async {
                    setState(() {
                      isLoggingOut = true;
                    });
                    _cancelInactivityTimer();
                    await _handleInactivity();
                  },
                ),
              ],
            );
          },
        );
      },
    );
    _dialogTimer = Timer(_dialogTimeoutDuration, _handleInactivity);
  }

  Future<void> _handleInactivity() async {
    debugPrint("Usuario inactivo. Cerrando sesión...");
    MarkApiClient.instance.clearSession();
    ref.invalidate(profileProvider);
    ref.invalidate(editProfileProvider);
    ref.invalidate(routesProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(homeProvider);
    Get.offAllNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final homeNotifier = ref.read(homeProvider.notifier);
    // Usar el unreadCount real del notificationsProvider (misma fuente que la página)
    final unreadCount = ref.watch(notificationsProvider).unreadCount;

    final List<Widget> pages = [
      HomePageContent(
          usuario: widget.userName,
          userId: widget.userId,
          idCollaborator: widget.idCollaborator,
          idMainAccount: widget.idMainAccount),
      NotificationsPage(userId: widget.userId),
      MenuPage(
        idCollaborator: widget.idCollaborator,
        idMainAccount: widget.idMainAccount,
        circulationCardPermission: widget.circulationCardPermission,
        taxesPermission: widget.taxesPermission,
        verificationsPermission: widget.verificationsPermission,
        insurancePermission: widget.insurancePermission,
        creditPermission: widget.creditPermission,
        userId: widget.userId,
        uuid: widget.uuid,
        inspectionsPermission: widget.inspectionsPermission,
        additionalPermissions: widget.additionalPermissions,
        creationId: widget.creationId,
      ),
      ProfilePage(
          usuario: widget.userName,
          userId: widget.userId,
          idCollaborator: widget.idCollaborator,
          idMainAccount: widget.idMainAccount,
          email: widget.email,
          password: widget.password,
          uuid: widget.uuid,
          creationId: widget.creationId),
    ];

    final isTablet = AppBreakpoints.isTablet(context);

    // Items de navegación compartidos entre móvil y tablet
    final navItems = [
      const ModernNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Inicio',
      ),
      ModernNavItem(
        icon: Icons.notifications_none_rounded,
        activeIcon: Icons.notifications_rounded,
        label: 'Notificaciones',
        showBadge: unreadCount > 0,
        badgeCount: unreadCount > 0 ? unreadCount : null,
      ),
      const ModernNavItem(
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view_rounded,
        label: 'Menú',
      ),
      const ModernNavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Perfil',
      ),
    ];

    void handleNavTap(int index) {
      homeNotifier.setNavIndex(index);
      if (index == 1) {
        ref
            .read(notificationsProvider.notifier)
            .fetchNotifications(widget.userId);
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _resetInactivityTimer,
      onPanDown: (_) => _resetInactivityTimer(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F4F7),
        appBar: PreferredSize(
          preferredSize: Size.zero,
          child: AppBar(
            backgroundColor: const Color(0xFFF2F4F7),
            elevation: 0,
          ),
        ),
        body: Stack(
          children: [
            IndexedStack(
              index: homeState.selectedNavIndex,
              children: pages,
            ),
            // Difuminado inferior sutil estilo iOS
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: isTablet ? 128 : 82,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFF2F4F7).withOpacity(0.0),
                        const Color(0xFFF2F4F7).withOpacity(0.85),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ModernFloatingNavBar(
                currentIndex: homeState.selectedNavIndex,
                backgroundColor: Colors.white,
                activeContentColor: const Color(0xFF0284C7),
                activeCapsuleColor: const Color(0xFFE0F2FE),
                inactiveContentColor: const Color(0xFF64748B),
                height: isTablet ? 74.0 : 50.0,
                maxWidth: isTablet ? 580.0 : null,
                iconSize: isTablet ? 34.0 : null,
                margin: isTablet
                    ? const EdgeInsets.only(left: 24, right: 24, bottom: 22)
                    : const EdgeInsets.only(left: 18, right: 18, bottom: 8),
                onTap: handleNavTap,
                items: navItems,
                showCapsule: false,
                showLabels: false,
                showDot: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
