import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:mark_v3/models/Routes_/driver_day_models.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Base de datos SQLite local independiente para el módulo de Custodia y Rondines (Offline-First).
///
/// Mantiene su propia cola de acciones y cola de fotos 100% separada de Rutas/Chofer,
/// evitando cruce de sincronizaciones, bloqueos de lote o saturación de cola entre perfiles.
class CustodiaLocalDb {
  CustodiaLocalDb._();
  static final CustodiaLocalDb instance = CustodiaLocalDb._();

  Database? _db;
  String? _currentUserTag;

  Future<Database> get database async {
    final targetTag = await _resolveUserTag();
    if (_db != null && _db!.isOpen && _currentUserTag == targetTag) {
      return _db!;
    }
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
    _currentUserTag = targetTag;
    _db = await _initDb(targetTag);
    return _db!;
  }

  Future<String> _resolveUserTag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDemo = prefs.getBool('isDemoUser') ?? false;
      final uid = prefs.getString('userId');
      if (isDemo) {
        return 'demo_${uid ?? "user"}';
      }
      if (uid != null && uid.isNotEmpty) {
        return uid;
      }
    } catch (_) {}
    return 'default';
  }

  /// Cambia explícitamente el usuario activo de la base de datos de custodia
  Future<void> switchUser(String? newUserId, {bool isDemo = false}) async {
    final tag =
        isDemo ? 'demo_${newUserId ?? "user"}' : (newUserId ?? 'default');
    if (_currentUserTag != tag) {
      if (_db != null && _db!.isOpen) {
        await _db!.close();
      }
      _db = null;
      _currentUserTag = tag;
    }
  }

  /// Cierra la base de datos local al cerrar sesión del custodio/rondinero
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
    }
    _db = null;
    _currentUserTag = null;
  }

  Future<Database> _initDb(String userTag) async {
    final dbPath = await getDatabasesPath();
    final safeTag = userTag.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final path = p.join(dbPath, 'markv31_custodia_$safeTag.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE action_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT UNIQUE NOT NULL,
            tipo TEXT NOT NULL,
            id_servicio INTEGER,
            id_rondin INTEGER,
            payload_json TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            avisos_json TEXT NOT NULL DEFAULT '[]',
            retry_count INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE photo_queue (
            uuid TEXT PRIMARY KEY,
            tipo INTEGER NOT NULL,
            file_path TEXT NOT NULL,
            uploaded INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ===========================================================================
  // COLA DE ACCIONES DE CUSTODIA (STRICT FIFO ORDER)
  // ===========================================================================

  /// Encola una acción de custodia o rondín.
  /// Si es 'cusLeido', deduplica inteligentemente para no saturar la base de datos.
  Future<void> enqueueAction({
    required String uuid,
    required String tipo,
    int? idServicio,
    int? idRondin,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;

    // Deduplicación para 'cusLeido': solo necesitamos la marca de lectura más reciente
    if (tipo == 'cusLeido') {
      final existing = await db.query(
        'action_queue',
        where: "tipo = 'cusLeido' AND status = 'pending'",
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final existingId = existing.first['id'] as int;
        await db.update(
          'action_queue',
          {
            'uuid': uuid,
            'id_servicio': idServicio,
            'id_rondin': idRondin,
            'payload_json': jsonEncode(payload),
            'created_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [existingId],
        );
        return;
      }
    }

    await db.insert(
      'action_queue',
      {
        'uuid': uuid,
        'tipo': tipo,
        'id_servicio': idServicio,
        'id_rondin': idRondin,
        'payload_json': jsonEncode(payload),
        'status': 'pending',
        'avisos_json': '[]',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obtiene las acciones pendientes de custodia en estricto orden de creación
  Future<List<QueuedAction>> getPendingActions({int limit = 100}) async {
    final db = await database;
    final rows = await db.query(
      'action_queue',
      where: "status IN ('pending', 'retrying')",
      orderBy: 'id ASC',
      limit: limit,
    );
    return rows.map(QueuedAction.fromDbMap).toList();
  }

  /// Obtiene las acciones rechazadas de custodia
  Future<List<QueuedAction>> getRejectedActions() async {
    final db = await database;
    final rows = await db.query(
      'action_queue',
      where: "status = 'rejected'",
      orderBy: 'id DESC',
    );
    return rows.map(QueuedAction.fromDbMap).toList();
  }

  /// Elimina una acción cuando el servidor responde "aplicada" o "repetida"
  Future<void> removeAction(String uuid) async {
    final db = await database;
    await db.delete(
      'action_queue',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// Marca una acción como rechazada por el servidor
  Future<void> markActionRejected(
    String uuid,
    List<ServerNotice> avisos,
  ) async {
    final db = await database;
    await db.update(
      'action_queue',
      {
        'status': 'rejected',
        'avisos_json': jsonEncode(avisos.map((e) => e.toJson()).toList()),
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// Marca una acción como 'reintentar'
  Future<void> markActionRetry(
    String uuid,
    List<ServerNotice> avisos,
  ) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE action_queue
      SET status = 'retrying',
          retry_count = retry_count + 1,
          avisos_json = ?
      WHERE uuid = ?
      ''',
      [jsonEncode(avisos.map((e) => e.toJson()).toList()), uuid],
    );
  }

  Future<void> dismissRejectedAction(String uuid) async {
    await removeAction(uuid);
  }

  Future<void> clearAllRejectedActions() async {
    final db = await database;
    await db.delete('action_queue', where: "status = 'rejected'");
  }

  // ===========================================================================
  // COLA DE FOTOS DE CUSTODIA Y RONDINES
  // ===========================================================================

  /// Guarda y optimiza una foto de evidencia para custodia
  Future<QueuedPhoto> saveAndEnqueuePhoto({
    required String uuid,
    required int tipo,
    File? sourceFile,
    Uint8List? rawBytes,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(dir.path, 'custodia_media'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final ext = tipo == 2 ? 'png' : 'jpg';
    final destPath = p.join(photosDir.path, '${uuid}_t$tipo.$ext');

    Uint8List bytesToProcess;
    if (rawBytes != null) {
      bytesToProcess = rawBytes;
    } else if (sourceFile != null) {
      bytesToProcess = await sourceFile.readAsBytes();
    } else {
      throw ArgumentError('Se requiere sourceFile o rawBytes');
    }

    // Reducir antes de subir: 1280 px máx lado mayor, JPG 75
    Uint8List finalBytes = bytesToProcess;
    try {
      final decoded = img.decodeImage(bytesToProcess);
      if (decoded != null) {
        if (tipo == 1) {
          img.Image resized = decoded;
          if (decoded.width > 1280 || decoded.height > 1280) {
            if (decoded.width >= decoded.height) {
              resized = img.copyResize(decoded, width: 1280);
            } else {
              resized = img.copyResize(decoded, height: 1280);
            }
          }
          finalBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 75));
        } else if (tipo == 2) {
          final grayscale = img.grayscale(decoded);
          finalBytes = Uint8List.fromList(img.encodePng(grayscale));
        }
      }
    } catch (e) {
      debugPrint('Aviso: no se pudo procesar imagen de custodia: $e');
    }

    final savedFile = File(destPath);
    await savedFile.writeAsBytes(finalBytes);

    final db = await database;
    final nowStr = DateTime.now().toIso8601String();
    await db.insert(
      'photo_queue',
      {
        'uuid': uuid,
        'tipo': tipo,
        'file_path': destPath,
        'uploaded': 0,
        'created_at': nowStr,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return QueuedPhoto(
      uuid: uuid,
      tipo: tipo,
      filePath: destPath,
      uploaded: false,
      createdAt: nowStr,
    );
  }

  /// Obtiene fotos pendientes de custodia
  Future<List<QueuedPhoto>> getPendingPhotos({int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      'photo_queue',
      where: 'uploaded = 0',
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(QueuedPhoto.fromDbMap).toList();
  }

  /// Marca una foto de custodia como subida
  Future<void> markPhotoUploaded(String uuid) async {
    final db = await database;
    await db.update(
      'photo_queue',
      {'uploaded': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// Verifica si las fotos requeridas por una acción ya fueron subidas
  Future<bool> arePhotosUploaded(List<String> photoUuids) async {
    if (photoUuids.isEmpty) return true;
    final db = await database;
    final placeholders = List.filled(photoUuids.length, '?').join(',');
    final rows = await db.query(
      'photo_queue',
      columns: ['uuid', 'uploaded'],
      where: 'uuid IN ($placeholders)',
      whereArgs: photoUuids,
    );
    final uploadedMap = {
      for (final r in rows) (r['uuid'] as String): (r['uploaded'] as int) == 1
    };
    for (final u in photoUuids) {
      if (uploadedMap[u] != true) return false;
    }
    return true;
  }
}
