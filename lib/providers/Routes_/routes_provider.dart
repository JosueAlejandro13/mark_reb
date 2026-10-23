import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';
import 'package:mark_v3/services/ConnectionRoutes_/RoutesCon_service.dart';
import 'package:mark_v3/services/ConnectionRoutes_/driver_local_db.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/widgets.dart';
import 'package:mark_v3/services/local_notification_service.dart';

class ActionExecutionResult {
  final bool queuedOrApplied;
  final String
      estado; // 'aplicada' | 'repetida' | 'rechazada' | 'reintentar' | 'en_cola'
  final List<ServerNotice> avisos;
  final bool needsConfirmDifference; // BULTOS o PENDIENTES
  final List<String> pendingFolios;

  const ActionExecutionResult({
    required this.queuedOrApplied,
    required this.estado,
    this.avisos = const [],
    this.needsConfirmDifference = false,
    this.pendingFolios = const [],
  });
}

class RoutesState {
  final bool isLoading;
  final bool isSyncing;
  final bool isOnline;
  final bool requiresManualAuth;
  final String? authError;
  final DriverSession? session;
  final String selectedDate; // YYYY-MM-DD
  final DayPackage? dayPackage;
  final List<QueuedAction> pendingActions;
  final List<QueuedAction> rejectedActions;
  final List<QueuedPhoto> pendingPhotos;
  final List<RouteClient> clients;
  final List<CatalogProduct> catalog;
  final List<SyncedOrder>? _syncedOrders;
  List<SyncedOrder> get syncedOrders => _syncedOrders ?? const [];
  final String? lastSyncTime;
  final List<ServerNotice> recentNotices;
  final Position? lastKnownPosition;
  final DateTime? lastPositionTime;

  const RoutesState({
    this.isLoading = false,
    this.isSyncing = false,
    this.isOnline = true,
    this.requiresManualAuth = false,
    this.authError,
    this.session,
    required this.selectedDate,
    this.dayPackage,
    this.pendingActions = const [],
    this.rejectedActions = const [],
    this.pendingPhotos = const [],
    this.clients = const [],
    this.catalog = const [],
    List<SyncedOrder>? syncedOrders,
    this.lastSyncTime,
    this.recentNotices = const [],
    this.lastKnownPosition,
    this.lastPositionTime,
  }) : _syncedOrders = syncedOrders;

  int get totalPendingSyncCount => pendingActions.length + pendingPhotos.length;

  DriverRoute? findRoute(int idRuta) {
    final pkg = dayPackage;
    if (pkg == null) return null;
    for (final r in pkg.rutas) {
      if (r.idRuta == idRuta) return r;
    }
    return null;
  }

  RouteStop? findStop(int idRuta, int idParada) {
    final route = findRoute(idRuta);
    if (route == null) return null;
    for (final s in route.paradas) {
      if (s.idParada == idParada) return s;
    }
    return null;
  }

  RoutesState copyWith({
    bool? isLoading,
    bool? isSyncing,
    bool? isOnline,
    bool? requiresManualAuth,
    String? authError,
    bool clearAuthError = false,
    DriverSession? session,
    String? selectedDate,
    DayPackage? dayPackage,
    bool clearDayPackage = false,
    List<QueuedAction>? pendingActions,
    List<QueuedAction>? rejectedActions,
    List<QueuedPhoto>? pendingPhotos,
    List<RouteClient>? clients,
    List<CatalogProduct>? catalog,
    List<SyncedOrder>? syncedOrders,
    String? lastSyncTime,
    List<ServerNotice>? recentNotices,
    Position? lastKnownPosition,
    DateTime? lastPositionTime,
  }) {
    return RoutesState(
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      isOnline: isOnline ?? this.isOnline,
      requiresManualAuth: requiresManualAuth ?? this.requiresManualAuth,
      authError: clearAuthError ? null : (authError ?? this.authError),
      session: session ?? this.session,
      selectedDate: selectedDate ?? this.selectedDate,
      dayPackage: clearDayPackage ? null : (dayPackage ?? this.dayPackage),
      pendingActions: pendingActions ?? this.pendingActions,
      rejectedActions: rejectedActions ?? this.rejectedActions,
      pendingPhotos: pendingPhotos ?? this.pendingPhotos,
      clients: clients ?? this.clients,
      catalog: catalog ?? this.catalog,
      syncedOrders: syncedOrders ?? _syncedOrders ?? const [],
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      recentNotices: recentNotices ?? this.recentNotices,
      lastKnownPosition: lastKnownPosition ?? this.lastKnownPosition,
      lastPositionTime: lastPositionTime ?? this.lastPositionTime,
    );
  }
}

final routesProvider =
    NotifierProvider<RoutesNotifier, RoutesState>(RoutesNotifier.new);

class RoutesNotifier extends Notifier<RoutesState> {
  final RoutesconService _api = RoutesconService();
  final DriverLocalDb _db = DriverLocalDb.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Uuid _uuid = const Uuid();

  AppLifecycleListener? _lifecycleListener;
  Timer? _syncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  StreamSubscription<RemoteMessage>? _fcmSub;
  StreamSubscription<String>? _fcmTokenRefreshSub;
  bool _isInitialized = false;
  DateTime? _rateLimitUntil;
  DateTime? _lastPeriodicDayRefresh;

  static String _todayString() =>
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  static String _nowLocalTimestamp() =>
      DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

  @override
  RoutesState build() {
    _lifecycleListener = AppLifecycleListener(
      onPause: _onAppPaused,
      onHide: _onAppPaused,
      onDetach: _onAppDetached,
      onResume: _onAppResumed,
    );

    ref.onDispose(() {
      _lifecycleListener?.dispose();
      _syncTimer?.cancel();
      _connSub?.cancel();
      _fcmSub?.cancel();
      _fcmTokenRefreshSub?.cancel();
    });

    // Cargar cola de la base de datos local SQLite de inmediato al arrancar el provider
    Future.microtask(() => _reloadQueuesFromDb());

    return RoutesState(selectedDate: _todayString());
  }

  void _onAppPaused() {
    _handleBackgroundOrExit();
  }

  void _onAppDetached() {
    _handleBackgroundOrExit();
  }

  void _handleBackgroundOrExit() {
    final inMemoryPending = state.totalPendingSyncCount;
    if (inMemoryPending > 0) {
      debugPrint('🔔 [RoutesNotifier] App pausada/cerrada con $inMemoryPending pendientes en memoria. Mostrando notificación...');
      LocalNotificationService.showPendingSyncNotification(
        pendingCount: inMemoryPending,
      );
      return;
    }

    // Por seguridad, verificar si hay registros en la base de datos local SQLite
    _db.getPendingActions().then((actions) {
      _db.getPendingPhotos().then((photos) {
        final total = actions.length + photos.length;
        if (total > 0) {
          debugPrint('🔔 [RoutesNotifier] App pausada/cerrada con $total pendientes en SQLite. Mostrando notificación...');
          LocalNotificationService.showPendingSyncNotification(
            pendingCount: total,
          );
        }
      });
    });
  }

  void _onAppResumed() {
    debugPrint('🔔 [RoutesNotifier] App reanudada en primer plano.');
    // Al regresar a la app, cancelar la notificación inmediatamente porque el usuario ya está adentro
    LocalNotificationService.cancelPendingSyncNotification();

    if (state.totalPendingSyncCount > 0 && state.isOnline) {
      debugPrint(
          '🔔 [RoutesNotifier] Conexión disponible al reanudar: sincronizando cola pendiente...');
      unawaited(syncPendingQueueAndRefreshDay());
    }
  }

