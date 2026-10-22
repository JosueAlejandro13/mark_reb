import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
        onNotificationTapCallback?.call();
      },
    );

    // Crear el canal en Android
    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_syncChannel);
      // Solicitar permisos en Android 13+ si aún no se han concedido
      await androidPlugin.requestNotificationsPermission();
    }

    _isInitialized = true;
    debugPrint('[LocalNotificationService] Inicializado correctamente.');
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

    // Programar la notificación inicial con el margen de 15 segundos
    // a través de AlarmManager para que funcione tanto en segundo plano como si la app se cierra
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

    // Programar también un recordatorio futuro a través del sistema operativo
    // por si el usuario cierra la app o borra la notificación manualmente
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
