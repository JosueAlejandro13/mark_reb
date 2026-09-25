import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mark_v3/services/database_service.dart';

//Autor: Josue Hernandez
class NotificationService {
  final String _baseUrl = '${DatabaseService.apiUrl}/notifications';

  Future<dynamic> _post(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? data['insertedId'] ?? data['affectedRows'] ?? true;
        } else {
          debugPrint('Error en $endpoint: ${data['message']}');
          return null;
        }
      } else {
        debugPrint('Error de servidor en $endpoint: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Excepción en $endpoint: $e');
      return null;
    }
  }

  Future<void> insertNotification(Map<String, dynamic> notificationData) async {
    await _post('insert_notification.php', notificationData);
  }

  Future<Map<String, dynamic>> gettypSource(String typSource) async {
    final data = await _post('get_type_source.php', {'typSource': typSource});
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  Future<Map<String, dynamic>?> getNoticeByName(String nameNotice) async {
    final data = await _post('get_notice_by_name.php', {'nameNotice': nameNotice});
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getNotifications(String idReceiver) async {
    final data = await _post('get_notifications.php', {
      'idReceiver': idReceiver,
      'unreadOnly': true
    });
    if (data != null) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  Future<void> updateNotification(String idReceiver, String notificationId) async {
    await _post('update_notification.php', {
      'idReceiver': idReceiver,
      'notificationId': notificationId
    });
  }

  Future<void> insertStatus(
    String iduser,
    String idvehic,
    String obs,
    DateTime date,
    String status,
    String typSource,
    String idSource,
  ) async {
    await _post('insert_status.php', {
      'iduser': iduser,
      'idvehic': idvehic,
      'obs': obs,
      'date': date.toIso8601String(),
      'status': status,
      'typSource': typSource,
      'idSource': idSource
    });
  }

  Future<List<Map<String, dynamic>>> getAllNotifications(String idReceiver) async {
    final data = await _post('get_notifications.php', {
      'idReceiver': idReceiver,
      'unreadOnly': false
    });
    if (data != null) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }
}