  void _updatePendingSyncNotification() {
    final pending = state.totalPendingSyncCount;
    if (pending <= 0) {
      LocalNotificationService.cancelPendingSyncNotification();
    } else {
      // Si la app está en primer plano (resumed), nunca mostrar la notificación en la barra
      final isResumed = WidgetsBinding.instance.lifecycleState ==
          AppLifecycleState.resumed;
      if (isResumed) {
        LocalNotificationService.cancelPendingSyncNotification();
      }
    }
  }

  // ===========================================================================
  // INICIALIZACIÓN, SESIÓN Y LISTENERS (CONECTIVIDAD + FCM actualizar_dia)
  // ===========================================================================

  Future<void> initializeModule(
      {String? fallbackEmail, String? fallbackPassword}) async {
    if (_isInitialized && state.dayPackage != null) {
      // Refrescar cola y sincronizar al volver a abrir la pantalla
      await _reloadQueuesFromDb();
      unawaited(syncPendingQueueAndRefreshDay());
      return;
    }
    _isInitialized = true;

    state = state.copyWith(isLoading: true, clearAuthError: true);

    // 1. Cargar estado local inmediatamente para trabajar con o sin señal
    await _reloadQueuesFromDb();
    final cachedPkg = await _db.getDayPackage(state.selectedDate) ??
        await _db.getLatestDayPackage();
    final cachedClients = await _db.searchCachedClients('');
    final cachedCatalog = await _db.getCachedCatalog();

    if (cachedPkg != null) {
      state = state.copyWith(
        dayPackage: cachedPkg,
        catalog:
            cachedPkg.catalogo.isNotEmpty ? cachedPkg.catalogo : cachedCatalog,
        clients: cachedClients,
      );
    } else if (cachedCatalog.isNotEmpty || cachedClients.isNotEmpty) {
      state = state.copyWith(
        catalog: cachedCatalog,
        clients: cachedClients,
      );
    }

    // 2. Configurar listeners de red y FCM
    await _setupConnectivityAndFcmListeners();

    // 3. Autenticar o renovar token con las credenciales guardadas en sesión
    final hasSession = await _ensureAuthenticatedSession(
      fallbackEmail: fallbackEmail,
      fallbackPassword: fallbackPassword,
    );

    if (hasSession && state.isOnline) {
      // Regla: "Actualizar el paquete del día (a=dia) después de vaciar la cola, no antes"
      await syncPendingQueueAndRefreshDay(forceRefreshDay: true);
      unawaited(loadClientsFromServer());
      unawaited(loadCatalogFromServer());
    }

    state = state.copyWith(isLoading: false);
  }

  Future<void> _setupConnectivityAndFcmListeners() async {
    _connSub?.cancel();
    final connectivity = Connectivity();
    final initialConn = await connectivity.checkConnectivity();
    final online = !initialConn.contains(ConnectivityResult.none);
    state = state.copyWith(isOnline: online);

    _connSub = connectivity.onConnectivityChanged.listen((results) async {
      final nowOnline = !results.contains(ConnectivityResult.none);
      final wasOffline = !state.isOnline;
      state = state.copyWith(isOnline: nowOnline);
      if (nowOnline && wasOffline) {
        await syncPendingQueueAndRefreshDay(forceRefreshDay: true);
      }
    });

    // Timer periódico cada 15 s con señal (Regla: "ej. cada 15 s con señal o al hacer una acción")
    // y actualización automática cada 10 min (Regla página 22: "que la app pida el día cada 10 min con señal por si un push se pierde")
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!state.isOnline || state.isSyncing) return;

