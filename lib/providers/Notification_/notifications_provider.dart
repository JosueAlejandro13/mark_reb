import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mark_v3/services/ConnectionNotification_/NotificationCon_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Modelo de Notificación
class NotificationItem {
  final String id;
  final IconData icon;
  final String title;
  final String description;
  final DateTime date;
  bool isRead;
  final int? origen;
  final int? idOrigen;

  NotificationItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.date,
    this.isRead = false,
    this.origen,
    this.idOrigen,
  });

  String getTimeAgo() {
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Hace un momento';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return difference.inHours == 1
          ? 'Hace 1 hora'
          : 'Hace ${difference.inHours} horas';
    } else if (difference.inDays < 7) {
      return difference.inDays == 1
          ? 'Ayer'
          : 'Hace ${difference.inDays} días';
    } else {
      return DateFormat('dd/MM/yyyy • HH:mm').format(date);
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date.toIso8601String(),
        'isRead': isRead,
        if (origen != null) 'origen': origen,
        if (idOrigen != null) 'idOrigen': idOrigen,
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      icon: Icons.notifications_none_rounded,
      title: json['title'] ?? 'Sin título',
      description: json['description'] ?? 'Sin contenido',
      date: json['date'] != null
          ? DateTime.tryParse(json['date']) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
      origen: int.tryParse(json['origen']?.toString() ?? ''),
      idOrigen: int.tryParse(json['idOrigen']?.toString() ?? ''),
    );
  }
}

// Estado inmutable de Notificaciones
class NotificationsState {
  final List<NotificationItem> notifications;
  final int selectedTab; // 0: Todas, 1: No leídas, 2: Leídas
  final bool isLoading;
  final String? error;

