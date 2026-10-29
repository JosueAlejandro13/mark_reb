import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:mark_v3/models/Custodia_/custodia_models.dart';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';
import 'package:mark_v3/services/ConnectionCustodia_/custodia_local_db.dart';
import 'package:mark_v3/services/local_notification_service.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class CustodiaState {
  final bool isLoading;
  final bool isSubmitting;
  final bool isSyncing;
  final bool isOnline;
  final int pendingActionsCount;
  final String? lastSyncTime;
  final List<QueuedAction> rejectedActions;
  final String? errorMessage;
  final CustodiaDataResponse? data;
  final int selectedTab; // 0 = Servicios, 1 = Rondines
  final int? activeServicioId;
  final int? activeRondinId;
  final int secondsRemaining; // Segundos restantes para check-in
  final bool isVencido;

  const CustodiaState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.isSyncing = false,
    this.isOnline = true,
    this.pendingActionsCount = 0,
    this.lastSyncTime,
    this.rejectedActions = const [],
    this.errorMessage,
    this.data,
    this.selectedTab = 0,
    this.activeServicioId,
    this.activeRondinId,
    this.secondsRemaining = 0,
    this.isVencido = false,
  });

  CustodiaServicio? get activeServicio {
    if (data == null || data!.servicios.isEmpty) return null;
    if (activeServicioId != null) {
      final found = data!.servicios.where((s) => s.id == activeServicioId).firstOrNull;
      if (found != null) return found;
    }
    return data!.servicios.first;
  }

  RondinDia? get activeRondin {
    if (data == null || data!.rondines.isEmpty) return null;
    if (activeRondinId != null) {
      final found = data!.rondines.where((r) => r.idRondinDia == activeRondinId).firstOrNull;
      if (found != null) return found;
    }
    return data!.rondines.first;
  }

  CustodiaState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    bool? isSyncing,
    bool? isOnline,
    int? pendingActionsCount,
    String? lastSyncTime,
    List<QueuedAction>? rejectedActions,
    String? errorMessage,
    bool clearError = false,
    bool clearData = false,
    CustodiaDataResponse? data,
    int? selectedTab,
    int? activeServicioId,
    int? activeRondinId,
    int? secondsRemaining,
    bool? isVencido,
  }) {
    return CustodiaState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSyncing: isSyncing ?? this.isSyncing,
      isOnline: isOnline ?? this.isOnline,
      pendingActionsCount: pendingActionsCount ?? this.pendingActionsCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      rejectedActions: rejectedActions ?? this.rejectedActions,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      data: clearData ? null : (data ?? this.data),
      selectedTab: selectedTab ?? this.selectedTab,
      activeServicioId: activeServicioId ?? this.activeServicioId,
      activeRondinId: activeRondinId ?? this.activeRondinId,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      isVencido: isVencido ?? this.isVencido,
    );
  }
}

final custodiaProvider =
    NotifierProvider<CustodiaNotifier, CustodiaState>(CustodiaNotifier.new);

class CustodiaNotifier extends Notifier<CustodiaState> {
  final MarkApiClient _api = MarkApiClient.instance;
  final CustodiaLocalDb _db = CustodiaLocalDb.instance;
  final Uuid _uuid = const Uuid();
  Timer? _countdownTimer;
  Timer? _syncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  int _lastMarkedLeidoId = 0;
  static const String _cacheKey = 'custodia_cached_data_v1';

  static String _nowTimestamp() =>
      DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

  @override
  CustodiaState build() {
    ref.onDispose(() {
      _countdownTimer?.cancel();
      _syncTimer?.cancel();
      _connSub?.cancel();
    });

    _setupConnectivityAndTimer();
    Future.microtask(() => cargarCustodia());
    return const CustodiaState(isLoading: true);
  }

