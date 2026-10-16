import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';
import 'package:mark_v3/pages/Routes_/route_distance_page.dart';
import 'package:mark_v3/providers/Routes_/routes_provider.dart';
import 'package:mark_v3/pages/Routes_/driver_sync_widgets.dart';

/// Pantalla de Operación en CEDI (Centro de Distribución):
/// Dos pestañas:
/// 1. Bajar en CEDI (`descarga`: Recogida / Incidencia / En reparto → En CEDI)
/// 2. Subir al Vehículo (`carga`: En CEDI → En reparto; filtro físico contra NO_ES_TU_RUTA)
class CediOperationsPage extends ConsumerStatefulWidget {
  final int idRuta;
  final int initialTab; // 0 = Bajar (descarga), 1 = Subir (carga)

  const CediOperationsPage({
    super.key,
    required this.idRuta,
    this.initialTab = 0,
  });

  @override
  ConsumerState<CediOperationsPage> createState() => _CediOperationsPageState();
}

class _CediOperationsPageState extends ConsumerState<CediOperationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<int> _selectedDownloadGuiaIds = {};
  final List<String> _scannedDownloadCodes = [];

  final Set<int> _selectedUploadGuiaIds = {};
  final List<String> _scannedUploadCodes = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Recopila todas las guías candidatas a bajar en el CEDI (cediDescargar + recogidas/incidencia/no entregadas)
  List<GuiaItem> _getDownloadCandidates(DriverRoute route) {
    final Map<int, GuiaItem> map = {};
    for (final g in route.cediDescargar) {
      map[g.idGuia] = g;
    }
    for (final stop in route.paradas) {
      for (final g in stop.recoger) {
        if (g.estado == 1 || g.estado == 8 || g.estado == 3) {
          map[g.idGuia] = g;
        }
      }
      for (final g in stop.entregar) {
        if (!g.isVisitGuia && (g.estado == 3 || g.estado == 8)) {
          map[g.idGuia] = g;
        }
      }
    }
    return map.values.toList();
  }

  /// Recopila todas las guías candidatas a subir en el CEDI (cediCargar + guías de entrega en estado <= 2)
  List<GuiaItem> _getUploadCandidates(DriverRoute route) {
    final Map<int, GuiaItem> map = {};
    for (final g in route.cediCargar) {
      map[g.idGuia] = g;
    }
    for (final stop in route.paradas) {
      for (final g in stop.entregar) {
        if (!g.isVisitGuia && (g.estado == 0 || g.estado == 2)) {
          map[g.idGuia] = g;
        }
      }
    }
    return map.values.toList();
  }

  /// Conjunto de todos los códigos de etiqueta válidos de esta ruta (para filtro físico NO_ES_TU_RUTA)
  Set<String> _getValidRouteLabelCodes(DriverRoute route) {
    final Set<String> valid = {};
    for (final g in route.cediCargar) {
      valid.add(LabelCode.normalizeScannedCode(g.folio));
      valid.add(g.folio.trim().toUpperCase());
      for (final e in g.etiquetas) {
        valid.add(LabelCode.normalizeScannedCode(e.codigo));
        valid.add(e.codigo.trim().toUpperCase());
      }
    }
    for (final g in route.cediDescargar) {
      valid.add(LabelCode.normalizeScannedCode(g.folio));
      valid.add(g.folio.trim().toUpperCase());
      for (final e in g.etiquetas) {
        valid.add(LabelCode.normalizeScannedCode(e.codigo));
        valid.add(e.codigo.trim().toUpperCase());
      }
    }
    for (final stop in route.paradas) {
      for (final g in [...stop.recoger, ...stop.entregar]) {
        valid.add(LabelCode.normalizeScannedCode(g.folio));
        valid.add(g.folio.trim().toUpperCase());
        for (final e in g.etiquetas) {
          valid.add(LabelCode.normalizeScannedCode(e.codigo));
          valid.add(e.codigo.trim().toUpperCase());
        }
      }
    }
    valid.remove('');
    return valid;
  }

  Future<void> _openScannerForDownload(DriverRoute route) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LabelScannerSheet(
        title: 'Escanear para Bajar en CEDI',
        subtitle: 'Escanee en ráfaga los paquetes que entrega al almacén',
        burstMode: true,
        initialCodes: _scannedDownloadCodes,
      ),
    );
    if (result != null) {
      setState(() {
        _scannedDownloadCodes
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _openScannerForUpload(DriverRoute route) async {
    final validCodes = _getValidRouteLabelCodes(route);
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LabelScannerSheet(
        title: 'Escanear Carga al Vehículo',
        subtitle:
            'Filtro activo de ruta: alerta roja si un paquete no va en tu ruta',
        burstMode: true,
        initialCodes: _scannedUploadCodes,
        validNormalizedCodes: validCodes.isNotEmpty ? validCodes : null,
        invalidCodeAlertTitle: '¡NO_ES_TU_RUTA!',
        invalidCodeAlertMessage:
            'Esa guía NO va en esta ruta: ¡NO la subas al vehículo!',
      ),
    );
    if (result != null) {
      setState(() {
        _scannedUploadCodes
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _submitDownload(DriverRoute route) async {
    if (_selectedDownloadGuiaIds.isEmpty && _scannedDownloadCodes.isEmpty) {
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final res = await ref.read(routesProvider.notifier).registrarDescargaCedi(
            idRuta: route.idRuta,
            idGuias: _selectedDownloadGuiaIds.toList(),
            codigos: _scannedDownloadCodes,
          );
      if (!mounted) return;
      showServerNoticesFeedback(
        context,
        res.avisos,
        fallbackSuccessMessage: 'Descarga en CEDI registrada correctamente.',
      );
      setState(() {
        _selectedDownloadGuiaIds.clear();
        _scannedDownloadCodes.clear();
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitUpload(DriverRoute route) async {
    if (_selectedUploadGuiaIds.isEmpty && _scannedUploadCodes.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      final res = await ref.read(routesProvider.notifier).registrarCargaCedi(
            idRuta: route.idRuta,
            idGuias: _selectedUploadGuiaIds.toList(),
            codigos: _scannedUploadCodes,
          );
      if (!mounted) return;
      showServerNoticesFeedback(
        context,
        res.avisos,
        fallbackSuccessMessage:
            'Carga al vehículo registrada. Paquetes en reparto.',
      );
      setState(() {
        _selectedUploadGuiaIds.clear();
        _scannedUploadCodes.clear();
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isSmallScreen = mediaQuery.size.width < 360;

    final state = ref.watch(routesProvider);
    final route = state.findRoute(widget.idRuta);

    if (route == null) {
      return MediaQuery(
        data: mediaQuery.copyWith(textScaler: clampedScaler),
        child: Scaffold(
          appBar: AppBar(title: const Text('Operación CEDI')),
          body: const Center(child: Text('Ruta no encontrada')),
        ),
      );
    }

    final downloadList = _getDownloadCandidates(route);
    final uploadList = _getUploadCandidates(route);

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF8FAFC),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 62,
          leadingWidth: 54,
          titleSpacing: 12,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF0F172A),
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Operación CEDI',
                style: TextStyle(
                  fontSize: 18.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${route.cedi?.nombre ?? "Centro de Distribución"} · ${route.nombre}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: const [],
        ),
        body: Column(
          children: [
            // Tarjeta superior del CEDI
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.warehouse_rounded,
                          color: Color(0xFF0284C7),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            route.cedi != null
                                ? route.cedi!.nombre
                                : 'Centro de Distribución',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${route.nombre} · Gestión de Almacén',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Top Mode Switcher (Capsule TabBar compacto idéntico a DeliverPage)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: const Color(0xFF0F172A),
                unselectedLabelColor: const Color(0xFF64748B),
                labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
                tabs: [
                  Tab(
                    height: 34,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.download_rounded, size: 14),
                        const SizedBox(width: 5),
                        Text('Bajar (${downloadList.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 34,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.upload_rounded, size: 14),
                        const SizedBox(width: 5),
                        Text('Subir (${uploadList.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab contents
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // PESTAÑA 1: BAJAR EN CEDI (DESCARGA)
                  _buildBatchTab(
                    isUpload: false,
                    title: 'Paquetes por bajar en el CEDI',
                    subtitle:
                        'Lo recogido de "Por pedido" y lo no entregado vuelve a quedar En CEDI.',
                    candidates: downloadList,
                    selectedIds: _selectedDownloadGuiaIds,
                    scannedCodes: _scannedDownloadCodes,
                    onScanPressed: () => _openScannerForDownload(route),
                    onSelectAll: () {
                      setState(() {
                        if (_selectedDownloadGuiaIds.length ==
                            downloadList.length) {
                          _selectedDownloadGuiaIds.clear();
                        } else {
                          _selectedDownloadGuiaIds
                            ..clear()
                            ..addAll(downloadList.map((e) => e.idGuia));
                        }
                      });
                    },
                    onToggleGuia: (id) {
                      setState(() {
                        if (_selectedDownloadGuiaIds.contains(id)) {
                          _selectedDownloadGuiaIds.remove(id);
                        } else {
                          _selectedDownloadGuiaIds.add(id);
                        }
                      });
                    },
                    onSubmit: () => _submitDownload(route),
                  ),

                  // PESTAÑA 2: SUBIR AL VEHÍCULO (CARGA)
                  _buildBatchTab(
                    isUpload: true,
                    title: 'Paquetes por subir al vehículo',
                    subtitle:
                        'Escanee en ráfaga. Al cargar pasan a "En reparto" y se avisa al destinatario.',
                    candidates: uploadList,
                    selectedIds: _selectedUploadGuiaIds,
                    scannedCodes: _scannedUploadCodes,
                    onScanPressed: () => _openScannerForUpload(route),
                    onSelectAll: () {
                      setState(() {
                        if (_selectedUploadGuiaIds.length ==
                            uploadList.length) {
                          _selectedUploadGuiaIds.clear();
                        } else {
                          _selectedUploadGuiaIds
                            ..clear()
                            ..addAll(uploadList.map((e) => e.idGuia));
                        }
                      });
                    },
                    onToggleGuia: (id) {
                      setState(() {
                        if (_selectedUploadGuiaIds.contains(id)) {
                          _selectedUploadGuiaIds.remove(id);
                        } else {
                          _selectedUploadGuiaIds.add(id);
                        }
                      });
                    },
                    onSubmit: () => _submitUpload(route),
                  ),
                ],
              ),
            ),
            // Barra de estado de sincronización inferior
            const DriverSyncStatusBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildGuiaTile({
    required GuiaItem g,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? accentColor : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? accentColor.withOpacity(0.06)
                : Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Checkmark squircle
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected ? accentColor : Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: isSelected ? accentColor : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          g.folio,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            g.estadoTexto,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                        if (g.unsyncedLocal) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.cloud_upload_outlined,
                            size: 14,
                            color: Color(0xFFD97706),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${g.bultos} bulto(s) · ${g.pesoKg} kg'
                      '${g.destinatario != null && g.destinatario!.nombre.isNotEmpty ? " · Para: ${g.destinatario!.nombre}" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required bool isUpload,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUpload
                    ? Icons.inventory_2_outlined
                    : Icons.assignment_turned_in_outlined,
                size: 26,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isUpload
                  ? 'Todo cargado o pendiente de escanear'
                  : 'No hay guías pendientes por descargar',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isUpload
                  ? 'No hay guías pendientes en la lista de carga. También puede escanear etiquetas directamente con el botón de ráfaga.'
                  : 'No hay guías pendientes por descargar en el CEDI.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required bool isUpload,
    required String title,
    required String subtitle,
    required List<GuiaItem> candidates,
    required Set<int> selectedIds,
    required List<String> scannedCodes,
    required VoidCallback onScanPressed,
    required VoidCallback onSelectAll,
    required Color accentColor,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isUpload
                      ? const Color(0xFFF0F9FF)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isUpload
                        ? const Color(0xFFBAE6FD)
                        : const Color(0xFFFED7AA),
                  ),
                ),
                child: Center(
                  child: Icon(
                    isUpload ? Icons.upload_rounded : Icons.download_rounded,
                    color: accentColor,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onScanPressed,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                    label: Text(
                      scannedCodes.isEmpty
                          ? 'Escanear en Ráfaga'
                          : 'Escaneados (${scannedCodes.length})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              if (candidates.isNotEmpty) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 38,
                  child: OutlinedButton(
                    onPressed: onSelectAll,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      selectedIds.length == candidates.length
                          ? 'Quitar todas'
                          : 'Marcar todas',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (scannedCodes.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 90,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: scannedCodes
                      .map(
                        (c) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                LabelCode.normalizeScannedCode(c),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    scannedCodes.remove(c);
                                  });
                                },
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomConfirmBar({
    required bool isUpload,
    required String countDetail,
    required bool hasItems,
    required Color accentColor,
    required Future<void> Function() onSubmit,
    required Set<int> selectedIds,
    required List<String> scannedCodes,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).padding.bottom > 0 ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: _SwipeToConfirmButton(
          key: ValueKey(
              '${isUpload}_${selectedIds.length}_${scannedCodes.length}'),
          isLoading: _isSubmitting,
          enabled: hasItems,
          disabledLabel: isUpload
              ? 'Marque guías o escanee'
              : 'Marque guías o escanee',
          label: isUpload
              ? 'Desliza para cargar$countDetail'
              : 'Desliza para descargar$countDetail',
          themeColor: accentColor,
          icon: isUpload
              ? Icons.local_shipping_rounded
              : Icons.warehouse_rounded,
          onConfirmed: onSubmit,
        ),
      ),
    );
  }

  Widget _buildBatchTab({
    required bool isUpload,
    required String title,
    required String subtitle,
    required List<GuiaItem> candidates,
    required Set<int> selectedIds,
    required List<String> scannedCodes,
    required VoidCallback onScanPressed,
    required VoidCallback onSelectAll,
    required ValueChanged<int> onToggleGuia,
    required Future<void> Function() onSubmit,
  }) {
    final accentColor =
        isUpload ? const Color(0xFF0284C7) : const Color(0xFFEA580C);
    final hasItems = selectedIds.isNotEmpty || scannedCodes.isNotEmpty;

    final String countDetail = selectedIds.isNotEmpty && scannedCodes.isNotEmpty
        ? ' (${selectedIds.length}g / ${scannedCodes.length}c)'
        : (selectedIds.isNotEmpty
            ? ' (${selectedIds.length} guías)'
            : (scannedCodes.isNotEmpty
                ? ' (${scannedCodes.length} códigos)'
                : ''));

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildActionCard(
                  isUpload: isUpload,
                  title: title,
                  subtitle: subtitle,
                  candidates: candidates,
                  selectedIds: selectedIds,
                  scannedCodes: scannedCodes,
                  onScanPressed: onScanPressed,
                  onSelectAll: onSelectAll,
                  accentColor: accentColor,
                ),
              ),
              if (candidates.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(isUpload: isUpload),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final g = candidates[index];
                        final isSelected = selectedIds.contains(g.idGuia);
                        return _buildGuiaTile(
                          g: g,
                          isSelected: isSelected,
                          accentColor: accentColor,
                          onTap: () => onToggleGuia(g.idGuia),
                        );
                      },
                      childCount: candidates.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _buildBottomConfirmBar(
          isUpload: isUpload,
          countDetail: countDetail,
          hasItems: hasItems,
          accentColor: accentColor,
          onSubmit: onSubmit,
          selectedIds: selectedIds,
          scannedCodes: scannedCodes,
        ),
      ],
    );
  }
}

/// Bandeja de acciones rechazadas ("Pendientes de revisar")
/// Regla: "Si una acción queda rechazada, las siguientes del mismo paquete pueden fallar en cadena.
/// Mostrar todas al chofer en una bandeja de 'pendientes de revisar'."
class RejectedActionsSheet extends ConsumerWidget {
  const RejectedActionsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(routesProvider);
    final rejected = state.rejectedActions;

    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final shortestSide = mediaQuery.size.shortestSide;
    final isTablet = shortestSide >= 600;
    final isLandscape = mediaQuery.orientation == Orientation.landscape ||
        screenWidth > screenHeight;

    final double dialogMaxWidth;
    if (isTablet && isLandscape) {
      dialogMaxWidth = math.min(screenWidth * 0.75, 760.0);
    } else if (isTablet) {
      dialogMaxWidth = 620.0;
    } else if (isLandscape) {
      dialogMaxWidth = math.min(screenWidth * 0.88, 640.0);
    } else {
      dialogMaxWidth = 520.0;
    }

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogMaxWidth,
          ),
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: isLandscape ? 24 : 16,
              vertical: isLandscape ? 12 : 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 0.9,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.10),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              isTablet ? 24 : 20,
              isLandscape ? 16 : 20,
              isTablet ? 24 : 20,
              isLandscape ? 18 : 22,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Encabezado con ícono, título, contador badge agrupado y botón de cerrar (X) estilo Apple
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: const Color(0xFFFECACA),
                            width: 0.8,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFDC2626),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Pendientes de revisar',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (rejected.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFFECACA),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '${rejected.length}',
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 0.8,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.close_rounded,
                                color: Color(0xFF64748B),
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isLandscape ? 6 : 8),

                  // 2. Subtítulo explicativo
                  const Text(
                    'No se dio de alta esta acción. Puedes descartar el aviso para retirarlo de tus pendientes:',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: isLandscape ? 12 : 16),

                  // 3. Lista de pendientes o estado vacío
                  if (rejected.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: isLandscape ? 16 : 24),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFA7F3D0),
                                  width: 0.8,
                                ),
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF10B981),
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'No hay pendientes de revisión.',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Todas las acciones están al corriente.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: isLandscape
                            ? math.min(screenHeight * 0.52, 280.0)
                            : math.min(screenHeight * 0.52, 400.0),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: rejected.length,
                        itemBuilder: (context, index) {
                          final item = rejected[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: EdgeInsets.symmetric(
                              horizontal: isLandscape ? 14 : 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2).withOpacity(0.50),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFEE2E2),
                                width: 1.0,
                              ),
                            ),
                            child: LayoutBuilder(
                              builder: (context, cardConstraints) {
                                final isCardWide =
                                    cardConstraints.maxWidth >= 460;

                                if (isCardWide) {
                                  // Disposición horizontal limpia: Tag | Avisos | Botón
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      _buildTypeBadge(item.tipo),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child:
                                            _buildNoticesColumn(item.avisos),
                                      ),
                                      const SizedBox(width: 12),
                                      _buildDismissButton(ref, item.uuid),
                                    ],
                                  );
                                } else {
                                  // Disposición vertical para pantallas angostas
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildTypeBadge(item.tipo),
                                          _buildDismissButton(ref, item.uuid),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      _buildNoticesColumn(item.avisos),
                                    ],
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String tipo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFECACA),
          width: 0.8,
        ),
      ),
      child: Text(
        tipo.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: Color(0xFFB91C1C),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildDismissButton(WidgetRef ref, String uuid) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            ref.read(routesProvider.notifier).dismissRejected(uuid),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFCA5A5),
              width: 0.9,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 14,
                color: Color(0xFFDC2626),
              ),
              SizedBox(width: 4),
              Text(
                'Descartar aviso',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoticesColumn(List<ServerNotice> avisos) {
    if (avisos.isEmpty) {
      return const Text(
        'No se dio de alta la acción.',
        style: TextStyle(
          fontSize: 12.5,
          color: Color(0xFF7F1D1D),
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (avisos.length == 1) {
      final cleanText = ServerNotice.sanitizeText(
        avisos.first.texto.isNotEmpty ? avisos.first.texto : 'No se dio de alta.',
      );
      return Text(
        cleanText,
        style: const TextStyle(
          fontSize: 12.5,
          color: Color(0xFF7F1D1D),
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: avisos.map((a) {
        final cleanText = ServerNotice.sanitizeText(
          a.texto.isNotEmpty ? a.texto : 'No se dio de alta.',
        );
        return Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(
                  Icons.circle,
                  size: 5,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cleanText,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF7F1D1D),
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SwipeToConfirmButton extends StatefulWidget {
  final Future<void> Function() onConfirmed;
  final String label;
  final String? disabledLabel;
  final Color themeColor;
  final IconData icon;
  final bool isLoading;
  final bool enabled;

  const _SwipeToConfirmButton({
    super.key,
    required this.onConfirmed,
    required this.label,
    this.disabledLabel,
    required this.themeColor,
    this.icon = Icons.arrow_forward_rounded,
    this.isLoading = false,
    this.enabled = true,
  });

  @override
  State<_SwipeToConfirmButton> createState() => _SwipeToConfirmButtonState();
}

class _SwipeToConfirmButtonState extends State<_SwipeToConfirmButton>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  late AnimationController _animController;
  late Animation<double> _resetAnimation;
  bool _isFinished = false;
  bool _localLoading = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        setState(() {
          _dragPosition = _resetAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _reset() {
    if (!mounted) return;
    _resetAnimation = Tween<double>(
      begin: _dragPosition,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward(from: 0.0);
    _isFinished = false;
  }

  @override
  Widget build(BuildContext context) {
    const double height = 46.0;
    const double handlePadding = 3.5;
    const double handleSize = height - (handlePadding * 2);
    final effectiveLoading = widget.isLoading || _localLoading;
    final isEnabled = widget.enabled && !effectiveLoading;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag =
            constraints.maxWidth - handleSize - (handlePadding * 2);

        return Container(
          height: height,
          width: constraints.maxWidth,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
            ),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // Barra de relleno que sigue el arrastre
              if (isEnabled)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: (_dragPosition + handleSize + handlePadding * 2)
                      .clamp(0.0, constraints.maxWidth),
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.themeColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(23),
                    ),
                  ),
                ),

              // Contenido central
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: 44, right: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isEnabled ? widget.icon : Icons.touch_app_outlined,
                        color: isEnabled
                            ? widget.themeColor
                            : const Color(0xFF94A3B8),
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isEnabled
                              ? widget.label
                              : (widget.disabledLabel ?? widget.label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isEnabled ? FontWeight.w700 : FontWeight.w500,
                            color: isEnabled
                                ? widget.themeColor
                                : const Color(0xFF94A3B8),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (isEnabled) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_double_arrow_right_rounded,
                          color: widget.themeColor.withOpacity(0.7),
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Agarradera / Handle circular deslizable
              Positioned(
                left: handlePadding + (isEnabled ? _dragPosition : 0.0),
                top: handlePadding,
                child: GestureDetector(
                  onHorizontalDragUpdate: !isEnabled || _isFinished
                      ? null
                      : (details) {
                          if (_animController.isAnimating) return;
                          setState(() {
                            _dragPosition = (_dragPosition + details.delta.dx)
                                .clamp(0.0, maxDrag);
                          });
                        },
                  onHorizontalDragEnd: !isEnabled || _isFinished
                      ? null
                      : (details) async {
                          if (_animController.isAnimating) return;
                          if (_dragPosition >= maxDrag * 0.75) {
                            HapticFeedback.mediumImpact();
                            setState(() {
                              _dragPosition = maxDrag;
                              _isFinished = true;
                              _localLoading = true;
                            });
                            try {
                              await widget.onConfirmed();
                            } finally {
                              if (mounted) {
                                setState(() => _localLoading = false);
                                _reset();
                              }
                            }
                          } else {
                            _reset();
                          }
                        },
                  child: Container(
                    width: handleSize,
                    height: handleSize,
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? widget.themeColor
                          : const Color(0xFFCBD5E1),
                      shape: BoxShape.circle,
                      boxShadow: isEnabled
                          ? [
                              BoxShadow(
                                color: widget.themeColor.withOpacity(0.38),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: effectiveLoading
                          ? LoadingAnimationWidget.threeRotatingDots(
                              color: Colors.white,
                              size: 18,
                            )
                          : Icon(
                              isEnabled
                                  ? Icons.arrow_forward_rounded
                                  : Icons.lock_outline_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
