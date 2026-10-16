import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:mark_v3/models/Routes_/driver_day_models.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Base de datos SQLite local para la operación sin señal (Offline-First)
/// Reglas del documento:
/// - Guardar cada acción en SQLite antes de mostrarla como hecha.
/// - Mandar en orden de creación, en lotes, nunca reordenar (cliente antes de pedido, recojo antes de entrega).
/// - Fotos en cola aparte; se reducen a 1280px lado mayor JPG 75 y firmas PNG B/N, y se suben antes de las acciones que las usan.
/// - PARTICIONADA POR USUARIO: Cada chofer o cuenta demo tiene su propio archivo SQLite independiente.
class DriverLocalDb {
  DriverLocalDb._();
  static final DriverLocalDb instance = DriverLocalDb._();

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

  /// Cambia explícitamente el usuario activo de la base de datos local SQLite
  Future<void> switchUser(String? newUserId, {bool isDemo = false}) async {
    final tag = isDemo ? 'demo_${newUserId ?? "user"}' : (newUserId ?? 'default');
    if (_currentUserTag != tag) {
      if (_db != null && _db!.isOpen) {
        await _db!.close();
      }
      _db = null;
      _currentUserTag = tag;
    }
  }

  /// Cierra la base de datos local al cerrar sesión del chofer
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
    final path = p.join(dbPath, 'markv31_driver_$safeTag.db');

    // Limpieza de base de datos legacy global para evitar fugas de pedidos o rechazos anteriores
    try {
      final legacyPath = p.join(dbPath, 'markv31_driver_operacion.db');
      final legacyFile = File(legacyPath);
      if (await legacyFile.exists()) {
        await legacyFile.delete();
      }
    } catch (_) {}

