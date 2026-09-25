import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mark_v3/services/ConnectionNotification_/NotificationCon_service.dart';
import 'package:mysql1/mysql1.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Modelo de Notificación
class NotificationItem {
  final String id;
  final IconData icon;
  final String title;
  final String description;
  final DateTime date;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.date,
    this.isRead = false,
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

  Future<void> fetchNotifications(String userId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final List<NotificationItem> mergedList = [];

      // 1. Cargar notificaciones locales guardadas de Firebase
      final prefs = await SharedPreferences.getInstance();
      final localJson = prefs.getString('notifications');
      if (localJson != null && localJson.isNotEmpty) {
        try {
          final List decoded = jsonDecode(localJson);
          mergedList.addAll(
              decoded.map((item) => NotificationItem.fromJson(item)).toList());
        } catch (e) {
          debugPrint('Error parseando notificaciones locales: $e');
        }
      }

      // 2. Cargar de la Base de Datos MySQL API
      final int? id = int.tryParse(userId);
      if (id != null) {
        final List<Map<String, dynamic>> dbNotifications =
            await _service.getAllNotifications(userId);

        for (final notif in dbNotifications) {
          String message = notif['message'] is Blob
              ? utf8.decode((notif['message'] as Blob).toBytes())
              : notif['message'].toString();

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
          );

          // Evitar duplicados por id
          final existingIndex =
              mergedList.indexWhere((item) => item.id == dbItem.id);
          if (existingIndex >= 0) {
            mergedList[existingIndex] = dbItem;
          } else {
            mergedList.add(dbItem);
          }
        }
      }

      // Ordenar por fecha descendente
      mergedList.sort((a, b) => b.date.compareTo(a.date));

      state = state.copyWith(
        notifications: mergedList,
        isLoading: false,
      );

      _persistNotifications();
    } catch (e) {
      debugPrint('Error al obtener notificaciones: $e');
      state = state.copyWith(
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
    _persistNotifications();

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
    _persistNotifications();

    // Actualizar en BD en segundo plano
    for (final item in updated) {
      _service.updateNotification(userId, item.id);
    }
  }

  void addNotification(NotificationItem item) {
    final current = [item, ...state.notifications];
    state = state.copyWith(notifications: current);
    _persistNotifications();
  }

  void deleteNotification(String id) {
    final updated = state.notifications.where((n) => n.id != id).toList();
    state = state.copyWith(notifications: updated);
    _persistNotifications();
  }

  Future<void> _persistNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(state.notifications.map((n) => n.toJson()).toList());
      await prefs.setString('notifications', encoded);
    } catch (e) {
      debugPrint('Error persistiendo notificaciones: $e');
    }
  }
}
