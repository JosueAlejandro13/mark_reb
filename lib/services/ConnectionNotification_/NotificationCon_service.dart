import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mark_v3/services/mark_api_client.dart';

/// Servicio de Notificaciones migrado a Mark V3.1 (api.php?a=notificaciones y a=notificacionesLeer)
class NotificationService {
  final MarkApiClient _client = MarkApiClient.instance;

  /// Obtener lista de notificaciones desde a=notificaciones
  Future<List<Map<String, dynamic>>> getAllNotifications(String idReceiver) async {
    try {
      final res = await _client.getNotificaciones(limite: 100);
      final rawList = res['bandeja'] ?? res['notificaciones'] ?? res['data'] ?? [];

      if (rawList is List) {
        return rawList.whereType<Map<String, dynamic>>().map((item) {
          final id = item['id']?.toString() ?? '';
          final title = item['titulo'] ?? item['title'] ?? 'Aviso';
          final description = item['texto'] ?? item['description'] ?? '';
          final leida = item['leida'] == true || item['leida'] == 1 || item['isRead'] == true;
          final dateStr = item['fecha'] ?? item['date'] ?? DateTime.now().toIso8601String();

          return {
            'id': id,
            'message': '$title|$description',
            'date': dateStr,
            'readNotice': leida ? 1 : 0,
            'origen': item['origen'],
            'idOrigen': item['idOrigen'],
          };
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error en NotificationService.getAllNotifications: $e');
      return [];
    }
  }

  /// Obtener notificaciones no leídas
  Future<List<Map<String, dynamic>>> getNotifications(String idReceiver) async {
    try {
      final res = await _client.getNotificaciones(soloNoLeidas: true, limite: 100);
      final rawList = res['bandeja'] ?? res['notificaciones'] ?? [];

      if (rawList is List) {
        return rawList.whereType<Map<String, dynamic>>().map((item) {
          final id = item['id']?.toString() ?? '';
          final title = item['titulo'] ?? 'Aviso';
          final description = item['texto'] ?? '';
          final dateStr = item['fecha'] ?? DateTime.now().toIso8601String();

          return {
            'id': id,
            'message': '$title|$description',
            'date': dateStr,
            'readNotice': 0,
            'origen': item['origen'],
            'idOrigen': item['idOrigen'],
          };
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error en NotificationService.getNotifications: $e');
      return [];
    }
  }

  /// Marcar notificación como leída en la API (a=notificacionesLeer)
  Future<void> updateNotification(String idReceiver, String notificationId) async {
    try {
      final intId = int.tryParse(notificationId);
      if (intId != null) {
        await _client.leerNotificaciones(ids: [intId]);
      } else {
        await _client.leerNotificaciones(todas: true);
      }
    } catch (e) {
      debugPrint('Error en NotificationService.updateNotification: $e');
    }
  }

  Future<void> insertNotification(Map<String, dynamic> notificationData) async {
    debugPrint('insertNotification recibido localmente: $notificationData');
  }

  Future<Map<String, dynamic>> gettypSource(String typSource) async {
    return {'typSource': typSource};
  }

  Future<Map<String, dynamic>?> getNoticeByName(String nameNotice) async {
    return {'name': nameNotice};
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
    debugPrint('insertStatus recibido: idvehic=$idvehic, status=$status');
  }
}