  Future<void> _setupConnectivityAndTimer() async {
    _connSub?.cancel();
    final connectivity = Connectivity();
    try {
      final initialConn = await connectivity.checkConnectivity();
      final online = !initialConn.contains(ConnectivityResult.none);
      state = state.copyWith(isOnline: online);
    } catch (_) {}

    _connSub = connectivity.onConnectivityChanged.listen((results) async {
      final nowOnline = !results.contains(ConnectivityResult.none);
      final wasOffline = !state.isOnline;
      state = state.copyWith(isOnline: nowOnline);
      if (nowOnline && wasOffline) {
        await syncCustodiaQueue();
      }
    });

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!state.isOnline || state.isSyncing) return;
      if (state.pendingActionsCount > 0) {
        syncCustodiaQueue();
      }
    });

    await _actualizarConteoCola();
  }

  /// Limpia completamente el estado de custodia en memoria (al cerrar sesión o cambiar de perfil)
  void reset() {
    _countdownTimer?.cancel();
    _syncTimer?.cancel();
    _connSub?.cancel();
    _lastMarkedLeidoId = 0;
    LocalNotificationService.cancelCustodiaCheckinReminder();
    state = const CustodiaState(isLoading: false);
  }

  void setSelectedTab(int index) {
    state = state.copyWith(selectedTab: index);
  }

  void setActiveServicio(int id) {
    state = state.copyWith(activeServicioId: id);
    _recalcularCountdown();
  }

  void setActiveRondin(int id) {
    state = state.copyWith(activeRondinId: id);
  }

  Future<void> _actualizarConteoCola() async {
    try {
      final pending = await _db.getPendingActions();
      final pendingPhotos = await _db.getPendingPhotos();
      final rejected = await _db.getRejectedActions();

      state = state.copyWith(
        pendingActionsCount: pending.length + pendingPhotos.length,
        rejectedActions: rejected,
      );
    } catch (_) {}
  }

  /// Carga la información de servicios y rondines (a=custodia)
  /// Con soporte Offline-First: Si la red no responde, carga el último paquete local guardado.
  Future<void> cargarCustodia({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    await _actualizarConteoCola();

    // 1. Intentar cargar del servidor si estamos en línea
    if (state.isOnline) {
      try {
        final res = await _api.getCustodia();
        if (res['ok'] == true) {
          final parsed = CustodiaDataResponse.fromJson(res);
          await _guardarCacheLocal(parsed);

          final nowStr = DateFormat('HH:mm:ss').format(DateTime.now());
          state = state.copyWith(
            isLoading: false,
            data: parsed,
            lastSyncTime: nowStr,
            clearError: true,
          );
          _recalcularCountdown();
          _programarNotificacionesLocales(parsed);
          return;
        } else {
          _countdownTimer?.cancel();
          state = state.copyWith(
            isLoading: false,
            errorMessage: res['error']?.toString() ?? 'Error al cargar custodia',
          );
        }
      } catch (e) {
        debugPrint('Fallo al consultar servidor en custodia: $e');
      }
    }

    // 2. Fallback offline: Cargar de SharedPreferences si falló la red o no hay conexión
    final cachedData = await _cargarCacheLocal();
    if (cachedData != null) {
      state = state.copyWith(
        isLoading: false,
        data: cachedData,
        clearError: true,
      );
      _recalcularCountdown();
      _programarNotificacionesLocales(cachedData);
    } else {
      _countdownTimer?.cancel();
      state = state.copyWith(
        isLoading: false,
        errorMessage: state.isOnline
            ? 'Error al cargar custodia'
            : 'Sin conexión a internet. No hay datos locales previos guardados.',
      );
    }
  }

  Future<void> _guardarCacheLocal(CustodiaDataResponse data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data.toJson()));
    } catch (_) {}
  }

  Future<CustodiaDataResponse?> _cargarCacheLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_cacheKey);
      if (str != null && str.isNotEmpty) {
        final map = jsonDecode(str) as Map<String, dynamic>;
        return CustodiaDataResponse.fromJson(map);
      }
    } catch (_) {}
    return null;
  }

  void _programarNotificacionesLocales(CustodiaDataResponse parsed) {
    try {
      final srv = state.activeServicio ?? (parsed.servicios.isNotEmpty ? parsed.servicios.first : null);
      if (srv != null && srv.checkin != null) {
        final chk = srv.checkin!;
        final vTs = chk.venceTs;
        if (vTs != null && vTs > 0 && !chk.vencido) {
          LocalNotificationService.scheduleCustodiaCheckinReminder(
            venceTs: vTs,
            cadaMin: chk.cadaMin,
          );
        }
        if (srv.solicitudes.isNotEmpty) {
          final sol = srv.solicitudes.first;
          LocalNotificationService.showCustodiaSolicitudNotification(
            texto: sol.texto,
            plazo: sol.plazo,
            plazoTs: sol.plazoTs,
          );
        }
      }
      final rondin = state.activeRondin ?? (parsed.rondines.isNotEmpty ? parsed.rondines.first : null);
      if (rondin != null && rondin.solicitudes.isNotEmpty) {
        final sol = rondin.solicitudes.first;
        LocalNotificationService.showCustodiaSolicitudNotification(
          texto: sol.texto,
          plazo: sol.plazo,
          plazoTs: sol.plazoTs,
        );
      }
    } catch (e) {
      // Ignorar en tests o entornos sin servicio nativo
    }
  }

  void _recalcularCountdown() {
    _countdownTimer?.cancel();
    final srv = state.activeServicio;
    final venceTs = srv?.checkin?.venceTs;
    if (venceTs == null || venceTs <= 0) {
      if (state.secondsRemaining != 0 || state.isVencido) {
        state = state.copyWith(secondsRemaining: 0, isVencido: false);
      }
      return;
    }

    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = venceTs - nowSec;

    if (diff <= 0) {
      if (!state.isVencido) {
        LocalNotificationService.showCustodiaVencidoNotification();
      }
      state = state.copyWith(secondsRemaining: 0, isVencido: true);
    } else {
      if (state.isVencido || state.secondsRemaining != diff) {
        state = state.copyWith(secondsRemaining: diff, isVencido: false);
      }

      // Programar timer único al momento exacto de vencimiento.
      // Evita mutar el estado cada segundo para no degradar el rendimiento del mapa nativo.
      _countdownTimer = Timer(Duration(seconds: diff), () {
        if (!state.isVencido) {
          LocalNotificationService.showCustodiaVencidoNotification();
        }
        state = state.copyWith(secondsRemaining: 0, isVencido: true);
      });
    }
  }

  /// Configuración de claves de seguridad y coacción (a=custodiaClaves)
  Future<bool> configurarClaves({
    required String password,
    required String clave,
    required String coaccion,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final res = await _api.configurarCustodiaClaves(
        password: password,
        clave: clave,
        coaccion: coaccion,
      );
      state = state.copyWith(isSubmitting: false);
      if (res['ok'] == true) {
        await cargarCustodia(silent: true);
        return true;
      } else {
        state = state.copyWith(
          errorMessage: res['error']?.toString() ?? 'Error al configurar claves',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Error al configurar claves: $e',
      );
      return false;
    }
  }

  Future<Position?> _obtenerPosicionActual() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );
    } catch (e) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Check-in periódico con clave (cusCheckin)
  /// Regla Ronda 151: Si se ingresa clave de coacción, el servidor contesta
  /// exactamente igual que con la clave buena. La app NO muestra nada distinto ni guarda qué clave se usó.
  /// Se ejecuta 100% Offline-First mediante cola SQLite.
  Future<bool> enviarCheckin({
    int? idServicio,
    int? idRondinDia,
    required String clave,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    final actionUuid = _uuid.v4();
    final timestamp = _nowTimestamp();

    Position? pos;
    try {
      pos = await _obtenerPosicionActual();
    } catch (_) {}

    final action = {
      'uuid': actionUuid,
      'tipo': 'cusCheckin',
      if (idServicio != null && idServicio > 0) 'idServicio': idServicio,
      if (idRondinDia != null && idRondinDia > 0) 'idRondinDia': idRondinDia,
      'clave': clave.trim(),
      'fecHor': timestamp,
      'lat': pos?.latitude ?? 0.0,
      'lng': pos?.longitude ?? 0.0,
      'prec': pos?.accuracy.round() ?? 10,
    };

    // 1. Guardar en SQLite
    await _db.enqueueAction(
      uuid: actionUuid,
      tipo: 'cusCheckin',
      payload: action,
    );

    // 2. Actualización optimista en memoria
    _aplicarCheckinEnMemoria(
      idServicio: idServicio,
      fecHor: timestamp,
    );

    await LocalNotificationService.cancelCustodiaCheckinReminder();
    await _actualizarConteoCola();
    state = state.copyWith(isSubmitting: false);

    // 3. Si hay red, sincronizar en segundo plano
    if (state.isOnline) {
      unawaited(syncCustodiaQueue());
    }

    return true;
  }

  void _aplicarCheckinEnMemoria({int? idServicio, required String fecHor}) {
    final currentData = state.data;
    if (currentData == null) return;

    final updatedServicios = currentData.servicios.map((s) {
      if (idServicio != null && s.id != idServicio) return s;
      final chk = s.checkin;
      if (chk == null) return s;

      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final nextVenceSec = nowSec + (chk.cadaMin * 60);
      final nextVenceDate = DateTime.fromMillisecondsSinceEpoch(nextVenceSec * 1000);
      final nextVenceStr = DateFormat('HH:mm').format(nextVenceDate);

      final updatedChk = chk.copyWith(
        ultimo: DateFormat('HH:mm').format(DateTime.now()),
        vence: nextVenceStr,
        venceTs: nextVenceSec,
        vencido: false,
        pide: false,
      );
      return s.copyWith(checkin: updatedChk);
    }).toList();

    final updatedData = currentData.copyWith(servicios: updatedServicios);
    state = state.copyWith(data: updatedData, isVencido: false);
    _recalcularCountdown();
    _guardarCacheLocal(updatedData);
  }

  /// Alerta crítica de Pánico silencioso (cusPanico)
  /// No pide clave y funciona en cualquier estado del servicio o rondín.
  Future<bool> enviarPanico({
    int? idServicio,
    int? idRondinDia,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    final actionUuid = _uuid.v4();
    final timestamp = _nowTimestamp();

    Position? pos;
    try {
      pos = await _obtenerPosicionActual();
    } catch (_) {}

    final action = {
      'uuid': actionUuid,
      'tipo': 'cusPanico',
      if (idServicio != null && idServicio > 0) 'idServicio': idServicio,
      if (idRondinDia != null && idRondinDia > 0) 'idRondinDia': idRondinDia,
      'fecHor': timestamp,
      'lat': pos?.latitude ?? 0.0,
      'lng': pos?.longitude ?? 0.0,
      'prec': pos?.accuracy.round() ?? 10,
    };

    await _db.enqueueAction(
      uuid: actionUuid,
      tipo: 'cusPanico',
      payload: action,
    );

    await _actualizarConteoCola();
    state = state.copyWith(isSubmitting: false);

    if (state.isOnline) {
      unawaited(syncCustodiaQueue());
    }

    return true;
  }

  /// Enviar mensaje o respuesta rápida al monitorista (cusMensaje)
  Future<bool> enviarMensaje({
    int? idServicio,
    int? idRondinDia,
    String? texto,
    String? rapida,
  }) async {
    if ((texto == null || texto.trim().isEmpty) && (rapida == null || rapida.isEmpty)) {
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    final actionUuid = _uuid.v4();
    final timestamp = _nowTimestamp();

    final action = {
      'uuid': actionUuid,
      'tipo': 'cusMensaje',
      if (idServicio != null && idServicio > 0) 'idServicio': idServicio,
      if (idRondinDia != null && idRondinDia > 0) 'idRondinDia': idRondinDia,
      if (texto != null && texto.trim().isNotEmpty) 'texto': texto.trim(),
      if (rapida != null && rapida.isNotEmpty) 'rapida': rapida,
      'fecHor': timestamp,
    };

    await _db.enqueueAction(
      uuid: actionUuid,
      tipo: 'cusMensaje',
      payload: action,
    );

    _aplicarMensajeEnMemoria(
      idServicio: idServicio,
      idRondinDia: idRondinDia,
      texto: texto?.trim() ?? (rapida ?? ''),
      rapida: rapida,
      fecHor: timestamp,
    );

    await _actualizarConteoCola();
    state = state.copyWith(isSubmitting: false);

    if (state.isOnline) {
      unawaited(syncCustodiaQueue());
    }

    return true;
  }

  void _aplicarMensajeEnMemoria({
    int? idServicio,
    int? idRondinDia,
    required String texto,
    String? rapida,
    required String fecHor,
  }) {
    final currentData = state.data;
    if (currentData == null) return;

    final nuevoMensaje = CustodiaMensaje(
      id: DateTime.now().millisecondsSinceEpoch,
      deApp: true,
      mio: true,
      quien: 'Yo',
      texto: texto,
      rapida: rapida,
      fecha: fecHor,
    );

    if (idServicio != null) {
      final updatedServicios = currentData.servicios.map((s) {
        if (s.id != idServicio) return s;
        final nuevosMensajes = List<CustodiaMensaje>.from(s.mensajes)..add(nuevoMensaje);
        return s.copyWith(mensajes: nuevosMensajes);
      }).toList();
      final updatedData = currentData.copyWith(servicios: updatedServicios);
      state = state.copyWith(data: updatedData);
      _guardarCacheLocal(updatedData);
    } else if (idRondinDia != null) {
      final updatedRondines = currentData.rondines.map((r) {
        if (r.idRondinDia != idRondinDia) return r;
        final nuevosMensajes = List<CustodiaMensaje>.from(r.mensajes)..add(nuevoMensaje);
        return r.copyWith(mensajes: nuevosMensajes);
      }).toList();
      final updatedData = currentData.copyWith(rondines: updatedRondines);
      state = state.copyWith(data: updatedData);
      _guardarCacheLocal(updatedData);
    }
  }

  /// Marcar mensajes leídos del monitorista hasta ese id (cusLeido)
  Future<void> marcarMensajesLeidos({
    int? idServicio,
    int? idRondinDia,
    required int hastaId,
  }) async {
    if (hastaId <= _lastMarkedLeidoId) return;
    _lastMarkedLeidoId = hastaId;

    try {
      final actionUuid = _uuid.v4();
      final action = {
        'uuid': actionUuid,
        'tipo': 'cusLeido',
        if (idServicio != null && idServicio > 0) 'idServicio': idServicio,
        if (idRondinDia != null && idRondinDia > 0) 'idRondinDia': idRondinDia,
        'hasta': hastaId,
      };

      await _db.enqueueAction(
        uuid: actionUuid,
        tipo: 'cusLeido',
        idServicio: idServicio,
        idRondin: idRondinDia,
        payload: action,
      );

      await _actualizarConteoCola();

      if (state.isOnline) {
        unawaited(syncCustodiaQueue());
      }
    } catch (_) {}
  }

  /// Subir fotografía y asociarla a la revisión de custodia (cusFoto)
  Future<bool> enviarFoto({
    required int idServicio,
    required int tipoFoto,
    required File file,
    String? texto,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    final photoUuid = _uuid.v4();
    final actionUuid = _uuid.v4();
    final timestamp = _nowTimestamp();

    await _db.saveAndEnqueuePhoto(
      uuid: photoUuid,
      tipo: 1,
      sourceFile: file,
    );

    final action = {
      'uuid': actionUuid,
      'tipo': 'cusFoto',
      'idServicio': idServicio,
      'tipoFoto': tipoFoto,
      'fotos': [photoUuid],
      if (texto != null && texto.trim().isNotEmpty) 'texto': texto.trim(),
      'fecHor': timestamp,
    };

    await _db.enqueueAction(
      uuid: actionUuid,
      tipo: 'cusFoto',
      payload: action,
    );

    await _actualizarConteoCola();
    state = state.copyWith(isSubmitting: false);

    if (state.isOnline) {
      unawaited(syncCustodiaQueue());
    }

    return true;
  }

  /// Marcar llegada o salida en un punto de rondín (rondinPunto)
  /// Opera 100% Offline-First: Guarda primero en SQLite (action_queue),
  /// actualiza la memoria y UI optimísticamente, y sincroniza cuando hay red.
  Future<bool> marcarRondinPunto({
    required int idRondinDia,
    required int idPunto,
    required String momento, // 'llegue' | 'sali'
    String? qr,
    List<String> fotos = const [],
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    final actionUuid = _uuid.v4();
    final timestamp = _nowTimestamp();

    Position? pos;
    try {
      pos = await _obtenerPosicionActual();
    } catch (_) {}

    final action = {
      'uuid': actionUuid,
      'tipo': 'rondinPunto',
      'idRondinDia': idRondinDia,
      'idPunto': idPunto,
      'momento': momento,
      if (qr != null && qr.isNotEmpty) 'qr': qr,
      if (fotos.isNotEmpty) 'fotos': fotos,
      'fecHor': timestamp,
      'lat': pos?.latitude ?? 0.0,
      'lng': pos?.longitude ?? 0.0,
      'prec': pos?.accuracy.round() ?? 10,
    };

    // 1. Guardar siempre en SQLite primero (Offline-First)
    await _db.enqueueAction(
      uuid: actionUuid,
      tipo: 'rondinPunto',
      payload: action,
    );

    // 2. Actualización optimista inmediata en memoria
    _aplicarRondinPuntoEnMemoria(
      idRondinDia: idRondinDia,
      idPunto: idPunto,
      momento: momento,
      fecHor: timestamp,
      lat: pos?.latitude,
      lng: pos?.longitude,
      conQr: qr != null && qr.isNotEmpty,
    );

    await _actualizarConteoCola();
    state = state.copyWith(isSubmitting: false);

    // 3. Si hay red, sincronizar en segundo plano sin bloquear
    if (state.isOnline) {
      unawaited(syncCustodiaQueue());
    }

    return true;
  }

  void _aplicarRondinPuntoEnMemoria({
    required int idRondinDia,
    required int idPunto,
    required String momento,
    required String fecHor,
    double? lat,
    double? lng,
    bool conQr = false,
  }) {
    final currentData = state.data;
    if (currentData == null) return;

    final updatedRondines = currentData.rondines.map((r) {
      if (r.idRondinDia != idRondinDia) return r;

      int nuevosCumplidos = r.cumplidos;
      final updatedPuntos = r.puntos.map((p) {
        // Ronda 151: "un «llegué» en otro punto cierra el anterior sin permanencia"
        if (p.id != idPunto) {
          if (momento == 'llegue' && p.llego && !p.salio && !p.completado) {
            nuevosCumplidos++;
            return p.copyWith(cumplidoDirecto: true);
          }
          return p;
        }

        final nuevoPaso = RondinPaso(
          momento: momento,
          fecha: fecHor,
          lat: lat,
          lng: lng,
          conQr: conQr,
        );
        final nuevosPasos = List<RondinPaso>.from(p.pasos)..add(nuevoPaso);

        // Ronda 151: La permanencia se cuenta entre «llegué» y «salí»
        final bool yaEstabaCompletado = p.completado;
        final bool ahoraCompletado = (p.cumplidoDirecto == true) ||
            (nuevosPasos.any((x) =>
                    x.momento == 'llegue' ||
                    x.momento == 'llegada' ||
                    x.momento == 'llego') &&
                nuevosPasos.any((x) =>
                    x.momento == 'sali' ||
                    x.momento == 'salida' ||
                    x.momento == 'salio'));

        if (!yaEstabaCompletado && ahoraCompletado) {
          nuevosCumplidos++;
        }

        return p.copyWith(
          pasos: nuevosPasos,
          cumplidoDirecto: ahoraCompletado ? true : p.cumplidoDirecto,
        );
      }).toList();

      return r.copyWith(
        puntos: updatedPuntos,
        cumplidos: nuevosCumplidos,
      );
    }).toList();

    final updatedData = currentData.copyWith(rondines: updatedRondines);
    state = state.copyWith(data: updatedData);
    _guardarCacheLocal(updatedData);
  }

  /// Sincroniza la cola local de acciones de custodia y rondines con el servidor
  Future<void> syncCustodiaQueue({bool userInitiated = false}) async {
    if (state.isSyncing) return;
    if (!state.isOnline) {
      if (userInitiated) {
        await _actualizarConteoCola();
      }
      return;
    }

    state = state.copyWith(isSyncing: true);

    try {
      // 1. Subir fotos pendientes si las hubiera
      final pendingPhotos = await _db.getPendingPhotos();
      for (final photo in pendingPhotos) {
        try {
          final photoFile = File(photo.filePath);
          if (!await photoFile.exists()) {
            await _db.markPhotoUploaded(photo.uuid);
            continue;
          }
          final success = await _api.uploadPhoto(
            uuid: photo.uuid,
            tipo: photo.tipo,
            filePath: photo.filePath,
          );
          if (success) {
            await _db.markPhotoUploaded(photo.uuid);
          } else {
            break;
          }
        } catch (_) {
          break;
        }
      }

      // 2. Enviar acciones pendientes en estricto orden FIFO
      final pending = await _db.getPendingActions(limit: 100);
      if (pending.isNotEmpty) {
        final List<QueuedAction> readyBatch = [];
        for (final act in pending) {
          final reqPhotos = act.requiredPhotoUuids;
          if (reqPhotos.isNotEmpty) {
            final allUp = await _db.arePhotosUploaded(reqPhotos);
            if (!allUp) break;
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

            if (estado == 'aplicada' || estado == 'repetida') {
              await _db.removeAction(uuid);
            } else if (estado == 'rechazada') {
              await _db.markActionRejected(uuid, rawAvisos);
            } else if (estado == 'reintentar') {
              await _db.markActionRetry(uuid, rawAvisos);
            }
          }
        }
      }

      // 3. Recargar información actualizada del servidor
      await cargarCustodia(silent: true);

      final nowStr = DateFormat('HH:mm:ss').format(DateTime.now());
      state = state.copyWith(
        isSyncing: false,
        lastSyncTime: nowStr,
      );
    } catch (e) {
      debugPrint('Error en syncCustodiaQueue: $e');
      state = state.copyWith(isSyncing: false);
    } finally {
      await _actualizarConteoCola();
    }
  }

  Future<void> dismissRejectedAction(String uuid) async {
    await _db.dismissRejectedAction(uuid);
    await _actualizarConteoCola();
  }
}
