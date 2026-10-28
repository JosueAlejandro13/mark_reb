import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// ignore_for_file: prefer_const_constructors
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:mark_v3/pages/notifications_page.dart';
import 'package:mark_v3/utils/SplashScreen.dart';
import 'package:mark_v3/pages/Auth_/forgot_password_page.dart';
import 'package:mark_v3/pages/Auth_/login_page.dart';
import 'package:mark_v3/pages/Auth_/verify_code_page.dart';
import 'package:mark_v3/pages/Auth_/reset_password_page.dart';
import 'package:mark_v3/pages/home_page.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/pages/reports_page.dart';
import 'package:mark_v3/pages/Routes_/routes_page.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:mark_v3/pages/Vehicles_/vehicles_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:uuid/uuid.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:mark_v3/services/local_notification_service.dart';

//Autor: Josue Hernandez
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Mensaje en segundo plano: ${message.messageId}");

  if (message.notification?.title != null &&
      message.notification?.body != null) {
    String notificationId = message.data.containsKey('id')
        ? message.data['id'].toString()
        : const Uuid().v4();
    NotificationItem notification = NotificationItem(
      id: notificationId,
      icon: Icons.notifications,
      title: message.notification!.title!,
      description: message.notification!.body!,
      date: DateTime.now(),
    );

    final prefs = await SharedPreferences.getInstance();
    final String? currentUserId = prefs.getString('userId');
    final String fcmKey = currentUserId != null && currentUserId.isNotEmpty
        ? 'fcm_pending_$currentUserId'
        : 'fcm_pending_notifications';

    final String? notificationsJson = prefs.getString(fcmKey);
    List<dynamic> notificationsList = [];

    if (notificationsJson != null && notificationsJson.isNotEmpty) {
      notificationsList = jsonDecode(notificationsJson);
    }

    notificationsList.insert(0, notification.toJson());

    await prefs.setString(fcmKey, jsonEncode(notificationsList));
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bloquea toda la aplicación en orientación vertical por defecto
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  try {
    await Firebase.initializeApp();

    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    if (kDebugMode) {
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(false);
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase initialization warning on iOS: $e");
  }

  tz.initializeTimeZones();
  await LocalNotificationService.initialize();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Connectivity _connectivity;
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  ConnectivityResult? _previousResult;
  ConnectivityResult? _lastConnectionStatus;
  bool _isAppReady = false;

  @override
  void initState() {
    super.initState();

    _connectivity = Connectivity();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateConnectionStatus(results);
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Retrasamos la comprobación inicial y la habilitación de los snackbars
      // para dar tiempo a que GetMaterialApp termine de construir su Overlay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _isAppReady = true;
          _checkInitialConnection();
        }
      });
    });

    _initializeFirebaseMessaging();
  }

  void _initializeFirebaseMessaging() {
    try {
      // Ronda 146: Escuchar renovación de token FCM
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          final token = await const FlutterSecureStorage().read(key: 'auth_token_64');
          if (token != null && token.isNotEmpty) {
            await MarkApiClient.instance.updateFcm(newToken, tokenOverride: token);
          }
        } catch (e) {
          debugPrint("Error en onTokenRefresh: $e");
        }
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("Mensaje en primer plano: ${message.notification?.title}");

        if (message.notification?.title != null &&
            message.notification?.body != null) {
          String notificationId = message.data.containsKey('id')
              ? message.data['id'].toString()
              : const Uuid().v4();

          NotificationItem notification = NotificationItem(
            id: notificationId,
            icon: Icons.notifications,
            title: message.notification!.title!,
            description: message.notification!.body!,
            date: DateTime.now(),
          );

          NotificationsPage.addNotification(notification, _updateUI);
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
        debugPrint("Notificación abierta: ${message.notification?.title}");
        // Ronda 146: Al tocar la notificación abre la bandeja de notificaciones
        try {
          final prefs = await SharedPreferences.getInstance();
          final uid = prefs.getString('userId') ?? '';
          Get.to(() => NotificationsPage(userId: uid, showBackButton: true));
        } catch (e) {
          debugPrint("Error navegando a notificaciones: $e");
        }
      });
    } catch (e) {
      debugPrint("FirebaseMessaging no inicializado o no soportado en esta plataforma/test: $e");
    }
  }

  void _updateUI() {
    setState(() {});
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    if (!_isAppReady) return;
    
    for (var result in results) {
      if (_lastConnectionStatus != result) {
        _lastConnectionStatus = result;
        // Las alertas visuales (Snackbar) de conexión se eliminaron a petición
        // del usuario, pero se mantiene el rastreo de _lastConnectionStatus.
      }
    }
  }

  double scaledFont(double screenWidth, double factor,
      {double min = 12, double max = 20}) {
    return (screenWidth * factor).clamp(min, max);
  }

  Future<void> _checkInitialConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Error al comprobar el estado inicial de la conexión: $e');
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Mark V3',
          locale: const Locale('es', 'ES'),
          supportedLocales: const [
            Locale('en', 'US'),
            Locale('es', 'ES'),
          ],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromARGB(255, 255, 255, 255),
            ),
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: Colors.black,
            ),
            appBarTheme: const AppBarTheme(
              centerTitle: false,
            ),
            useMaterial3: true,
            popupMenuTheme: PopupMenuThemeData(
              color: Colors.white,
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            checkboxTheme: CheckboxThemeData(
              fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF1E293B);
                }
                return Colors.transparent;
              }),
              checkColor: WidgetStateProperty.all(Colors.white),
              side: const BorderSide(color: Color(0xFF64748B), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: Color(0xFF027A9F),
              selectionColor: Color(0x33027A9F),
              selectionHandleColor: Color(0xFF027A9F),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
              ),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF027A9F), width: 1.5),
              ),
              labelStyle: TextStyle(
                color: Colors.black,
                fontSize: scaledFont(screenWidth, 0.031, min: 14, max: 16),
              ),
              hintStyle: TextStyle(
                color: Colors.black,
                fontSize: scaledFont(screenWidth, 0.031, min: 14, max: 16),
              ),
              errorStyle: TextStyle(
                color: Colors.red,
                fontSize: scaledFont(screenWidth, 0.028, min: 12, max: 14),
              ),
              floatingLabelStyle: TextStyle(
                color: Colors.black,
                fontSize: scaledFont(screenWidth, 0.031, min: 14, max: 16),
              ),
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Color.fromARGB(255, 255, 255, 255),
              selectedItemColor: Color.fromARGB(255, 51, 44, 44),
              unselectedItemColor: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                splashFactory: NoSplash.splashFactory,
                foregroundColor: Colors.black,
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              contentTextStyle: TextStyle(
                fontSize: screenWidth * 0.035,
                color: const Color.fromARGB(255, 255, 255, 255),
              ),
              backgroundColor: const Color(0xFF0886B5).withOpacity(0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              behavior: SnackBarBehavior.floating,
            ),
            primaryColor: const Color.fromARGB(255, 255, 255, 255),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                splashFactory: NoSplash.splashFactory,
                backgroundColor: const Color(0xFF0886B5),
                foregroundColor: Colors.white,
                elevation: 6,
                shadowColor: const Color(0xFF0886B5).withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                textStyle: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Colors.white,
              elevation: 8, // Sombra
              shape: RoundedRectangleBorder(
                // Bordes redondeados
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              headerBackgroundColor: const Color(0xFF0284C7),
              headerForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              dayStyle: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
              dayForegroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                if (states.contains(WidgetState.disabled)) {
                  return const Color(0xFF94A3B8);
                }
                return const Color(0xFF0F172A);
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF0284C7);
                }
                return null;
              }),
              todayBorder: const BorderSide(
                color: Color(0xFF0284C7),
                width: 1.5,
              ),
              todayForegroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return const Color(0xFF0284C7);
              }),
              todayBackgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF0284C7);
                }
                return Colors.transparent;
              }),
              yearForegroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return const Color(0xFF0F172A);
              }),
              yearBackgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF0284C7);
                }
                return null;
              }),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0284C7),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            iconButtonTheme: IconButtonThemeData(
              style: IconButton.styleFrom(
                splashFactory: NoSplash.splashFactory,
              ),
            ),
          ),
          initialRoute: '/splash',
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/login': (context) => const LoginPage(),
            '/forgot-password': (context) => const ForgotPasswordPage(),
            '/verify-code': (context) {
              final email =
                  ModalRoute.of(context)?.settings.arguments as String?;
              return VerifyCodePage(email: email);
            },
            '/reset-password': (context) {
              final email =
                  ModalRoute.of(context)?.settings.arguments as String?;
              return ResetPasswordPage(email: email);
            },
            '/home': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map?;
              final userId = args?['id'] as String?;
              final uuid = args?['uuid'] as String?;
              final userName = args?['name'] as String?;
              final idCollaborator = args?['idCollaborator'] as String?;
              final idMainAccount = args?['idMainAccount'] as String?;
              final circulationCardPermission =
                  args?['circulationCardPermission'] as String?;
              final taxesPermission = args?['taxesPermission'] as String?;
              final verificationsPermission =
                  args?['verificationsPermission'] as String?;
              final insurancePermission =
                  args?['insurancePermission'] as String?;
              final creditPermission = args?['creditPermission'] as String?;
              final inspectionsPermission =
                  args?['inspectionsPermission'] as String?;
              final additionalPermissions =
                  args?['additionalPermissions'] as String?;
              final idVehic = args?['idVehic'] as String?;
              final creationId = args?['creationId'] as String?;
              final password = args?['password'] as String?;
              final email = args?['email'] as String?;

              return HomePage(
                userId: userId ?? '',
                uuid: uuid ?? '',
                userName: userName ?? '',
                idCollaborator: idCollaborator ?? '',
                idMainAccount: idMainAccount ?? '',
                circulationCardPermission: circulationCardPermission ?? '',
                taxesPermission: taxesPermission ?? '',
                verificationsPermission: verificationsPermission ?? '',
                insurancePermission: insurancePermission ?? '',
                creditPermission: creditPermission ?? '',
                inspectionsPermission: inspectionsPermission ?? '',
                additionalPermissions: additionalPermissions ?? '',
                creationId: creationId ?? '',
                password: password ?? '',
                email: email ?? '',
              );
            },
            '/manageVehicles': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map?;
              final circulationCardPermission =
                  args?['circulationCardPermission'] as String? ?? '0';
              final taxesPermission =
                  args?['taxesPermission'] as String? ?? '0';
              final verificationsPermission =
                  args?['verificationsPermission'] as String? ?? '0';
              final insurancePermission =
                  args?['insurancePermission'] as String? ?? '0';
              final creditPermission =
                  args?['creditPermission'] as String? ?? '0';
              final userId = args?['id'] as String?;
              final additionalPermissions =
                  args?['additionalPermissions'] as String?;
              final inspectionsPermission =
                  args?['inspectionsPermission'] as String? ?? '0';
              final idCollaborator = args?['idCollaborator'] as String?;
              final idMainAccount = args?['idMainAccount'] as String?;

              return VehiclesPage(
                  circulationCardPermission: circulationCardPermission,
                  taxesPermission: taxesPermission,
                  verificationsPermission: verificationsPermission,
                  insurancePermission: insurancePermission,
                  creditPermission: creditPermission,
                  inspectionsPermission: inspectionsPermission,
                  userId: userId ?? '',
                  additionalPermissions: additionalPermissions ?? '',
                  idMainAccount: idMainAccount ?? '',
                  idCollaborator: idCollaborator ?? '');
            },
            '/routes': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map?;
              final idMainAccount = args?['idMainAccount'] as String?;
              final idCollaborator = args?['idCollaborator'] as String?;

              return RoutesPage(
                idMainAccount: idMainAccount ?? '',
                idCollaborator: idCollaborator ?? '',
              );
            },
            '/reports': (context) => const ReportsPage(),
            '/reabastecimiento': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map?;
              final idMainAccount = args?['idMainAccount'] as String?;
              final idCollaborator = args?['idCollaborator'] as String?;

              return RoutesPage(
                idMainAccount: idMainAccount ?? '',
                idCollaborator: idCollaborator ?? '',
              );
            },
          },
          builder: (context, child) {
            final width = MediaQuery.sizeOf(context).width;
            final isTablet = width >= 600.0;
            return ResponsiveBreakpoints.builder(
              child: isTablet
                  // En tablet/desktop: renderizado natural sin forzar escala
                  ? child!
                  // En móvil: escalar desde diseño base de 375px
                  : ResponsiveScaledBox(
                      width: 375,
                      child: child!,
                    ),
              breakpoints: [
                const Breakpoint(start: 0, end: 599, name: MOBILE),
                const Breakpoint(start: 600, end: 1023, name: TABLET),
                const Breakpoint(start: 1024, end: 1920, name: DESKTOP),
                const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
              ],
            );
          },
        );
      },
    );
  }
}
