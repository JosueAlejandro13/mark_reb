import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:mark_v3/pages/MenuPage.dart';
import 'package:mark_v3/providers/home_provider.dart';
import 'package:mark_v3/services/database_service.dart';
import 'profile_page.dart';
import 'home_page_content.dart';
import 'notifications_page.dart';
import 'package:mark_v3/widgets/modern_floating_nav_bar.dart';

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

class _HomePageState extends ConsumerState<HomePage> with WidgetsBindingObserver {
  Timer? _inactivityTimer;
  Timer? _dialogTimer;
  final Duration _timeoutDuration = const Duration(minutes: 100000);
  final Duration _dialogTimeoutDuration = const Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetInactivityTimer();

    // Carga inicial de notificaciones con Riverpod
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeProvider.notifier).fetchUnreadNotifications(widget.userId);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelInactivityTimer();
    super.dispose();
  }

  Future<void> _handleAppCloseOrBackground() async {
    DatabaseService dbService = DatabaseService();
    await dbService.updateAccessRecord(
        int.parse(widget.creationId), widget.uuid);
  }

  Future<void> _handleAppOpenOrBackground() async {
    DatabaseService dbService = DatabaseService();
    await dbService.updateAccessRecordOpen(
        int.parse(widget.creationId), widget.uuid);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      debugPrint('App en el primer plano');
      _handleAppOpenOrBackground();
      ref.read(homeProvider.notifier).fetchUnreadNotifications(widget.userId);
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Inactividad detectada',
            style: TextStyle(
                fontSize: screenWidth * 0.040, fontWeight: FontWeight.w500),
          ),
          content: Text(
            'Tu sesión se cerrará pronto por inactividad. ¿Deseas continuar?',
            style: TextStyle(fontSize: screenWidth * 0.035),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _cancelInactivityTimer();
                Navigator.of(context).pop();
                _handleInactivity();
              },
              child: Text(
                'Cerrar Sesión',
                style: TextStyle(fontSize: screenWidth * 0.030),
              ),
            ),
            TextButton(
              onPressed: () {
                _resetInactivityTimer();
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF0886B5),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Cancelar',
                style: TextStyle(fontSize: screenWidth * 0.030),
              ),
            ),
          ],
        );
      },
    );
    _dialogTimer = Timer(_dialogTimeoutDuration, _handleInactivity);
  }

  Future<void> _handleInactivity() async {
    DatabaseService dbService = DatabaseService();
    await dbService.updateAccessRecord(
        int.parse(widget.creationId), widget.uuid);

    debugPrint("Usuario inactivo. Redirigiendo a Login...");
    Get.offAllNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final homeNotifier = ref.read(homeProvider.notifier);

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

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _resetInactivityTimer,
      onPanDown: (_) => _resetInactivityTimer(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 250, 250, 250),
              Color.fromARGB(255, 205, 240, 255),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PreferredSize(
            preferredSize: Size.zero,
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
          ),
          body: Stack(
            children: [
              IndexedStack(
                index: homeState.selectedNavIndex,
                children: pages,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ModernFloatingNavBar(
                  currentIndex: homeState.selectedNavIndex,
                  activeContentColor: const Color(0xFF0886B5),
                  activeCapsuleColor: const Color(0xFFE0F2FE),
                  inactiveContentColor: const Color(0xFF64748B),
                  onTap: (index) {
                    homeNotifier.setNavIndex(index);
                    if (index == 1) {
                      homeNotifier.fetchUnreadNotifications(widget.userId);
                    }
                  },
                  items: [
                    const ModernNavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Inicio',
                    ),
                    ModernNavItem(
                      icon: Icons.notifications_none_rounded,
                      activeIcon: Icons.notifications_rounded,
                      label: 'Notificaciones',
                      showBadge: homeState.unreadNotifications > 0,
                      badgeCount: homeState.unreadNotifications > 0
                          ? homeState.unreadNotifications
                          : null,
                    ),
                    const ModernNavItem(
                      icon: Icons.dashboard_outlined,
                      activeIcon: Icons.dashboard_rounded,
                      label: 'Menú',
                    ),
                    const ModernNavItem(
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: 'Perfil',
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
}
