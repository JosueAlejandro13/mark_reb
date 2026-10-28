import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:mark_v3/pages/Custodia_/custodia_page.dart';
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  /// ID único para la notificación de sincronización pendiente
  static const int pendingSyncNotificationId = 8801;

  /// ID para el recordatorio programado cuando la app permanezca cerrada
  static const int pendingSyncReminderId = 8802;

  /// IDs únicos para Custodia y Rondines (Ronda 151)
  static const int custodiaCheckinReminderId = 9901;
  static const int custodiaCheckinWarningId = 9902;
  static const int custodiaStatusRequestId = 9903;
  static const int custodiaMessageId = 9904;
  static const int custodiaVencidoAlertId = 9905;

  /// Canal Android para sincronización offline
  static const AndroidNotificationChannel _syncChannel =
      AndroidNotificationChannel(
    'offline_sync_alerts_v1',
    'Sincronización de Datos Offline',
    description:
        'Notificaciones para alertar cuando hay datos pendientes de sincronizar con el servidor.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Canal Android para Custodia y Rondines (Ronda 151)
  static const AndroidNotificationChannel _custodiaChannel =
      AndroidNotificationChannel(
    'custodia_alerts_v1',
    'Custodia y Rondines',
    description:
        'Alertas de check-in periódico, solicitudes de estatus del monitorista y mensajes de custodia.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Callback global para cuando el usuario presiona la notificación
  static void Function()? onNotificationTapCallback;

  /// Inicializar el plugin de notificaciones locales
  static Future<void> initialize({
    void Function()? onNotificationTap,
  }) async {
    if (_isInitialized) return;

    if (onNotificationTap != null) {
      onNotificationTapCallback = onNotificationTap;
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint(
            '[LocalNotificationService] Notificación presionada: ${details.payload}');
        if (details.payload != null &&
            (details.payload == 'custodia' ||
                details.payload!.startsWith('custodia'))) {
          try {
            Get.to(() => const CustodiaPage());
          } catch (e) {
            debugPrint('[LocalNotificationService] Error navegando a Custodia: $e');
          }
        }
        onNotificationTapCallback?.call();
      },
    );

    // Crear canales en Android
    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_syncChannel);
      await androidPlugin.createNotificationChannel(_custodiaChannel);
      // Solicitar permisos en Android 13+ si aún no se han concedido
      await androidPlugin.requestNotificationsPermission();
    }

    _isInitialized = true;
    debugPrint(
        '[LocalNotificationService] Inicializado correctamente con canal de Custodia.');
  }

  /// Solicitar permisos de notificación explícitamente (Android 13+)
  static Future<bool> requestPermission() async {
    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final notifGranted = await androidPlugin.requestNotificationsPermission();
      return notifGranted ?? false;
    }
    return true;
  }

  // ==========================================
  // --- MÓDULO CUSTODIA Y RONDINES (Ronda 151) ---
  // ==========================================

  /// Programa un aviso local para checkin.venceTs (Ronda 151)
  /// "La app programa un aviso local para checkin.venceTs. Si vence, el monitorista recibe una alerta y la app recibe un push."
  static Future<void> scheduleCustodiaCheckinReminder({
    required int venceTs,
    required int cadaMin,
  }) async {
    if (venceTs <= 0) return;
    if (!_isInitialized) await initialize();

    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diffSec = venceTs - nowSec;
    if (diffSec <= 0) {
      await showCustodiaVencidoNotification();
      return;
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _custodiaChannel.id,
      _custodiaChannel.name,
      channelDescription: _custodiaChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF0284C7),
      playSound: true,
      enableVibration: true,
      ongoing: false,
      autoCancel: true,
      styleInformation: const BigTextStyleInformation(
        'Tu tiempo de reporte ha expirado. Realiza tu check-in de inmediato para evitar alertas al monitorista.',
        contentTitle: '⚠️ Check-in de Custodia requerido',
        summaryText: 'Custodia Activa',
      ),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      final targetDateTime =
          tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, venceTs * 1000);

      // Aviso exacto al vencimiento
      await _notificationsPlugin.zonedSchedule(
        custodiaCheckinReminderId,
        '⚠️ Check-in de Custodia requerido',
        'Tu tiempo de reporte ha expirado. Realiza tu check-in para reportarte.',
        targetDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'custodia_checkin_expired',
      );

      // Advertencia preventiva 2 min antes si el tiempo restante lo permite
      if (diffSec > 150) {
        final warningDateTime =
            targetDateTime.subtract(const Duration(minutes: 2));
        if (warningDateTime.isAfter(tz.TZDateTime.now(tz.local))) {
          await _notificationsPlugin.zonedSchedule(
            custodiaCheckinWarningId,
            '⏳ Check-in de Custodia por vencer',
            'Tu próximo check-in vence en 2 minutos. Ingresa tu clave para reportarte.',
            warningDateTime,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: 'custodia_checkin_warning',
          );
        }
      }
      debugPrint(
          '[LocalNotificationService] Check-in programado para $targetDateTime (faltan ${diffSec}s)');
    } catch (e) {
      debugPrint(
          '[LocalNotificationService] Error al programar aviso de check-in: $e');
    }
  }

  /// Cancela los recordatorios de check-in de custodia tras enviar el reporte
  static Future<void> cancelCustodiaCheckinReminder() async {
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.cancel(custodiaCheckinReminderId);
      await _notificationsPlugin.cancel(custodiaCheckinWarningId);
      debugPrint(
          '[LocalNotificationService] Recordatorios de check-in cancelados.');
    } catch (e) {
      debugPrint(
          '[LocalNotificationService] Error al cancelar recordatorios: $e');
    }
  }

  /// Muestra una notificación inmediata cuando el monitorista envía una solicitud de estatus
  static Future<void> showCustodiaSolicitudNotification({
    required String texto,
    required String plazo,
    int? plazoTs,
  }) async {
    if (!_isInitialized) await initialize();

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _custodiaChannel.id,
      _custodiaChannel.name,
      channelDescription: _custodiaChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFD97706),
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      ongoing: false,
      autoCancel: true,
      styleInformation: BigTextStyleInformation(
        'El monitorista solicita tu estatus: "$texto"\nPlazo: $plazo. Contesta realizando tu check-in.',
        contentTitle: '⚠️ Solicitud de Estatus (Custodia)',
        summaryText: 'Alerta de Monitorista',
      ),
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notificationsPlugin.show(
      custodiaStatusRequestId,
      '⚠️ Solicitud de Estatus (Custodia)',
      'El monitorista solicita tu estatus: "$texto" (Plazo: $plazo)',
      notificationDetails,
      payload: 'custodia_solicitud',
    );
  }

  /// Muestra notificación inmediata cuando llega un mensaje de texto del monitorista
  static Future<void> showCustodiaMensajeNotification({
    required String quien,
    required String texto,
  }) async {
    if (!_isInitialized) await initialize();

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _custodiaChannel.id,
      _custodiaChannel.name,
      channelDescription: _custodiaChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF0284C7),
      playSound: true,
      enableVibration: true,
      ongoing: false,
      autoCancel: true,
      styleInformation: BigTextStyleInformation(
        texto,
        contentTitle: '💬 Mensaje de $quien',
        summaryText: 'Custodia Chat',
      ),
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notificationsPlugin.show(
      custodiaMessageId,
      '💬 Mensaje de $quien',
      texto,
      notificationDetails,
      payload: 'custodia_chat',
    );
  }

  /// Alerta cuando el check-in está vencido
  static Future<void> showCustodiaVencidoNotification() async {
    if (!_isInitialized) await initialize();

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _custodiaChannel.id,
      _custodiaChannel.name,
      channelDescription: _custodiaChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFDC2626),
      playSound: true,
      enableVibration: true,
      ongoing: false,
      autoCancel: true,
      styleInformation: const BigTextStyleInformation(
        'Tu reporte periódico está vencido. Ingresa tu clave para reportarte inmediatamente.',
        contentTitle: '⚠️ Check-in Vencido',
        summaryText: 'Alerta Crítica',
      ),
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notificationsPlugin.show(
      custodiaVencidoAlertId,
      '⚠️ Check-in Vencido',
      'Tu reporte periódico está vencido. Ingresa tu clave para reportarte.',
      notificationDetails,
      payload: 'custodia_vencido',
    );
  }

  // ==========================================
  // --- MÓDULO SINCRONIZACIÓN OFFLINE ---
  // ==========================================

  /// Muestra o actualiza la notificación de registros pendientes sin subir
  static Future<void> showPendingSyncNotification({
    required int pendingCount,
    bool? isOnline,
    int delaySeconds = 15,
  }) async {
    if (pendingCount <= 0) {
      await cancelPendingSyncNotification();
      return;
    }

    if (!_isInitialized) {
      await initialize();
    }

    final String countLabel =
        pendingCount == 1 ? '1 registro' : '$pendingCount registros';

    final String title = pendingCount == 1
        ? '1 registro pendiente de sincronizar'
        : '$pendingCount registros pendientes de sincronizar';

    const String body =
        'Tus datos están guardados en el dispositivo y esperan conexión para enviarse al servidor.';

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _syncChannel.id,
      _syncChannel.name,
      channelDescription: _syncChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFEA580C),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Mark Sincronización',
      ),
      ongoing: false,
      autoCancel: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      if (delaySeconds > 0) {
        await _notificationsPlugin.zonedSchedule(
          pendingSyncNotificationId,
          title,
          body,
          tz.TZDateTime.now(tz.local).add(Duration(seconds: delaySeconds)),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } else {
        await _notificationsPlugin.show(
          pendingSyncNotificationId,
          title,
          body,
          notificationDetails,
          payload: 'pending_sync_payload',
        );
      }
    } catch (e) {
      debugPrint(
          ' [LocalNotificationService] Error al programar a los $delaySeconds s: $e');
      await _notificationsPlugin.show(
        pendingSyncNotificationId,
        title,
        body,
        notificationDetails,
        payload: 'pending_sync_payload',
      );
    }

    try {
      const String reminderTitle = 'Tus datos siguen guardados';
      final String reminderBody = pendingCount == 1
          ? 'Hay 1 registro pendiente de enviar al servidor. Abre Mark V3 cuando tengas conexión.'
          : 'Hay $pendingCount registros pendientes de enviar al servidor. Abre Mark V3 cuando tengas conexión.';

      final AndroidNotificationDetails reminderAndroidDetails =
          AndroidNotificationDetails(
        _syncChannel.id,
        _syncChannel.name,
        channelDescription: _syncChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFFEA580C),
        styleInformation: BigTextStyleInformation(
          reminderBody,
          contentTitle: reminderTitle,
          summaryText: 'Recordatorio Mark',
        ),
        ongoing: false,
        autoCancel: true,
      );

      final NotificationDetails reminderNotificationDetails =
          NotificationDetails(
        android: reminderAndroidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        pendingSyncReminderId,
        reminderTitle,
        reminderBody,
        tz.TZDateTime.now(tz.local).add(const Duration(minutes: 2)),
        reminderNotificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint(
          ' [LocalNotificationService] No se pudo programar recordatorio futuro: $e');
    }

    debugPrint(
        ' [LocalNotificationService] Notificación mostrada: $pendingCount pendientes.');
  }

  /// Cancela la notificación de sincronización pendiente cuando la cola quede en 0
  static Future<void> cancelPendingSyncNotification() async {
    if (!_isInitialized) return;
    await _notificationsPlugin.cancel(pendingSyncNotificationId);
    await _notificationsPlugin.cancel(pendingSyncReminderId);
    debugPrint(
        ' [LocalNotificationService] Notificaciones y recordatorios cancelados.');
  }
}
