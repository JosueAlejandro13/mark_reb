import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:mark_v3/models/Custodia_/custodia_models.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:uuid/uuid.dart';

class CustodiaState {
  final bool isLoading;
  final bool isSubmitting;
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
  final Uuid _uuid = const Uuid();
  Timer? _countdownTimer;

  static String _nowTimestamp() =>
      DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

  @override
  CustodiaState build() {
    ref.onDispose(() {
      _countdownTimer?.cancel();
    });

    Future.microtask(() => cargarCustodia());
    return const CustodiaState(isLoading: true);
  }

  /// Limpia completamente el estado de custodia en memoria (al cerrar sesión o cambiar de perfil)
  void reset() {
    _countdownTimer?.cancel();
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

  /// Carga la información de servicios y rondines (a=custodia)
  Future<void> cargarCustodia({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final res = await _api.getCustodia();
      if (res['ok'] == true) {
        final parsed = CustodiaDataResponse.fromJson(res);
        state = state.copyWith(
          isLoading: false,
          data: parsed,
          clearError: true,
        );
        _recalcularCountdown();
      } else {
        _countdownTimer?.cancel();
        state = state.copyWith(
          isLoading: false,
          clearData: true,
          errorMessage: res['error']?.toString() ?? 'Error al cargar custodia',
        );
      }
    } catch (e) {
      _countdownTimer?.cancel();
      state = state.copyWith(
        isLoading: false,
        clearData: true,
        errorMessage: 'Error de conexión: $e',
      );
    }
  }

  void _recalcularCountdown() {
    _countdownTimer?.cancel();
    final srv = state.activeServicio;
    final venceTs = srv?.checkin?.venceTs;
    if (venceTs == null || venceTs <= 0) {
      state = state.copyWith(secondsRemaining: 0, isVencido: false);
      return;
    }

    void tick() {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final diff = venceTs - nowSec;
      if (diff <= 0) {
        state = state.copyWith(secondsRemaining: 0, isVencido: true);
      } else {
        state = state.copyWith(secondsRemaining: diff, isVencido: false);
      }
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
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
        timeLimit: const Duration(seconds: 5),
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
  /// NOTA DE SEGURIDAD (Ronda 151): Si se ingresa clave de coacción, el servidor contesta
  /// exactamente igual que con la clave buena. La app NO muestra nada distinto ni guarda qué clave se usó.
  Future<bool> enviarCheckin({
    int? idServicio,
    int? idRondinDia,
    required String clave,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final pos = await _obtenerPosicionActual();
      final action = {
        'uuid': _uuid.v4(),
        'tipo': 'cusCheckin',
        if (idServicio != null && idServicio > 0) 'idServicio': idServicio,
        if (idRondinDia != null && idRondinDia > 0) 'idRondinDia': idRondinDia,
        'clave': clave.trim(),
        'fecHor': _nowTimestamp(),
        'lat': pos?.latitude ?? 0.0,
        'lng': pos?.longitude ?? 0.0,
        'prec': pos?.accuracy.round() ?? 10,
      };

      final resList = await _api.sendActions([action]);
      state = state.copyWith(isSubmitting: false);

      final firstRes = resList.isNotEmpty ? resList.first : null;
      final estado = firstRes?['estado']?.toString();

      if (estado == 'aplicada' || estado == 'repetida') {
        await cargarCustodia(silent: true);
        return true;
      } else {
        final avisos = firstRes?['avisos'] as List<dynamic>?;
        final errorText = avisos != null && avisos.isNotEmpty
            ? (avisos.first is Map ? avisos.first['texto'] : avisos.first.toString())
            : 'Check-in rechazado por el servidor';
        state = state.copyWith(errorMessage: errorText.toString());
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Error al enviar check-in: $e',
      );
      return false;
    }
  }

  /// Alerta crítica de Pánico silencioso (cusPanico)
  /// No pide clave y funciona en cualquier estado del servicio o rondín.
  Future<bool> enviarPanico({
    int? idServicio,
    int? idRondinDia,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final pos = await _obtenerPosicionActual();
      final action = {
        'uuid': _uuid.v4(),
        'tipo': 'cusPanico',
        if (idServicio != null && idServicio > 0) 'idServicio': idServicio,
        if (idRondinDia != null && idRondinDia > 0) 'idRondinDia': idRondinDia,
        'fecHor': _nowTimestamp(),
        'lat': pos?.latitude ?? 0.0,
        'lng': pos?.longitude ?? 0.0,
        'prec': pos?.accuracy.round() ?? 10,
      };

      await _api.sendActions([action]);
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Error al enviar señal de pánico: $e',
      );
      return false;
    }
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
    try {
      final action = {
        'uuid': _uuid.v4(),
        'tipo': 'cusMensaje',
        if (idServicio != null && idServicio > 0) 'idServicio': idServicio,
        if (idRondinDia != null && idRondinDia > 0) 'idRondinDia': idRondinDia,
        if (texto != null && texto.trim().isNotEmpty) 'texto': texto.trim(),
        if (rapida != null && rapida.isNotEmpty) 'rapida': rapida,
        'fecHor': _nowTimestamp(),
      };

      final resList = await _api.sendActions([action]);
      state = state.copyWith(isSubmitting: false);

      final firstRes = resList.isNotEmpty ? resList.first : null;
      if (firstRes?['estado'] == 'aplicada' || firstRes?['estado'] == 'repetida') {
        await cargarCustodia(silent: true);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Error al enviar mensaje: $e',
      );
      return false;
    }
  }

  /// Marcar mensajes leídos del monitorista hasta ese id (cusLeido)
  Future<void> marcarMensajesLeidos({
    int? idServicio,
    int? idRondinDia,
    required int hastaId,
  }) async {
    try {
      final action = {
        'uuid': _uuid.v4(),
        'tipo': 'cusLeido',
        if (idServicio != null && idServicio > 0) 'idServicio': idServicio,
        if (idRondinDia != null && idRondinDia > 0) 'idRondinDia': idRondinDia,
        'hasta': hastaId,
      };
      await _api.sendActions([action]);
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
    try {
      final photoUuid = _uuid.v4();
      final uploadOk = await _api.uploadPhoto(
        uuid: photoUuid,
        tipo: 1,
        filePath: file.path,
      );
      if (!uploadOk) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'No se pudo subir la fotografía al servidor',
        );
        return false;
      }

      final action = {
        'uuid': _uuid.v4(),
        'tipo': 'cusFoto',
        'idServicio': idServicio,
        'tipoFoto': tipoFoto,
        'fotos': [photoUuid],
        if (texto != null && texto.trim().isNotEmpty) 'texto': texto.trim(),
        'fecHor': _nowTimestamp(),
      };

      await _api.sendActions([action]);
      state = state.copyWith(isSubmitting: false);
      await cargarCustodia(silent: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Error al enviar foto: $e',
      );
      return false;
    }
  }

  /// Marcar llegada o salida en un punto de rondín (rondinPunto)
  Future<bool> marcarRondinPunto({
    required int idRondinDia,
    required int idPunto,
    required String momento, // 'llegue' | 'sali'
    String? qr,
    List<String> fotos = const [],
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final pos = await _obtenerPosicionActual();
      final action = {
        'uuid': _uuid.v4(),
        'tipo': 'rondinPunto',
        'idRondinDia': idRondinDia,
        'idPunto': idPunto,
        'momento': momento,
        if (qr != null && qr.isNotEmpty) 'qr': qr,
        if (fotos.isNotEmpty) 'fotos': fotos,
        'fecHor': _nowTimestamp(),
        'lat': pos?.latitude ?? 0.0,
        'lng': pos?.longitude ?? 0.0,
        'prec': pos?.accuracy.round() ?? 10,
      };

      final resList = await _api.sendActions([action]);
      state = state.copyWith(isSubmitting: false);

      final firstRes = resList.isNotEmpty ? resList.first : null;
      if (firstRes?['estado'] == 'aplicada' || firstRes?['estado'] == 'repetida') {
        await cargarCustodia(silent: true);
        return true;
      } else {
        final avisos = firstRes?['avisos'] as List<dynamic>?;
        final firstAviso =
            avisos != null && avisos.isNotEmpty ? avisos.first : null;
        String errorText = 'Punto no aceptado';
        if (firstAviso is Map) {
          final codigo = firstAviso['codigo']?.toString().toUpperCase();
          final msg = firstAviso['texto']?.toString() ??
              firstAviso['mensaje']?.toString();
          if (msg != null && msg.isNotEmpty) {
            errorText = msg;
          } else if (codigo == 'LEJOS') {
            errorText =
                'Estás fuera de la geocerca del punto y no se validó código QR';
          } else if (codigo == 'QR') {
            errorText =
                'El código QR escaneado no corresponde a este punto de control';
          } else if (codigo == 'PUNTO') {
            errorText =
                'El punto no pertenece al rondín o no respeta el orden estricto';
          } else if (codigo == 'POSICION') {
            errorText = 'No se pudo obtener la posición GPS exacta del teléfono';
          } else if (codigo == 'CUSTODIA') {
            errorText = 'Este rondín no está asignado a tu usuario o ya concluyó';
          }
        } else if (firstAviso != null) {
          errorText = firstAviso.toString();
        }
        state = state.copyWith(errorMessage: errorText);
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Error al marcar punto de rondín: $e',
      );
      return false;
    }
  }
}
