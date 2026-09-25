import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mark_v3/pages/MenuPage.dart';
import 'package:mark_v3/services/ConnectionNotification_/NotificationCon_service.dart';
import 'package:mark_v3/services/database_service.dart';
import 'profile_page.dart';
import 'home_page_content.dart';
import 'notifications_page.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

//Autor: Josue Hernandez
class HomePage extends StatefulWidget {
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
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final List<Widget> pages = [];
  final PageController _pageController = PageController();

  Timer? _inactivityTimer;
  Timer? _dialogTimer;
  final Duration _timeoutDuration = const Duration(minutes: 100000);
  final Duration _dialogTimeoutDuration = const Duration(seconds: 10);
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUnreadNotifications();

    WidgetsBinding.instance.addObserver(this);
    _resetInactivityTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelInactivityTimer();
    _pageController.dispose();

    super.dispose();
  }

  Future<void> _fetchUnreadNotifications() async {
    int userId = int.parse(widget.userId);

    List<Map<String, dynamic>> notifications =
        await NotificationService().getNotifications(userId.toString());

    int unreadNotifications =
        notifications.where((notif) => notif['sendApp'] == 1).length;

    print("Notificaciones no leídas: $unreadNotifications");
    setState(() {
      unreadCount = unreadNotifications;
    });
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
    final screenHeight = MediaQuery.of(context).size.height;
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
            'Tu sesión se cerrará en 10 segundos. ¿Deseas continuar?',
            style: TextStyle(fontSize: screenWidth * 0.033),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetInactivityTimer();
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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final List<Widget> pages = [
      HomePageContent(
          usuario: widget.userName,
          userId: widget.userId,
          idCollaborator: widget.idCollaborator,
          idMainAccount: widget.idMainAccount),
      NotificationsPage(userId: widget.userId),
      ProfilePage(
          usuario: widget.userName,
          userId: widget.userId,
          idCollaborator: widget.idCollaborator,
          idMainAccount: widget.idMainAccount,
          email: widget.email,
          password: widget.password),
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
    ];

    void onItemTapped(int index) {
      setState(() {
        _selectedIndex = index;
      });
      _resetInactivityTimer();
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _resetInactivityTimer,
      onPanDown: (_) => _resetInactivityTimer(),
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(20.0),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
        body: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(seconds: 5),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 250, 250, 250),
                    Color.fromARGB(255, 205, 240, 255)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              children: pages,
            ),
          ],
        ),
        bottomNavigationBar: CurvedNavigationBar(
          backgroundColor: Colors.transparent,
          color: const Color.fromARGB(255, 205, 240, 255),
          buttonBackgroundColor: Colors.white,
          height: 47.0,
          items: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home,
                    size: screenWidth * 0.056, color: Colors.black),
                Text('Inicio',
                    style: TextStyle(
                        fontSize: screenWidth * 0.022, color: Colors.black)),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.notifications,
                        size: screenWidth * 0.056, color: Colors.black),
                    if (unreadCount >
                        0) // Solo muestra el número si unreadCount es mayor que 0
                      Positioned(
                        right: -9,
                        top: -17,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 17,
                            minHeight: 17,
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: TextStyle(
                              fontSize: screenWidth * 0.029,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                Text('Notificaciones',
                    style: TextStyle(
                        fontSize: screenWidth * 0.022, color: Colors.black)),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person,
                    size: screenWidth * 0.056, color: Colors.black),
                Text('Perfil',
                    style: TextStyle(
                        fontSize: screenWidth * 0.022, color: Colors.black)),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu,
                    size: screenWidth * 0.056, color: Colors.black),
                Text('Menú',
                    style: TextStyle(
                        fontSize: screenWidth * 0.022, color: Colors.black)),
              ],
            ),
          ],
          onTap: (index) {
            if (mounted) {
              setState(() {
                _selectedIndex = index;
              });

              if (index == 1) {
                _fetchUnreadNotifications();
              }
            }
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 1),
              curve: Curves.easeInOut,
            );
          },
          index: _selectedIndex,
        ),
      ),
    );
  }
}