    return openDatabase(
      path,
      version: 1,
      onOpen: (db) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS synced_orders (
            referencia TEXT PRIMARY KEY,
            cliente TEXT,
            fecha TEXT,
            total_lineas INTEGER,
            por_aprobar INTEGER,
            hora TEXT,
            json_data TEXT NOT NULL
          )
        ''');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE day_packages (
            fecha TEXT PRIMARY KEY,
            json_data TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE route_polylines (
            id_ruta INTEGER PRIMARY KEY,
            huella TEXT NOT NULL,
            polilinea TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE action_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT UNIQUE NOT NULL,
            tipo TEXT NOT NULL,
            id_ruta INTEGER,
            id_parada INTEGER,
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

        await db.execute('''
          CREATE TABLE clients_cache (
            id INTEGER PRIMARY KEY,
            codigo TEXT,
            nombre TEXT NOT NULL,
            search_text TEXT NOT NULL,
            json_data TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE catalog_cache (
            id_producto INTEGER PRIMARY KEY,
            json_data TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ===========================================================================
  // PAQUETE DEL DÍA Y HUELLAS DE POLILÍNEA
  // ===========================================================================

  /// Devuelve el mapa de huellas {"300": "98d59e63a896b892"} guardadas localmente
  Future<Map<String, String>> getSavedRouteHuellas() async {
    final db = await database;
    final rows = await db.query('route_polylines');
    final Map<String, String> huellas = {};
    for (final r in rows) {
      final idRuta = r['id_ruta']?.toString();
      final huella = r['huella']?.toString();
      final poly = r['polilinea']?.toString();
      if (idRuta != null &&
          huella != null &&
          huella.isNotEmpty &&
          poly != null &&
          poly.isNotEmpty) {
        huellas[idRuta] = huella;
      }
    }
    return huellas;
  }

  /// Guarda el paquete del día y resuelve polilíneas cuando vienen con "igual": true y "polilinea": null
  Future<DayPackage> saveDayPackage(DayPackage pkg) async {
    final db = await database;
    final List<DriverRoute> updatedRoutes = [];

    for (final route in pkg.rutas) {
      final geo = route.geometria;
      if (geo != null) {
        if (geo.polilinea != null && geo.polilinea!.isNotEmpty) {
          await db.insert(
            'route_polylines',
            {
              'id_ruta': route.idRuta,
              'huella': geo.huella,
              'polilinea': geo.polilinea!,
              'updated_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          updatedRoutes.add(route);
        } else if (geo.igual) {
          // Conservar la polilínea guardada localmente para esta ruta
          final rows = await db.query(
            'route_polylines',
            where: 'id_ruta = ?',
            whereArgs: [route.idRuta],
            limit: 1,
          );
          if (rows.isNotEmpty) {
            final cachedPoly = rows.first['polilinea']?.toString();
            updatedRoutes.add(
              route.copyWith(
                geometria: geo.copyWith(polilinea: cachedPoly),
              ),
            );
          } else {
            updatedRoutes.add(route);
          }
        } else {
          updatedRoutes.add(route);
        }
      } else {
        updatedRoutes.add(route);
      }
    }

    final resolvedPkg = pkg.copyWith(rutas: updatedRoutes);

    await db.insert(
      'day_packages',
      {
        'fecha': resolvedPkg.fecha,
        'json_data': jsonEncode(resolvedPkg.toJson()),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (resolvedPkg.catalogo.isNotEmpty) {
      await saveCatalog(resolvedPkg.catalogo);
    }

    return resolvedPkg;
  }

  Future<DayPackage?> getDayPackage(String fecha) async {
    final db = await database;
    final rows = await db.query(
      'day_packages',
      where: 'fecha = ?',
      whereArgs: [fecha],
      limit: 1,
    );
    if (rows.isEmpty) {
      // Si no hay para esa fecha exacta, buscar el último guardado si se pide fallback
      return null;
    }
    try {
      final map =
          jsonDecode(rows.first['json_data'] as String) as Map<String, dynamic>;
      return DayPackage.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<DayPackage?> getLatestDayPackage() async {
    final db = await database;
    final rows = await db.query(
      'day_packages',
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final map =
          jsonDecode(rows.first['json_data'] as String) as Map<String, dynamic>;
      return DayPackage.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  // ===========================================================================
  // COLA DE ACCIONES (STRICT FIFO ORDER)
  // ===========================================================================

  Future<void> enqueueAction({
    required String uuid,
    required String tipo,
    int? idRuta,
    int? idParada,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    await db.insert(
      'action_queue',
      {
        'uuid': uuid,
        'tipo': tipo,
        'id_ruta': idRuta,
        'id_parada': idParada,
        'payload_json': jsonEncode(payload),
        'status': 'pending',
        'avisos_json': '[]',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Obtiene las acciones listas para enviar (pending o retrying), en estricto orden de creación
  Future<List<QueuedAction>> getPendingActions({int limit = 200}) async {
    final db = await database;
    final rows = await db.query(
      'action_queue',
      where: "status IN ('pending', 'retrying')",
      orderBy: 'id ASC',
      limit: limit,
    );
    return rows.map(QueuedAction.fromDbMap).toList();
  }

  /// Obtiene las acciones rechazadas para la bandeja de "Pendientes de revisar"
  Future<List<QueuedAction>> getRejectedActions() async {
    final db = await database;
    final rows = await db.query(
      'action_queue',
      where: "status = 'rejected'",
      orderBy: 'id DESC',
    );
    return rows.map(QueuedAction.fromDbMap).toList();
  }

  /// Elimina una acción de la cola cuando el servidor contesta "aplicada" o "repetida"
  Future<void> removeAction(String uuid) async {
    final db = await database;
    await db.delete(
      'action_queue',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// Marca una acción como rechazada (sale de la cola de envío y pasa a la bandeja de revisión)
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

  /// Marca una acción como "reintentar" (se queda en la cola con el mismo uuid)
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
  // COLA DE FOTOS Y FIRMAS (CON REDUCCIÓN 1280PX JPG 75 Y PNG B/N)
  // ===========================================================================

  /// Procesa y guarda una foto (tipo=1: max 1280px, JPG 75) o firma (tipo=2: PNG B/N)
  Future<QueuedPhoto> saveAndEnqueuePhoto({
    required String uuid,
    required int tipo,
    File? sourceFile,
    Uint8List? rawBytes,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(dir.path, 'driver_media'));
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

    // Procesar con package:image según especificación:
    // "Reducir antes de subir: 1280 px de lado mayor, JPG calidad 75 (~200 KB). La firma, PNG en blanco y negro."
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
        } else {
          final grayscale = img.grayscale(decoded);
          finalBytes = Uint8List.fromList(img.encodePng(grayscale));
        }
      }
    } catch (_) {
      // Si falla la recodificación, conservar los bytes originales
      finalBytes = bytesToProcess;
    }

    final outFile = File(destPath);
    await outFile.writeAsBytes(finalBytes, flush: true);

    final now = DateTime.now().toIso8601String();
    final db = await database;
    await db.insert(
      'photo_queue',
      {
        'uuid': uuid,
        'tipo': tipo,
        'file_path': destPath,
        'uploaded': 0,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return QueuedPhoto(
      uuid: uuid,
      tipo: tipo,
      filePath: destPath,
      uploaded: false,
      createdAt: now,
    );
  }

  Future<List<QueuedPhoto>> getPendingPhotos() async {
    final db = await database;
    final rows = await db.query(
      'photo_queue',
      where: 'uploaded = 0',
      orderBy: 'created_at ASC',
    );
    return rows.map(QueuedPhoto.fromDbMap).toList();
  }

  Future<bool> arePhotosUploaded(List<String> uuids) async {
    if (uuids.isEmpty) return true;
    final db = await database;
    final placeholders = List.filled(uuids.length, '?').join(',');
    final rows = await db.query(
      'photo_queue',
      where: 'uuid IN ($placeholders) AND uploaded = 0',
      whereArgs: uuids,
    );
    return rows.isEmpty;
  }

  Future<void> markPhotoUploaded(String uuid) async {
    final db = await database;
    await db.update(
      'photo_queue',
      {'uploaded': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  // ===========================================================================
  // CACHÉ DE CLIENTES Y CATÁLOGO (PARA BÚSQUEDA SIN SEÑAL - RONDA 31)
  // ===========================================================================

  Future<void> saveClients(List<RouteClient> clients) async {
    final db = await database;
    final batch = db.batch();
    for (final c in clients) {
      final searchText = [
        c.nombre,
        c.nombreCorto,
        c.codigo,
        c.telefono,
        c.contacto,
        c.direccion,
      ].join(' ').toLowerCase();

      // Si es un cliente definitivo del servidor (id > 0), eliminar cualquier duplicado provisional
      // previo que coincida en nombre o en código
      if (c.id > 0) {
        batch.delete(
          'clients_cache',
          where: 'id <= 0 AND (LOWER(TRIM(nombre)) = ? OR codigo = ?)',
          whereArgs: [c.nombre.trim().toLowerCase(), c.codigo],
        );
      } else {
        // Si es provisional, eliminar cualquier entrada previa con el mismo nombre o código
        batch.delete(
          'clients_cache',
          where: 'id <= 0 AND (LOWER(TRIM(nombre)) = ? OR codigo = ?)',
          whereArgs: [c.nombre.trim().toLowerCase(), c.codigo],
        );
      }

      // ID determinista para provisionales para evitar crear filas múltiples con timestamps distintos
      final rowId = c.id > 0
          ? c.id
          : (c.localUuid != null && c.localUuid!.isNotEmpty
              ? -c.localUuid.hashCode.abs()
              : -c.codigo.hashCode.abs());

      batch.insert(
        'clients_cache',
        {
          'id': rowId == 0 ? -1 : rowId,
          'codigo': c.codigo,
          'nombre': c.nombre,
          'search_text': searchText,
          'json_data': jsonEncode(c.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteProvisionalClient(
      {String? nombre, String? codigo, String? localUuid}) async {
    final db = await database;
    final orClauses = <String>[];
    final args = <dynamic>[];
    if (nombre != null && nombre.trim().isNotEmpty) {
      orClauses.add('LOWER(TRIM(nombre)) = ?');
      args.add(nombre.trim().toLowerCase());
    }
    if (codigo != null && codigo.trim().isNotEmpty) {
      orClauses.add('codigo = ?');
      args.add(codigo.trim());
    }
    if (localUuid != null && localUuid.trim().isNotEmpty) {
      orClauses.add('json_data LIKE ?');
      args.add('%$localUuid%');
    }
    if (orClauses.isEmpty) return;
    await db.delete(
      'clients_cache',
      where: 'id <= 0 AND (${orClauses.join(' OR ')})',
      whereArgs: args,
    );
  }

  /// Sincronización completa con el servidor: limpia registros que fueron descartados o unidos en la oficina
  Future<void> syncFullClientsCache(List<RouteClient> serverClients) async {
    final db = await database;
    final pendingActions = await db.query(
      'action_queue',
      columns: ['uuid'],
      where: "tipo = 'cliente' AND status != 'applied'",
    );
    final pendingUuids = pendingActions
        .map((r) => r['uuid']?.toString() ?? '')
        .where((u) => u.isNotEmpty)
        .toSet();

    await db.transaction((txn) async {
      final currentServerIds =
          serverClients.map((c) => c.id).where((id) => id > 0).toSet();

      // 1. Eliminar de SQLite registros del servidor que ya no existen (clientes dados de baja, unidos o descartados)
      if (currentServerIds.isNotEmpty) {
        final placeholders =
            List.filled(currentServerIds.length, '?').join(',');
        await txn.delete(
          'clients_cache',
          where: 'id > 0 AND id NOT IN ($placeholders)',
          whereArgs: currentServerIds.toList(),
        );
      }

      // 2. Eliminar provisionales (id <= 0) que ya fueron procesados o unidos en oficina (no pendientes en cola local)
      final provisionalRows = await txn.query(
        'clients_cache',
        columns: ['id', 'json_data'],
        where: 'id <= 0',
      );
      for (final row in provisionalRows) {
        final rowId = row['id'] as int;
        try {
          final json =
              jsonDecode(row['json_data'] as String) as Map<String, dynamic>;
          final localUuid = json['localUuid']?.toString() ?? '';
          if (!pendingUuids.contains(localUuid)) {
            await txn
                .delete('clients_cache', where: 'id = ?', whereArgs: [rowId]);
          }
        } catch (_) {
          await txn
              .delete('clients_cache', where: 'id = ?', whereArgs: [rowId]);
        }
      }

      // 3. Insertar o actualizar la lista fresca del servidor
      final batch = txn.batch();
      for (final c in serverClients) {
        final searchText = [
          c.nombre,
          c.nombreCorto,
          c.codigo,
          c.telefono,
          c.contacto,
          c.direccion,
        ].join(' ').toLowerCase();

        batch.insert(
          'clients_cache',
          {
            'id': c.id,
            'codigo': c.codigo,
            'nombre': c.nombre,
            'search_text': searchText,
            'json_data': jsonEncode(c.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<RouteClient>> searchCachedClients(String query) async {
    final db = await database;
    final q = query.trim().toLowerCase();
    final rows = q.isEmpty
        ? await db.query('clients_cache', orderBy: 'nombre ASC', limit: 300)
        : await db.query(
            'clients_cache',
            where: 'search_text LIKE ?',
            whereArgs: ['%$q%'],
            orderBy: 'nombre ASC',
            limit: 200,
          );

    final rawList = rows
        .map((r) {
          try {
            final json =
                jsonDecode(r['json_data'] as String) as Map<String, dynamic>;
            final rowId = r['id'] as int?;
            if ((json['id'] == null || json['id'] == 0) &&
                rowId != null &&
                rowId < 0) {
              json['id'] = rowId;
            }
            return RouteClient.fromJson(json);
          } catch (_) {
            return null;
          }
        })
        .whereType<RouteClient>()
        .toList();

    // Deduplicación inteligente:
    // Si ya existe un cliente con id > 0 (servidor), cualquier registro provisional (id <= 0)
    // con el mismo nombre normalizado o código debe eliminarse de la caché y de los resultados.
    final serverClients = rawList.where((c) => c.id > 0).toList();
    final serverNames =
        serverClients.map((c) => c.nombre.trim().toLowerCase()).toSet();
    final serverCodes = serverClients.map((c) => c.codigo.trim()).toSet();

    final result = <RouteClient>[];
    final seenKeys = <String>{};
    final orphanedProvisionalIds = <int>[];

    for (final c in rawList) {
      final normName = c.nombre.trim().toLowerCase();
      if (c.id <= 0 &&
          (serverNames.contains(normName) ||
              serverCodes.contains(c.codigo.trim()))) {
        orphanedProvisionalIds.add(c.id);
        continue;
      }
      final key = c.id > 0 ? 'id_${c.id}' : 'name_$normName';
      if (seenKeys.add(key)) {
        result.add(c);
      }
    }

    if (orphanedProvisionalIds.isNotEmpty) {
      // Purgar de SQLite en segundo plano
      final placeholders =
          List.filled(orphanedProvisionalIds.length, '?').join(',');
      db
          .delete('clients_cache',
              where: 'id IN ($placeholders)', whereArgs: orphanedProvisionalIds)
          .ignore();
    }

    return result;
  }

  Future<void> saveCatalog(List<CatalogProduct> products) async {
    final db = await database;
    final batch = db.batch();
    for (final prod in products) {
      batch.insert(
        'catalog_cache',
        {
          'id_producto': prod.idProducto,
          'json_data': jsonEncode(prod.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<CatalogProduct>> getCachedCatalog() async {
    final db = await database;
    final rows = await db.query('catalog_cache');
    return rows
        .map((r) {
          try {
            return CatalogProduct.fromJson(
              jsonDecode(r['json_data'] as String) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<CatalogProduct>()
        .toList();
  }

  Future<void> saveSyncedOrder(SyncedOrder order) async {
    try {

      final db = await database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS synced_orders (
          referencia TEXT PRIMARY KEY,
          cliente TEXT,
          fecha TEXT,
          total_lineas INTEGER,
          por_aprobar INTEGER,
          hora TEXT,
          json_data TEXT NOT NULL
        )
      ''');
      await db.insert(
        'synced_orders',
        {
          'referencia': order.referencia,
          'cliente': order.cliente,
          'fecha': order.fecha,
          'total_lineas': order.totalLineas,
          'por_aprobar': order.porAprobar ? 1 : 0,
          'hora': order.sincronizadoHora,
          'json_data': jsonEncode(order.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // Ignorar errores no bloqueantes de persistencia local
    }
  }

  Future<List<SyncedOrder>> getSyncedOrders() async {
    try {
      final db = await database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS synced_orders (
          referencia TEXT PRIMARY KEY,
          cliente TEXT,
          fecha TEXT,
          total_lineas INTEGER,
          por_aprobar INTEGER,
          hora TEXT,
          json_data TEXT NOT NULL
        )
      ''');
      final rows = await db.query('synced_orders', orderBy: 'hora DESC');
      final List<SyncedOrder> list = [];
      for (final r in rows) {
        try {
          final json =
              jsonDecode(r['json_data'] as String) as Map<String, dynamic>;
          list.add(SyncedOrder.fromJson(json));
        } catch (_) {}
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteSyncedOrder(String referencia) async {
    try {

      final db = await database;
      await db.delete(
        'synced_orders',
        where: 'referencia = ?',
        whereArgs: [referencia],
      );
    } catch (_) {}
  }
}