      if (state.totalPendingSyncCount > 0) {
        syncPendingQueueAndRefreshDay();
      } else {
        final now = DateTime.now();
        if (_lastPeriodicDayRefresh == null ||
            now.difference(_lastPeriodicDayRefresh!).inMinutes >= 10) {
          _lastPeriodicDayRefresh = now;
          syncPendingQueueAndRefreshDay(forceRefreshDay: true);
        }
      }
    });

    // Push FCM: { "tipo": "actualizar_dia", "idRuta": "812", "fecha": "2026-09-28", "motivo": "ruta" }
    _fcmSub?.cancel();
    _fcmSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final tipo = message.data['tipo']?.toString();
      if (tipo == 'actualizar_dia') {
        final motivo = message.data['motivo']?.toString() ?? 'ruta';
        debugPrint('Push FCM actualizar_dia recibido (motivo: $motivo)');
        // Regla: "si hay acciones en la cola, primero enviarlas; luego a=dia y refrescar la pantalla"
        await syncPendingQueueAndRefreshDay(forceRefreshDay: true);
      } else if (tipo == 'aviso') {
        // Ronda 54: Push de avisos de la plataforma { "tipo": "aviso", "id": "...", "nivel": "...", "categoria": "..." }
        // La app solo lo muestra (trae notification visible); no debe tratarlo como cambio de ruta ni pedir a=dia.
        debugPrint(
            'Push FCM aviso de plataforma recibido (id: ${message.data['id']}, nivel: ${message.data['nivel']})');
      }
    });

    // Actualizar token FCM cuando cambie (a=fcm)
    _fcmTokenRefreshSub?.cancel();
    _fcmTokenRefreshSub =
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (_api.token != null && _api.token!.isNotEmpty && state.isOnline) {
        try {
          await _api.updateFcm(newToken);
        } catch (_) {}
      }
    });
  }

  Future<bool> _ensureAuthenticatedSession({
    String? fallbackEmail,
    String? fallbackPassword,
    bool forceNewToken = false,
  }) async {
    try {
      // 1. Si no forzamos renovación, revisar si ya tenemos un token activo en MarkApiClient
      if (!forceNewToken) {
        if (_api.token != null && _api.token!.isNotEmpty) {
          final clientSession = MarkApiClient.instance.currentSession;
          if (clientSession != null) {
            state = state.copyWith(
              session: clientSession,
              requiresManualAuth: false,
              clearAuthError: true,
            );
            return true;
          }
        }

        final savedToken = await _secureStorage.read(key: 'driver_api_token');
        final savedSessionStr =
            await _secureStorage.read(key: 'driver_api_session');
        if (savedToken != null && savedToken.length >= 16) {
          _api.setToken(savedToken);
          if (savedSessionStr != null && savedSessionStr.isNotEmpty) {
            try {
              final savedSession = DriverSession.fromJson(
                jsonDecode(savedSessionStr) as Map<String, dynamic>,
              );
              state = state.copyWith(
                session: savedSession,
                requiresManualAuth: false,
                clearAuthError: true,
              );
            } catch (_) {}
          }
          // Si estamos online, validar con a=yo (ping)
          if (state.isOnline) {
            try {
              final freshSession = await _api.pingYo();
              await _secureStorage.write(
                key: 'driver_api_session',
                value: jsonEncode(freshSession.toJson()),
              );
              state = state.copyWith(
                session: freshSession,
                requiresManualAuth: false,
                clearAuthError: true,
              );
              return true;
            } on DriverApiException catch (e) {
              if (!e.isUnauthorized) {
                return true; // Error de red temporal, seguir con sesión local
              }
              // Si dio 401, continuar abajo para pedir token nuevo con credenciales de sesión
            } catch (_) {
              return true; // Sin red, usar sesión en caché
            }
          } else {
            return true;
          }
        }
      }

      // 2. Obtener credenciales guardadas en sesión (driver_email/driver_password o session_token)
      String? email =
          fallbackEmail ?? await _secureStorage.read(key: 'driver_email');
      String? password =
          fallbackPassword ?? await _secureStorage.read(key: 'driver_password');

      if (email == null ||
          password == null ||
          email.isEmpty ||
          password.isEmpty) {
        final sessionTokenStr = await _secureStorage.read(key: 'session_token');
        if (sessionTokenStr != null && sessionTokenStr.isNotEmpty) {
          try {
            final map = jsonDecode(sessionTokenStr) as Map<String, dynamic>;
            email = (email == null || email.isEmpty)
                ? map['email']?.toString() ?? map['userName']?.toString()
                : email;
            password = (password == null || password.isEmpty)
                ? map['password']?.toString()
                : password;
          } catch (_) {}
        }
      }

      if (email != null &&
          email.isNotEmpty &&
          password != null &&
          password.isNotEmpty) {
        return await loginWithCredentials(email, password);
      }

      // Si no hay credenciales y no hay red pero hay paquete en caché, dejar trabajar offline
      if (!state.isOnline && state.dayPackage != null) {
        return false;
      }

      state = state.copyWith(
        requiresManualAuth: true,
        authError:
            'Ingrese su usuario y contraseña de chofer para conectar con el servidor de operación.',
      );
      return false;
    } catch (e) {
      debugPrint('Error en _ensureAuthenticatedSession: $e');
      return false;
    }
  }

  Future<bool> loginWithCredentials(String usuario, String password) async {
    state = state.copyWith(isLoading: true, clearAuthError: true);
    try {
      String deviceLabel = 'Android Device';
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final android = await deviceInfo.androidInfo;
          deviceLabel =
              '${android.manufacturer} ${android.model} / Android ${android.version.release}';
        } else if (Platform.isIOS) {
          final ios = await deviceInfo.iosInfo;
          deviceLabel = '${ios.name} / iOS ${ios.systemVersion}';
        }
      } catch (_) {}

      String fcmToken = '';
      try {
        fcmToken = await FirebaseMessaging.instance.getToken() ?? '';
      } catch (_) {}

      final session = await _api.login(
        usuario: usuario.trim(),
        password: password,
        dispositivo: deviceLabel,
        appVersion: '1.0.1',
        fcm: fcmToken,
      );

      await _secureStorage.write(key: 'driver_email', value: usuario.trim());
      await _secureStorage.write(key: 'driver_password', value: password);
      await _secureStorage.write(key: 'driver_api_token', value: session.token);
      await _secureStorage.write(
        key: 'driver_api_session',
        value: jsonEncode(session.toJson()),
      );

      state = state.copyWith(
        isLoading: false,
        session: session,
        requiresManualAuth: false,
        clearAuthError: true,
      );

      // Al recuperar sesión (ej. tras HTTP 401), enviar la cola pendiente con el token nuevo y luego bajar el día
      unawaited(syncPendingQueueAndRefreshDay(forceRefreshDay: true));
      return true;
    } on DriverApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        requiresManualAuth: true,
        authError: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        authError:
            'Sin conexión al servidor de rutas. Trabajando en modo local sin señal.',
      );
      return false;
    }
  }

  // ===========================================================================
  // SINCRONIZACIÓN DE COLA Y PAQUETE DEL DÍA (a=foto → a=acciones → a=dia)
  // ===========================================================================

  Future<void> _reloadQueuesFromDb() async {
    final pendingAct = await _db.getPendingActions();
    final rejectedAct = await _db.getRejectedActions();
    final pendingPho = await _db.getPendingPhotos();
    final syncedOrders = await _db.getSyncedOrders();
    state = state.copyWith(
      pendingActions: pendingAct,
      rejectedActions: rejectedAct,
      pendingPhotos: pendingPho,
      syncedOrders: syncedOrders,
    );
    _updatePendingSyncNotification();
  }

  Future<void> changeDate(String newDate) async {
    final isDifferentDate = state.selectedDate != newDate;
    // Limpiar el paquete en memoria inmediatamente si cambió la fecha para no parpadear la ruta anterior
    state = state.copyWith(
      selectedDate: newDate,
      isLoading: true,
      clearDayPackage: isDifferentDate,
    );
    final localPkg = await _db.getDayPackage(newDate);
    if (localPkg != null && state.selectedDate == newDate) {
      state = state.copyWith(dayPackage: localPkg);
    }
    await syncPendingQueueAndRefreshDay(forceRefreshDay: true);
    state = state.copyWith(isLoading: false);
  }

  Future<void> syncPendingQueueAndRefreshDay({
    bool forceRefreshDay = false,
    bool isUserInitiated = false,
  }) async {
    if (state.isSyncing) return;

    // Respetar backoff por HTTP 429 (60 segundos)
    if (_rateLimitUntil != null && DateTime.now().isBefore(_rateLimitUntil!)) {
      return;
    }

    await _reloadQueuesFromDb();
    if (!state.isOnline) return;

    if (_api.token == null || _api.token!.isEmpty) {
      final ok = await _ensureAuthenticatedSession();
      if (!ok) return;
    }

    state = state.copyWith(isSyncing: true);
    final List<ServerNotice> collectedNotices = [];

    try {
      // 1. SUBIR FOTOS Y FIRMAS PENDIENTES PRIMERO (Regla: "Fotos: una cola aparte; se suben antes que las acciones que las usan")
      final photos = await _db.getPendingPhotos();
      for (final photo in photos) {
        try {
          final uploaded = await _api.uploadPhoto(
            uuid: photo.uuid,
            tipo: photo.tipo,
            filePath: photo.filePath,
          );
          if (uploaded) {
            await _db.markPhotoUploaded(photo.uuid);
          }
        } on DriverApiException catch (e) {
          if (e.isUnauthorized) {
            await _handleUnauthorizedDuringSync();
            return;
          }
          if (e.isRateLimited) {
            _rateLimitUntil = DateTime.now().add(const Duration(seconds: 60));
            return;
          }
        } catch (e) {
          debugPrint('Error subiendo foto ${photo.uuid}: $e');
          break; // Sin señal estable, reintentar después
        }
      }

      // 2. ENVIAR ACCIONES EN ORDEN ESTRICTO DE CREACIÓN (Lotes de hasta 200)
      final pending = await _db.getPendingActions(limit: 200);
      if (pending.isNotEmpty) {
        // Filtrar acciones cuyas fotos aún no terminaron de subir para no provocar FOTO_PENDIENTE innecesario,
        // pero conservando el orden estricto del lote hasta la primera que dependa de una foto no subida.
        final List<QueuedAction> readyBatch = [];
        for (final act in pending) {
          final reqPhotos = act.requiredPhotoUuids;
          if (reqPhotos.isNotEmpty) {
            final allUp = await _db.arePhotosUploaded(reqPhotos);
            if (!allUp) {
              break; // Detener el lote aquí para nunca reordenar acciones posteriores
            }
          }
          readyBatch.add(act);
        }

        if (readyBatch.isNotEmpty) {
          final payloads = readyBatch.map((a) => a.payload).toList();
          final resultados = await _api.sendActions(payloads);

          for (final res in resultados) {
            final uuid = (res['uuid'] ?? '').toString();
            if (uuid.isEmpty) continue;
            final estado = (res['estado'] ?? '').toString();
            final rawAvisos = (res['avisos'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .map(ServerNotice.fromJson)
                .toList();

            collectedNotices.addAll(rawAvisos);

            if (estado == 'aplicada' || estado == 'repetida') {
              await _db.removeAction(uuid);
              final origAct =
                  readyBatch.where((a) => a.uuid == uuid).firstOrNull;
              _applyServerActionResultToMemory(res, originalAction: origAct);
            } else if (estado == 'rechazada') {
              await _db.markActionRejected(uuid, rawAvisos);
            } else if (estado == 'reintentar') {
              await _db.markActionRetry(uuid, rawAvisos);
            }
          }
        }
      }

      await _reloadQueuesFromDb();

      // 3. ACTUALIZAR PAQUETE DEL DÍA (a=dia) DESPUÉS DE VACIAR LA COLA, NO ANTES
      final needsDayRefresh = forceRefreshDay ||
          collectedNotices.any((n) =>
              n.codigo == 'RUTA' ||
              n.codigo == 'PARADA' ||
              n.codigo == 'GUIA' ||
              n.codigo == 'GUIA_RUTA' ||
              n.codigo == 'CLIENTE_UNIDO' ||
              n.codigo == 'CLIENTE_DESCARTADO');

      if (state.pendingActions.isEmpty &&
          (needsDayRefresh || state.dayPackage == null || state.dayPackage?.fecha != state.selectedDate)) {
        final targetDate = state.selectedDate;
        final huellas = await _db.getSavedRouteHuellas();
        final freshPkg = await _api.fetchDayPackage(
          fecha: targetDate,
          huellas: huellas,
        );
        final savedPkg = await _db.saveDayPackage(freshPkg);
        _lastPeriodicDayRefresh = DateTime.now();
        if (state.selectedDate == targetDate && (savedPkg.fecha.isEmpty || savedPkg.fecha == targetDate)) {
          state = state.copyWith(
            dayPackage: savedPkg,
            catalog:
                savedPkg.catalogo.isNotEmpty ? savedPkg.catalogo : state.catalog,
            lastSyncTime: DateFormat('HH:mm:ss').format(DateTime.now()),
          );
        }
      } else if (state.pendingActions.isEmpty) {
        state = state.copyWith(
          lastSyncTime: DateFormat('HH:mm:ss').format(DateTime.now()),
        );
      }

      if (collectedNotices.isNotEmpty) {
        state = state.copyWith(recentNotices: collectedNotices);
        if (collectedNotices.any((n) =>
            n.codigo == 'CLIENTE_UNIDO' ||
            n.codigo == 'CLIENTE_DESCARTADO' ||
            n.codigo == 'CLIENTE_BAJA')) {
          unawaited(loadClientsFromServer());
        }
      }
    } on DriverApiException catch (e) {
      if (e.isUnauthorized) {
        await _handleUnauthorizedDuringSync();
      } else if (e.isRateLimited) {
        _rateLimitUntil = DateTime.now().add(const Duration(seconds: 60));
        if (isUserInitiated) {
          state = state.copyWith(
            recentNotices: [
              ServerNotice(nivel: 'aviso', codigo: '429', texto: e.message),
            ],
          );
        }
      } else {
        // En caso de HTTP 500 u otro error de servidor durante sincronización en segundo plano:
        // No saturar la UI con alertas emergentes continuas y aplicar backoff de 45 segundos.
        debugPrint('Sync diferido por HTTP ${e.statusCode}: ${e.message}');
        _rateLimitUntil = DateTime.now().add(const Duration(seconds: 45));
        if (isUserInitiated) {
          state = state.copyWith(
            recentNotices: [
              ServerNotice(
                  nivel: 'error',
                  codigo: 'HTTP_${e.statusCode}',
                  texto: e.message),
            ],
          );
        }
      }
    } catch (e) {
      debugPrint('Sync diferido (modo offline): $e');
    } finally {
      state = state.copyWith(isSyncing: false);
      _updatePendingSyncNotification();
    }
  }

  Future<void> _handleUnauthorizedDuringSync() async {
    state = state.copyWith(isSyncing: false);
    // Intentar renovar el token automáticamente con las credenciales guardadas sin borrar la cola
    final renewed = await _ensureAuthenticatedSession(forceNewToken: true);
    if (renewed) {
      await syncPendingQueueAndRefreshDay();
    } else {
      state = state.copyWith(requiresManualAuth: true);
    }
  }

  void _applyServerActionResultToMemory(Map<String, dynamic> res,
      {QueuedAction? originalAction}) {
    // 1. Procesar Pedido confirmado por el servidor (Ronda 31)
    final isPedido = (originalAction?.tipo == 'pedido') ||
        (res['pedido'] is Map<String, dynamic>) ||
        (res['avisos'] is List &&
            (res['avisos'] as List)
                .any((a) => a is Map && a['codigo']?.toString() == 'PEDIDO'));

    if (isPedido) {
      final pedidoJson = res['pedido'] is Map<String, dynamic>
          ? res['pedido'] as Map<String, dynamic>
          : <String, dynamic>{};
      final rawUuid = (res['uuid'] ?? originalAction?.uuid ?? '').toString();
      final fallbackRef =
          rawUuid.length >= 8 ? 'APP-${rawUuid.substring(0, 8)}' : 'APP-PEDIDO';
      final payload = originalAction?.payload ?? {};

      // Obtener nombre del cliente
      String clienteNombre = (pedidoJson['cliente'] ?? '').toString();
      final int? idClie = pedidoJson['idCliente'] != null
          ? int.tryParse(pedidoJson['idCliente'].toString())
          : (payload['idCliente'] != null
              ? int.tryParse(payload['idCliente'].toString())
              : null);
      final String clienteUuid = (payload['clienteUuid'] ?? '').toString();

      if (clienteNombre.isEmpty && idClie != null && idClie > 0) {
        final found = state.clients.where((c) => c.id == idClie).firstOrNull;
        if (found != null) clienteNombre = found.nombre;
      }
      if (clienteNombre.isEmpty && clienteUuid.isNotEmpty) {
        final found =
            state.clients.where((c) => c.localUuid == clienteUuid).firstOrNull;
        if (found != null) clienteNombre = found.nombre;
      }
      if (clienteNombre.isEmpty) {
        final avisosList = (res['avisos'] as List<dynamic>? ?? []);
        for (final a in avisosList) {
          if (a is Map && a['codigo'] == 'PEDIDO') {
            final txt = (a['texto'] ?? '').toString();
            final match = RegExp(r'Pedido de (.*?) para', caseSensitive: false)
                .firstMatch(txt);
            if (match != null) {
              clienteNombre = match.group(1)?.trim() ?? '';
              break;
            }
          }
        }
      }
      if (clienteNombre.isEmpty) clienteNombre = 'Cliente';

      final List<dynamic> lineas = pedidoJson['lineas'] is List<dynamic>
          ? (pedidoJson['lineas'] as List<dynamic>)
          : (payload['lineas'] is List<dynamic>
              ? (payload['lineas'] as List<dynamic>)
              : []);
      final int totalLineasCount = pedidoJson['lineas'] is int
          ? (pedidoJson['lineas'] as int)
          : (int.tryParse(pedidoJson['lineas']?.toString() ?? '') ??
              lineas.length);

      final String fecha =
          (pedidoJson['fecha'] ?? payload['fecha'] ?? 'Próxima visita')
              .toString();
      final String refCode =
          (pedidoJson['referencia'] ?? fallbackRef).toString();
      final bool porAprobar = (pedidoJson['porAprobar'] == true) ||
          (clienteUuid.isNotEmpty && idClie == null);

      final orderToSave = SyncedOrder(
        referencia: refCode,
        idCliente: idClie,
        cliente: clienteNombre,
        fecha: fecha,
        totalLineas: totalLineasCount > 0 ? totalLineasCount : lineas.length,
        porAprobar: porAprobar,
        sincronizadoHora:
            DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
        rawLineas: lineas,
      );

      final existingIndex =
          state.syncedOrders.indexWhere((o) => o.referencia == refCode);
      if (existingIndex < 0) {
        state = state.copyWith(
          syncedOrders: [orderToSave, ...state.syncedOrders],
        );
      } else {
        final updatedList = List<SyncedOrder>.from(state.syncedOrders);
        updatedList[existingIndex] = orderToSave;
        state = state.copyWith(syncedOrders: updatedList);
      }
      unawaited(_db.saveSyncedOrder(orderToSave));
    }

    // 2. Procesar Cliente nuevo confirmado por el servidor (Ronda 31: {id, codigo, nombre, porAprobar: true})
    if (res['cliente'] is Map<String, dynamic>) {
      final clieJson = res['cliente'] as Map<String, dynamic>;
      final serverId = int.tryParse((clieJson['id'] ?? '').toString()) ?? 0;
      final serverCodigo = (clieJson['codigo'] ?? '').toString();
      final serverNombre = (clieJson['nombre'] ?? '').toString();
      final origUuid = originalAction?.uuid ?? '';
      final tempCode = origUuid.isNotEmpty
          ? 'APP-${origUuid.substring(0, origUuid.length > 6 ? 6 : origUuid.length).toUpperCase()}'
          : '';

      if (serverId > 0 || serverCodigo.isNotEmpty) {
        // Eliminar registro provisional huérfano de SQLite
        unawaited(_db.deleteProvisionalClient(
          nombre: serverNombre,
          codigo: tempCode.isNotEmpty ? tempCode : null,
          localUuid: origUuid.isNotEmpty ? origUuid : null,
        ));

        // Reemplazar o actualizar en memoria el cliente provisional por el del servidor
        bool replaced = false;
        final updatedClients = <RouteClient>[];
        for (final c in state.clients) {
          final isMatch = (origUuid.isNotEmpty && c.localUuid == origUuid) ||
              (tempCode.isNotEmpty && c.codigo == tempCode) ||
              (serverNombre.isNotEmpty &&
                  c.nombre.toLowerCase().trim() ==
                      serverNombre.toLowerCase().trim());

          if (isMatch) {
            if (!replaced) {
              updatedClients.add(c.copyWith(
                id: serverId > 0 ? serverId : c.id,
                codigo: serverCodigo.isNotEmpty ? serverCodigo : c.codigo,
                nombre: serverNombre.isNotEmpty ? serverNombre : c.nombre,
              ));
              replaced = true;
            }
          } else {
            updatedClients.add(c);
          }
        }
        state = state.copyWith(clients: updatedClients);
        unawaited(_db.saveClients(updatedClients));
      }
    }

    final pkg = state.dayPackage;
    if (pkg == null) return;

    // Actualizar guías confirmadas por el servidor (guias[])
    final guiasList = (res['guias'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final visitaMap = res['visita'] is Map<String, dynamic>
        ? res['visita'] as Map<String, dynamic>
        : null;

    if (guiasList.isEmpty && visitaMap == null) return;

    final Map<int, Map<String, dynamic>> updatesById = {};
    for (final g in guiasList) {
      final id = int.tryParse((g['idGuia'] ?? '').toString()) ?? 0;
      if (id > 0) updatesById[id] = g;
    }
    if (visitaMap != null) {
      final id = int.tryParse((visitaMap['idGuia'] ?? '').toString()) ?? 0;
      if (id > 0) {
        final resultado = (visitaMap['resultado'] ?? '').toString();
        updatesById[id] = {
          'idGuia': id,
          'estado': resultado == 'incidencia' ? 8 : 4,
          'estadoTexto': resultado == 'venta'
              ? 'Visitada (Venta)'
              : (resultado == 'sin_venta'
                  ? 'Visitada (Sin venta)'
                  : 'Incidencia'),
        };
      }
    }

    final updatedRoutes = pkg.rutas.map((route) {
      final updatedStops = route.paradas.map((stop) {
        final updRecoger = stop.recoger.map((g) {
          final u = updatesById[g.idGuia];
          if (u == null) return g;
          final st =
              int.tryParse((u['estado'] ?? g.estado).toString()) ?? g.estado;
          return g.copyWith(
            estado: st,
            estadoTexto:
                (u['estadoTexto'] ?? GuiaItem.estadoLabel(st)).toString(),
            unsyncedLocal: false,
          );
        }).toList();

        final updEntregar = stop.entregar.map((g) {
          final u = updatesById[g.idGuia];
          if (u == null) return g;
          final st =
              int.tryParse((u['estado'] ?? g.estado).toString()) ?? g.estado;
          return g.copyWith(
            estado: st,
            estadoTexto:
                (u['estadoTexto'] ?? GuiaItem.estadoLabel(st)).toString(),
            unsyncedLocal: false,
          );
        }).toList();

        return stop.copyWith(
          recoger: updRecoger,
          entregar: updEntregar,
          unsyncedLocal: false,
        );
      }).toList();

      return route.copyWith(paradas: updatedStops);
    }).toList();

    final updatedPkg = pkg.copyWith(rutas: updatedRoutes);
    state = state.copyWith(dayPackage: updatedPkg);
    unawaited(_db.saveDayPackage(updatedPkg));
  }

  void clearRecentNotices() {
    state = state.copyWith(recentNotices: const []);
  }

  Future<void> dismissRejected(String uuid) async {
    await _db.dismissRejectedAction(uuid);
    await _reloadQueuesFromDb();
  }

  // ===========================================================================
  // GPS DEL TELÉFONO (LECTURA FRESCA MÁX 30S, TIMEOUT 5S SIN BLOQUEAR)
  // ===========================================================================

  /// Regla del documento:
  /// "pedir una lectura fresca al hacer cada acción (máximo 30 s de antigüedad),
  /// mandar prec (metros) y no bloquear la acción si tarda más de 5 s: mandar sin posición."
  Future<Position?> getFreshPositionNonBlocking() async {
    try {
      final now = DateTime.now();
      if (state.lastKnownPosition != null &&
          state.lastPositionTime != null &&
          now.difference(state.lastPositionTime!).inSeconds <= 30) {
        return state.lastKnownPosition;
      }

      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 5));

      state = state.copyWith(
        lastKnownPosition: pos,
        lastPositionTime: DateTime.now(),
      );
      return pos;
    } catch (_) {
      // No bloquear la acción si tarda > 5 s o falla el GPS
      return state.lastKnownPosition;
    }
  }

  /// Actualiza la posición GPS actual en tiempo real para refrescar distancias reactivas
  void updatePosition(Position pos) {
    state = state.copyWith(
      lastKnownPosition: pos,
      lastPositionTime: DateTime.now(),
    );
  }

  /// Calcula la distancia en metros entre el chofer y un punto (cliente / parada)
  double? calculateDistanceMeters(double targetLat, double targetLng) {
    final pos = state.lastKnownPosition;
    if (pos == null || (targetLat == 0 && targetLng == 0)) return null;
    return Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      targetLat,
      targetLng,
    );
  }

  // ===========================================================================
  // REGISTRO DE FOTOS Y FIRMAS LOCALES
  // ===========================================================================

  Future<String> registerLocalPhoto(File imageFile) async {
    final photoUuid = _uuid.v4();
    await _db.saveAndEnqueuePhoto(
      uuid: photoUuid,
      tipo: 1, // 1 = foto (1280px JPG 75)
      sourceFile: imageFile,
    );
    await _reloadQueuesFromDb();
    return photoUuid;
  }

  Future<String> registerLocalSignature(Uint8List pngBytes) async {
    final sigUuid = _uuid.v4();
    await _db.saveAndEnqueuePhoto(
      uuid: sigUuid,
      tipo: 2, // 2 = firma (PNG B/N)
      rawBytes: pngBytes,
    );
    await _reloadQueuesFromDb();
    return sigUuid;
  }

  // ===========================================================================
  // CONSTRUCCIÓN Y EJECUCIÓN DE LAS 11 ACCIONES DEL DOCUMENTO
  // (salida, llegada, recojo, descarga, carga, entrega, incidencia, fin, visita, pedido, cliente)
  // ===========================================================================

  Future<ActionExecutionResult> _enqueueAndExecuteAction({
    required String tipo,
    int? idRuta,
    int? idParada,
    required Map<String, dynamic> customFields,
  }) async {
    final actionUuid = _uuid.v4();
    final pos = await getFreshPositionNonBlocking();

    final payload = <String, dynamic>{
      'uuid': actionUuid,
      'tipo': tipo,
      if (idRuta != null) 'idRuta': idRuta,
      if (idParada != null) 'idParada': idParada,
      ...customFields,
      if (pos != null) ...{
        'lat': double.parse(pos.latitude.toStringAsFixed(6)),
        'lng': double.parse(pos.longitude.toStringAsFixed(6)),
        'prec': pos.accuracy.round(),
      },
      'fecHor': _nowLocalTimestamp(),
    };

    // 1. Guardar en SQLite antes de mostrarla como hecha
    await _db.enqueueAction(
      uuid: actionUuid,
      tipo: tipo,
      idRuta: idRuta,
      idParada: idParada,
      payload: payload,
    );

    // 2. Actualizar estado optimista local para que el chofer vea su avance al instante
    _applyOptimisticUpdate(
      tipo: tipo,
      idRuta: idRuta,
      idParada: idParada,
      payload: payload,
    );

    await _reloadQueuesFromDb();

    // 3. Si hay señal, intentar sincronizar de inmediato y devolver el resultado real del servidor
    if (state.isOnline) {
      await syncPendingQueueAndRefreshDay();
      // Revisar si esta acción quedó rechazada (ej. BULTOS o PENDIENTES o CODIGO)
      final rejected =
          state.rejectedActions.where((a) => a.uuid == actionUuid).toList();
      if (rejected.isNotEmpty) {
        final act = rejected.first;
        final needsDiff = act.avisos.any(
          (n) => n.codigo == 'BULTOS' || n.codigo == 'PENDIENTES',
        );
        return ActionExecutionResult(
          queuedOrApplied: false,
          estado: 'rechazada',
          avisos: act.avisos,
          needsConfirmDifference: needsDiff,
        );
      }

      final stillPending =
          state.pendingActions.where((a) => a.uuid == actionUuid).toList();
      if (stillPending.isEmpty) {
        return ActionExecutionResult(
          queuedOrApplied: true,
          estado: 'aplicada',
          avisos: state.recentNotices,
        );
      }
    }

    return const ActionExecutionResult(
      queuedOrApplied: true,
      estado: 'en_cola',
      avisos: [
        ServerNotice(
          nivel: 'info',
          codigo: 'COLA_LOCAL',
          texto:
              'Guardado en el teléfono. Se enviará automáticamente al tener señal.',
        ),
      ],
    );
  }

  void _applyOptimisticUpdate({
    required String tipo,
    int? idRuta,
    int? idParada,
    required Map<String, dynamic> payload,
  }) {
    final pkg = state.dayPackage;
    if (pkg == null || idRuta == null) return;

    final updatedRoutes = pkg.rutas.map((route) {
      if (route.idRuta != idRuta) return route;

      if (tipo == 'salida') {
        // salida solo pasa la ruta de programada (0) a activa (1).
        // Una salida repetida no reabre una ruta terminada (2 o 3).
        if (route.isFinalizada) {
          return route;
        }
        return route.copyWith(
          operacional: true,
          operationalRoute: 1,
        );
      }
      if (tipo == 'fin') {
        // fin solo de activa (1) a terminada (2).
        // Un fin que llega después de que el motor la cerró (3) no cambia el estado.
        final newOpRoute = route.isCerradaPorMotor ? 3 : 2;
        return route.copyWith(
          operacional: false,
          operationalRoute: newOpRoute,
        );
      }

      if (tipo == 'descarga' || tipo == 'carga') {
        final ids = (payload['idGuias'] as List<dynamic>? ?? [])
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .toSet();
        final codes = (payload['codigos'] as List<dynamic>? ?? [])
            .map((e) => LabelCode.normalizeScannedCode(e.toString()))
            .toSet();

        bool matchesGuia(GuiaItem g) {
          if (ids.contains(g.idGuia)) return true;
          for (final etq in g.etiquetas) {
            if (codes.contains(LabelCode.normalizeScannedCode(etq.codigo))) {
              return true;
            }
          }
          return false;
        }

        final newState = tipo == 'descarga' ? 2 : 3;
        final newLabel = tipo == 'descarga' ? 'En CEDI' : 'En reparto';

        final updDescargar = route.cediDescargar
            .map((g) => matchesGuia(g)
                ? g.copyWith(
                    estado: newState,
                    estadoTexto: newLabel,
                    unsyncedLocal: true)
                : g)
            .toList();
        final updCargar = route.cediCargar
            .map((g) => matchesGuia(g)
                ? g.copyWith(
                    estado: newState,
                    estadoTexto: newLabel,
                    unsyncedLocal: true)
                : g)
            .toList();

        final updStops = route.paradas.map((stop) {
          return stop.copyWith(
            recoger: stop.recoger
                .map((g) => matchesGuia(g)
                    ? g.copyWith(
                        estado: newState,
                        estadoTexto: newLabel,
                        unsyncedLocal: true)
                    : g)
                .toList(),
            entregar: stop.entregar
                .map((g) => matchesGuia(g)
                    ? g.copyWith(
                        estado: newState,
                        estadoTexto: newLabel,
                        unsyncedLocal: true)
                    : g)
                .toList(),
          );
        }).toList();

        return route.copyWith(
          cediDescargar: updDescargar,
          cediCargar: updCargar,
          paradas: updStops,
        );
      }

      final targetGuiaId = int.tryParse((payload['idGuia'] ?? '').toString());

      final updatedStops = route.paradas.map((stop) {
        if (idParada != null && stop.idParada != idParada) return stop;

        if (tipo == 'llegada') {
          return stop.copyWith(
            visitada: true,
            visitaOrigen: stop.visitaOrigen == 'gps' ? 'ambos' : 'app',
            unsyncedLocal: true,
          );
        }

        if (tipo == 'recojo' && targetGuiaId != null) {
          final updRecoger = stop.recoger.map((g) {
            if (g.idGuia != targetGuiaId) return g;
            // Mensajería (modalidad 1) pasa directo a En reparto (3)
            final nextSt = g.modalidad == 1 ? 3 : 1;
            return g.copyWith(
              estado: nextSt,
              estadoTexto: GuiaItem.estadoLabel(nextSt),
              unsyncedLocal: true,
            );
          }).toList();
          final allDone = updRecoger.every((g) => g.estado >= 1) &&
              stop.entregar.every((g) => g.estado == 4);
          return stop.copyWith(
            visitada: allDone ? true : stop.visitada,
            visitaOrigen: stop.visitaOrigen ?? 'app',
            recoger: updRecoger,
            unsyncedLocal: true,
          );
        }

        if (tipo == 'entrega' && targetGuiaId != null) {
          final updEntregar = stop.entregar.map((g) {
            if (g.idGuia != targetGuiaId) return g;
            return g.copyWith(
              estado: 4,
              estadoTexto: 'Entregada',
              unsyncedLocal: true,
            );
          }).toList();
          final allDone = stop.recoger.every((g) => g.estado >= 1) &&
              updEntregar.every((g) => g.estado == 4);
          return stop.copyWith(
            visitada: allDone ? true : stop.visitada,
            visitaOrigen: stop.visitaOrigen ?? 'app',
            entregar: updEntregar,
            unsyncedLocal: true,
          );
        }

        if (tipo == 'incidencia' && targetGuiaId != null) {
          final updRecoger = stop.recoger.map((g) {
            if (g.idGuia != targetGuiaId) return g;
            return g.copyWith(
              estado: 8,
              estadoTexto: 'Incidencia',
              unsyncedLocal: true,
            );
          }).toList();
          final updEntregar = stop.entregar.map((g) {
            if (g.idGuia != targetGuiaId) return g;
            return g.copyWith(
              estado: 8,
              estadoTexto: 'Incidencia',
              unsyncedLocal: true,
            );
          }).toList();
          return stop.copyWith(
            visitada: true,
            visitaOrigen: stop.visitaOrigen ?? 'app',
            recoger: updRecoger,
            entregar: updEntregar,
            unsyncedLocal: true,
          );
        }

        if (tipo == 'visita') {
          final motivo = int.tryParse((payload['motivo'] ?? '').toString());
          final isIncidence = motivo != null &&
              (motivo == 31 || motivo == 32 || motivo == 36 || motivo == 37);
          final nextSt = isIncidence ? 8 : 4;
          final nextTxt = isIncidence ? 'Incidencia' : 'Visitada';
          final updEntregar = stop.entregar.map((g) {
            if (targetGuiaId != null && g.idGuia != targetGuiaId) return g;
            return g.copyWith(
              estado: nextSt,
              estadoTexto: nextTxt,
              unsyncedLocal: true,
            );
          }).toList();
          return stop.copyWith(
            visitada: true,
            visitaOrigen: stop.visitaOrigen ?? 'app',
            entregar: updEntregar,
            unsyncedLocal: true,
          );
        }

        return stop;
      }).toList();

      return route.copyWith(paradas: updatedStops);
    }).toList();

    final updatedPkg = pkg.copyWith(rutas: updatedRoutes);
    state = state.copyWith(dayPackage: updatedPkg);
    unawaited(_db.saveDayPackage(updatedPkg));
  }

  // --- Métodos públicos para cada tipo de acción ---

  /// 1. SALIDA (Inicia ruta)
  Future<ActionExecutionResult> registrarSalida(int idRuta) {
    return _enqueueAndExecuteAction(
      tipo: 'salida',
      idRuta: idRuta,
      customFields: const {},
    );
  }

  /// 2. LLEGADA (Marca visita en la parada sin tocar guías)
  Future<ActionExecutionResult> registrarLlegada({
    required int idRuta,
    required int idParada,
  }) {
    return _enqueueAndExecuteAction(
      tipo: 'llegada',
      idRuta: idRuta,
      idParada: idParada,
      customFields: const {},
    );
  }

  /// 3. RECOJO
  Future<ActionExecutionResult> registrarRecojo({
    required int idRuta,
    required int idParada,
    required int idGuia,
    int? bultos,
    List<String> codigos = const [],
    List<String> fotosUuids = const [],
    String nota = '',
    bool confirmarDiferencia = false,
  }) {
    return _enqueueAndExecuteAction(
      tipo: 'recojo',
      idRuta: idRuta,
      idParada: idParada,
      customFields: {
        'idGuia': idGuia,
        if (bultos != null) 'bultos': bultos,
        if (codigos.isNotEmpty) 'codigos': codigos,
        'fotos': fotosUuids,
        if (nota.trim().isNotEmpty) 'nota': nota.trim(),
        if (confirmarDiferencia) 'confirmarDiferencia': true,
      },
    );
  }

  /// 4. DESCARGA EN CEDI (Por lote)
  Future<ActionExecutionResult> registrarDescargaCedi({
    required int idRuta,
    List<int> idGuias = const [],
    List<String> codigos = const [],
  }) {
    return _enqueueAndExecuteAction(
      tipo: 'descarga',
      idRuta: idRuta,
      customFields: {
        if (idGuias.isNotEmpty) 'idGuias': idGuias,
        if (codigos.isNotEmpty) 'codigos': codigos,
      },
    );
  }

  /// 5. CARGA EN CEDI (Por lote)
  Future<ActionExecutionResult> registrarCargaCedi({
    required int idRuta,
    List<int> idGuias = const [],
    List<String> codigos = const [],
  }) {
    return _enqueueAndExecuteAction(
      tipo: 'carga',
      idRuta: idRuta,
      customFields: {
        if (idGuias.isNotEmpty) 'idGuias': idGuias,
        if (codigos.isNotEmpty) 'codigos': codigos,
      },
    );
  }

  /// 6. ENTREGA
  Future<ActionExecutionResult> registrarEntrega({
    required int idRuta,
    required int idParada,
    required int idGuia,
    String? codigo,
    List<String> fotosUuids = const [],
    String? nombreRecibe,
    String? firmaUuid,
    List<String> codigosEtiquetas = const [],
    String nota = '',
  }) {
    return _enqueueAndExecuteAction(
      tipo: 'entrega',
      idRuta: idRuta,
      idParada: idParada,
      customFields: {
        'idGuia': idGuia,
        if (codigo != null && codigo.trim().isNotEmpty) 'codigo': codigo.trim(),
        if (fotosUuids.isNotEmpty) 'fotos': fotosUuids,
        if (nombreRecibe != null && nombreRecibe.trim().isNotEmpty)
          'nombre': nombreRecibe.trim(),
        if (firmaUuid != null && firmaUuid.isNotEmpty) 'firma': firmaUuid,
        if (codigosEtiquetas.isNotEmpty) 'codigos': codigosEtiquetas,
        if (nota.trim().isNotEmpty) 'nota': nota.trim(),
      },
    );
  }

  /// 7. INCIDENCIA
  Future<ActionExecutionResult> registrarIncidencia({
    required int idRuta,
    required int idParada,
    required int idGuia,
    required int motivo,
    String nota = '',
    List<String> fotosUuids = const [],
  }) {
    return _enqueueAndExecuteAction(
      tipo: 'incidencia',
      idRuta: idRuta,
      idParada: idParada,
      customFields: {
        'idGuia': idGuia,
        'motivo': motivo,
        if (nota.trim().isNotEmpty) 'nota': nota.trim(),
        'fotos': fotosUuids,
      },
    );
  }

  /// 8. FIN DE RUTA
  Future<ActionExecutionResult> registrarFinRuta({
    required int idRuta,
    bool confirmarDiferencia = false,
  }) {
    return _enqueueAndExecuteAction(
      tipo: 'fin',
      idRuta: idRuta,
      customFields: {
        if (confirmarDiferencia) 'confirmarDiferencia': true,
      },
    );
  }

  /// 9. VISITA (Rutas Diarias modalidad 2 y Fijas modalidad 3, o fuera de ruta con idClie)
  Future<ActionExecutionResult> registrarVisita({
    required int idRuta,
    int? idParada,
    int? idGuia,
    int? idClie,
    List<Map<String, dynamic>> ventas = const [],
    List<Map<String, dynamic>> pedido = const [],
    String? fechaPedido,
    int? motivo,
    String nota = '',
    List<String> fotosUuids = const [],
  }) {
    return _enqueueAndExecuteAction(
      tipo: 'visita',
      idRuta: idRuta,
      idParada: idParada,
      customFields: {
        if (idGuia != null && idGuia > 0) 'idGuia': idGuia,
        if (idClie != null && idClie > 0) 'idClie': idClie,
        if (ventas.isNotEmpty) 'ventas': ventas,
        if (pedido.isNotEmpty) 'pedido': pedido,
        if (fechaPedido != null && fechaPedido.isNotEmpty)
          'fechaPedido': fechaPedido,
        if (motivo != null) 'motivo': motivo,
        if (nota.trim().isNotEmpty) 'nota': nota.trim(),
        if (fotosUuids.isNotEmpty) 'fotos': fotosUuids,
      },
    );
  }

  /// 10. ALTA DE CLIENTE NUEVO (Ronda 31: tipo = "cliente")
  /// Devuelve el uuid de la acción cliente para poder ligarlo en `clienteUuid` de un pedido sin señal
  Future<String> registrarClienteNuevo({
    required String nombre,
    String telefono = '',
    String contacto = '',
    String notas = '',
    required Map<String, String> direccion,
    double? latOverride,
    double? lngOverride,
  }) async {
    final clientActionUuid = _uuid.v4();
    final pos = await getFreshPositionNonBlocking();
    final lat = latOverride ?? pos?.latitude;
    final lng = lngOverride ?? pos?.longitude;

    final payload = <String, dynamic>{
      'uuid': clientActionUuid,
      'tipo': 'cliente',
      'nombre': nombre.trim(),
      if (telefono.trim().isNotEmpty) 'telefono': telefono.trim(),
      if (contacto.trim().isNotEmpty) 'contacto': contacto.trim(),
      if (notas.trim().isNotEmpty) 'notas': notas.trim(),
      if (lat != null && lng != null) ...{
        'lat': double.parse(lat.toStringAsFixed(6)),
        'lng': double.parse(lng.toStringAsFixed(6)),
        if (pos != null) 'prec': pos.accuracy.round(),
      },
      if (direccion.values.any((v) => v.trim().isNotEmpty))
        'direccion': direccion,
      'fecHor': _nowLocalTimestamp(),
    };

    // Guardar en la cola (siempre antes de cualquier pedido ligado)
    await _db.enqueueAction(
      uuid: clientActionUuid,
      tipo: 'cliente',
      payload: payload,
    );

    // Guardar cliente provisional en caché local para que ya se le puedan levantar pedidos sin señal
    final provisionalClient = RouteClient(
      id: 0,
      codigo: 'APP-${clientActionUuid.substring(0, 6).toUpperCase()}',
      nombre: nombre.trim(),
      contacto: contacto.trim(),
      telefono: telefono.trim(),
      direccion: direccion.values.where((v) => v.trim().isNotEmpty).join(', '),
      lat: lat ?? 0.0,
      lng: lng ?? 0.0,
      obs: notas.trim(),
      porAprobar: true,
      localUuid: clientActionUuid,
    );
    await _db.saveClients([provisionalClient]);
    final updatedClients = await _db.searchCachedClients('');
    state = state.copyWith(clients: updatedClients);

    await _reloadQueuesFromDb();
    if (state.isOnline) {
      unawaited(syncPendingQueueAndRefreshDay());
    }
    return clientActionUuid;
  }

  /// 11. PEDIDO SUELTO (Ronda 31: tipo = "pedido", sin idRuta)
  Future<ActionExecutionResult> registrarPedidoSuelto({
    int? idCliente,
    String? clienteUuid,
    String? clienteNombre,
    required List<Map<String, dynamic>> lineas,
    String? fecha,
  }) {
    return _enqueueAndExecuteAction(
      tipo: 'pedido',
      customFields: {
        if (idCliente != null && idCliente > 0) 'idCliente': idCliente,
        if ((idCliente == null || idCliente <= 0) &&
            clienteUuid != null &&
            clienteUuid.isNotEmpty)
          'clienteUuid': clienteUuid,
        if (clienteNombre != null && clienteNombre.isNotEmpty)
          'cliente': clienteNombre,
        'lineas': lineas,
        if (fecha != null && fecha.isNotEmpty) 'fecha': fecha,
      },
    );
  }

  // ===========================================================================
  // CONSULTA DE CLIENTES Y CATÁLOGO (a=clientes, a=catalogo)
  // ===========================================================================

  Future<void> loadClientsFromServer({String query = ''}) async {
    if (!state.isOnline) {
      final cached = await _db.searchCachedClients(query);
      state = state.copyWith(clients: cached);
      return;
    }

    try {
      final List<RouteClient> allParsed = [];
      int? desde = 0;
      do {
        final data =
            await _api.fetchClients(q: query, desde: desde ?? 0, limite: 500);
        final rawList = data['clientes'];
        if (rawList is List) {
          final parsed = rawList
              .whereType<Map<String, dynamic>>()
              .map(RouteClient.fromJson)
              .toList();
          allParsed.addAll(parsed);
        }
        // Solo paginar todo si se está bajando la lista completa (sin query de búsqueda)
        if (query.isEmpty && data['siguiente'] != null) {
          desde = int.tryParse(data['siguiente'].toString());
        } else {
          desde = null;
        }
      } while (desde != null);

      if (query.isEmpty) {
        // Sincronización completa: limpia clientes unidos o descartados en la oficina
        await _db.syncFullClientsCache(allParsed);
      } else {
        await _db.saveClients(allParsed);
      }

      final cached = await _db.searchCachedClients(query);
      state = state.copyWith(clients: cached);

      unawaited(loadCatalogFromServer());
    } catch (e) {
      debugPrint('Usando caché local de clientes: $e');
      final cached = await _db.searchCachedClients(query);
      state = state.copyWith(clients: cached);
    }
  }

  Future<void> loadCatalogFromServer() async {
    if (!state.isOnline) {
      final cached = await _db.getCachedCatalog();
      if (cached.isNotEmpty) {
        state = state.copyWith(catalog: cached);
      }
      return;
    }
    try {
      final cat = await _api.fetchCatalog();
      if (cat.isNotEmpty) {
        await _db.saveCatalog(cat);
        state = state.copyWith(catalog: cat);
      }
    } catch (e) {
      debugPrint('Error actualizando catálogo: $e');
      final cached = await _db.getCachedCatalog();
      if (cached.isNotEmpty) {
        state = state.copyWith(catalog: cached);
      }
    }
  }

  Future<void> deleteSyncedOrder(String referencia) async {
    final updated =
        state.syncedOrders.where((o) => o.referencia != referencia).toList();
    state = state.copyWith(syncedOrders: updated);
    await _db.deleteSyncedOrder(referencia);
  }
}