  const NotificationsState({
    this.notifications = const [],
    this.selectedTab = 0,
    this.isLoading = false,
    this.error,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  List<NotificationItem> get filteredNotifications {
    switch (selectedTab) {
      case 1:
        return notifications.where((n) => !n.isRead).toList();
      case 2:
        return notifications.where((n) => n.isRead).toList();
      default:
        return notifications;
    }
  }

  NotificationsState copyWith({
    List<NotificationItem>? notifications,
    int? selectedTab,
    bool? isLoading,
    String? error,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      selectedTab: selectedTab ?? this.selectedTab,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Provider Global de Notificaciones
final notificationsProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(
        NotificationsNotifier.new);

class NotificationsNotifier extends Notifier<NotificationsState> {
  final NotificationService _service = NotificationService();

  @override
  NotificationsState build() {
    return const NotificationsState();
  }

  void changeTab(int index) {
    state = state.copyWith(selectedTab: index);
  }

  void clearNotifications() {
    state = const NotificationsState();
  }

  Future<void> fetchNotifications(String userId) async {
    state = state.copyWith(isLoading: true, error: null);

    final prefs = await SharedPreferences.getInstance();
    final String userCacheKey = 'notifications_$userId';

    // 1. Limpieza de seguridad: borrar la clave global legacy 'notifications'
    // que causaba que notificaciones de usuarios reales se filtraran a cuentas demo o nuevos usuarios.
    if (prefs.containsKey('notifications')) {
      await prefs.remove('notifications');
    }

    try {
      final List<NotificationItem> freshList = [];

      // 2. Cargar de la Base de Datos MySQL API (fuente de verdad oficial para este userId)
      final int? id = int.tryParse(userId);
      if (id != null) {
        final List<Map<String, dynamic>> dbNotifications =
            await _service.getAllNotifications(userId);

        for (final notif in dbNotifications) {
          String message = notif['message'] is List<int>
              ? utf8.decode(notif['message'] as List<int>)
              : (notif['message']?.toString() ?? '');

          String dateString = notif['date'] is DateTime
              ? (notif['date'] as DateTime).toIso8601String()
              : notif['date'].toString();

          DateTime notificationDate =
              DateTime.tryParse(dateString) ?? DateTime.now();

          List<String> messageParts = message.split('|');
          String title =
              messageParts.isNotEmpty ? messageParts[0] : "Sin título";
          String description =
              messageParts.length > 1 ? messageParts[1] : "Sin descripción";

          final dbItem = NotificationItem(
            id: notif['id'].toString(),
            icon: Icons.notifications_active_rounded,
            title: title,
            description: description,
            date: notificationDate,
            isRead: notif['readNotice'] == 1,
            origen: int.tryParse(notif['origen']?.toString() ?? ''),
            idOrigen: int.tryParse(notif['idOrigen']?.toString() ?? ''),
          );

          freshList.add(dbItem);
        }
      }

      // 3. Revisar si hay notificaciones pendientes recibidas por push en segundo plano para este usuario
      final pendingFcmJson = prefs.getString('fcm_pending_$userId');
      if (pendingFcmJson != null && pendingFcmJson.isNotEmpty) {
        try {
          final List decoded = jsonDecode(pendingFcmJson);
          for (final item in decoded) {
            final fcmItem = NotificationItem.fromJson(item);
            if (!freshList.any((e) => e.id == fcmItem.id)) {
              freshList.add(fcmItem);
            }
          }
          await prefs.remove('fcm_pending_$userId');
        } catch (e) {
          debugPrint('Error procesando FCM pendientes: $e');
        }
      }

      // Ordenar por fecha descendente
      freshList.sort((a, b) => b.date.compareTo(a.date));

      state = state.copyWith(
        notifications: freshList,
        isLoading: false,
      );

      // Persistir la lista fresca en la caché exclusiva de este usuario
      await _persistNotifications(userId);
    } catch (e) {
      debugPrint('Error al obtener notificaciones: $e');

      // Fallback solo en caso de falla de red: restaurar la caché previa de ESTE usuario
      final cachedJson = prefs.getString(userCacheKey);
      List<NotificationItem> cachedList = [];
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final List decoded = jsonDecode(cachedJson);
          cachedList = decoded
              .map((item) => NotificationItem.fromJson(item))
              .toList();
        } catch (_) {}
      }

      state = state.copyWith(
        notifications: cachedList.isNotEmpty ? cachedList : state.notifications,
        isLoading: false,
        error: 'No se pudieron sincronizar las notificaciones.',
      );
    }
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    final updated = state.notifications.map((item) {
      if (item.id == notificationId) {
        item.isRead = true;
      }
      return item;
    }).toList();

    state = state.copyWith(notifications: updated);
    _persistNotifications(userId);

    try {
      await _service.updateNotification(userId, notificationId);
    } catch (e) {
      debugPrint('Error actualizando notificación en BD: $e');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    final updated = state.notifications.map((item) {
      item.isRead = true;
      return item;
    }).toList();

    state = state.copyWith(notifications: updated);
    _persistNotifications(userId);

    // Actualizar en BD en segundo plano
    for (final item in updated) {
      _service.updateNotification(userId, item.id);
    }
  }

  void addNotification(NotificationItem item, [String? userId]) {
    final current = [item, ...state.notifications];
    state = state.copyWith(notifications: current);
    _persistNotifications(userId);
  }

  void deleteNotification(String id, [String? userId]) {
    final updated = state.notifications.where((n) => n.id != id).toList();
    state = state.copyWith(notifications: updated);
    _persistNotifications(userId);
  }

  Future<void> _persistNotifications([String? userId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = (userId != null && userId.isNotEmpty)
          ? 'notifications_$userId'
          : 'notifications_${prefs.getString('userId') ?? 'current'}';
      final encoded =
          jsonEncode(state.notifications.map((n) => n.toJson()).toList());
      await prefs.setString(key, encoded);
    } catch (e) {
      debugPrint('Error persistiendo notificaciones: $e');
    }
  }
}
