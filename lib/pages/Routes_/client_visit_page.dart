import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';
import 'package:mark_v3/pages/Routes_/route_distance_page.dart';
import 'package:mark_v3/providers/Routes_/routes_provider.dart';
import 'package:mark_v3/pages/Routes_/driver_sync_widgets.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';
import 'package:url_launcher/url_launcher.dart';

class _EditableVisitLine {
  final int idProducto;
  final String codigo;
  final String nombre;
  final String unidad;
  final double precio;
  int cantidad;
  int tipo; // 1 = venta, 2 = devolución, 3 = cambio

  _EditableVisitLine({
    required this.idProducto,
    required this.codigo,
    required this.nombre,
    required this.unidad,
    required this.precio,
    required this.cantidad,
    this.tipo = 1,
  });
}

/// Pantalla de Visita Comercial (Rutas Diarias modalidad 2 y Fijas modalidad 3, o fuera de ruta)
class VisitRecordPage extends ConsumerStatefulWidget {
  final int idRuta;
  final int? idParada;
  final GuiaItem? visitGuia;
  final RouteClient client;

  const VisitRecordPage({
    super.key,
    required this.idRuta,
    this.idParada,
    this.visitGuia,
    required this.client,
  });

  @override
  ConsumerState<VisitRecordPage> createState() => _VisitRecordPageState();
}

class _VisitRecordPageState extends ConsumerState<VisitRecordPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<_EditableVisitLine> _todayLines = [];
  final List<_EditableVisitLine> _nextOrderLines = [];
  String? _fechaPedido;
  final TextEditingController _noteCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<File> _photoFiles = [];
  final List<String> _photoUuids = [];
  bool _isTakingPhoto = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _preloadExpectedItems();
  }

  void _handleTabChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _preloadExpectedItems() {
    final g = widget.visitGuia;
    if (g == null) return;
    final catalog = ref.read(routesProvider).catalog;
    final Map<int, CatalogProduct> catMap = {
      for (final p in catalog) p.idProducto: p,
    };

    if (g.ventas.isNotEmpty) {
      for (final v in g.ventas) {
        final prod = catMap[v.idProducto];
        _todayLines.add(
          _EditableVisitLine(
            idProducto: v.idProducto,
            codigo: prod?.codigo ?? 'ID-${v.idProducto}',
            nombre: prod?.nombre ?? 'Producto #${v.idProducto}',
            unidad: prod?.unidad ?? 'PZA',
            precio:
                prod?.precio ?? (v.cantidad > 0 ? v.importe / v.cantidad : 0.0),
            cantidad: v.cantidad,
            tipo: v.tipo,
          ),
        );
      }
      return;
    }

    for (final item in g.items) {
      final prod = catMap[item.idProducto];
      _todayLines.add(
        _EditableVisitLine(
          idProducto: item.idProducto,
          codigo: item.sku.isNotEmpty ? item.sku : (prod?.codigo ?? ''),
          nombre: item.descrip.isNotEmpty
              ? item.descrip
              : (prod?.nombre ?? 'Producto #${item.idProducto}'),
          unidad: prod?.unidad ?? 'PZA',
          precio: prod?.precio ?? 0.0,
          cantidad: item.cantidad,
          tipo: 1,
        ),
      );
    }
  }

  double get _todaySalesTotal {
    double sum = 0;
    for (final line in _todayLines) {
      if (line.tipo == 1 && line.cantidad > 0) {
        sum += line.precio * line.cantidad;
      }
    }
    return sum;
  }

  double get _todayDevolutionTotal {
    double sum = 0;
    for (final line in _todayLines) {
      if (line.tipo == 2 && line.cantidad > 0) {
        sum += line.precio * line.cantidad;
      }
    }
    return sum;
  }

  int get _todayChangePieces {
    int sum = 0;
    for (final line in _todayLines) {
      if (line.tipo == 3 && line.cantidad > 0) {
        sum += line.cantidad;
      }
    }
    return sum;
  }

  bool get _hasSales => _todayLines.any((l) => l.tipo == 1 && l.cantidad > 0);
  bool get _hasDevolutions =>
      _todayLines.any((l) => l.tipo == 2 && l.cantidad > 0);
  bool get _hasChanges => _todayLines.any((l) => l.tipo == 3 && l.cantidad > 0);
  bool get _hasAnyTodayProducts => _todayLines.any((l) => l.cantidad > 0);
  bool get _hasAnyNextOrder => _nextOrderLines.any((l) => l.cantidad > 0);

  double get _approximateTodayTotal {
    if (_hasSales && _hasDevolutions) {
      final net = _todaySalesTotal - _todayDevolutionTotal;
      return net < 0 ? 0.0 : net;
    }
    if (_hasDevolutions) {
      return _todayDevolutionTotal;
    }
    return _todaySalesTotal;
  }

  double get _approximateNextOrderTotal {
    double sum = 0;
    for (final line in _nextOrderLines) {
      if (line.cantidad > 0) {
        sum += line.precio * line.cantidad;
      }
    }
    return sum;
  }

  Future<void> _openCatalogPicker({
    required bool forNextOrder,
    int defaultTipo = 1,
  }) async {
    final state = ref.read(routesProvider);
    List<CatalogProduct> catalog = state.catalog;
    if (catalog.isEmpty) {
      await ref.read(routesProvider.notifier).loadClientsFromServer();
      catalog = ref.read(routesProvider).catalog;
    }

    if (!mounted) return;
    final selected = await showModalBottomSheet<CatalogProduct>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CatalogSearchModal(catalog: catalog),
    );

    if (selected != null) {
      setState(() {
        final targetList = forNextOrder ? _nextOrderLines : _todayLines;
        final targetTipo = forNextOrder ? 1 : defaultTipo;
        final existingIdx = targetList.indexWhere(
            (l) => l.idProducto == selected.idProducto && l.tipo == targetTipo);
        if (existingIdx >= 0) {
          targetList[existingIdx].cantidad++;
        } else {
          targetList.add(
            _EditableVisitLine(
              idProducto: selected.idProducto,
              codigo: selected.codigo,
              nombre: selected.nombre,
              unidad: selected.unidad,
              precio: selected.precio,
              cantidad: 1,
              tipo: targetTipo,
            ),
          );
        }
      });
    }
  }

  Future<void> _takePhoto({VoidCallback? onStateChange}) async {
    if (_isTakingPhoto) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked == null) return;
      if (mounted) {
        setState(() => _isTakingPhoto = true);
        onStateChange?.call();
      }
      final file = File(picked.path);
      final uuid =
          await ref.read(routesProvider.notifier).registerLocalPhoto(file);
      if (mounted) {
        setState(() {
          _photoFiles.add(file);
          _photoUuids.add(uuid);
        });
        onStateChange?.call();
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarTop.showError(
        context,
        'No se pudo procesar la foto: $e',
        style: SnackbarTopStyle.appleCard,
      );
    } finally {
      if (mounted) {
        setState(() => _isTakingPhoto = false);
        onStateChange?.call();
      }
    }
  }

  // --- SALIDA 1: VENDÍ ---
  Future<void> _submitVendi() async {
    final validSales = _todayLines.where((l) => l.cantidad > 0).toList();
    final validPedido = _nextOrderLines.where((l) => l.cantidad > 0).toList();

    if (validSales.isEmpty && validPedido.isEmpty) {
      showServerNoticesFeedback(context, const [
        ServerNotice(
          nivel: 'error',
          codigo: 'VACIA',
          texto:
              'Agregue al menos un producto (venta, devolución o cambio) o un pedido para la próxima visita.',
        ),
      ]);
      return;
    }

    await _executeVisitAction(
      ventas: validSales
          .map((l) => {
                'idProducto': l.idProducto,
                'cantidad': l.cantidad,
                if (l.tipo != 1) 'tipo': l.tipo,
              })
          .toList(),
      pedido: validPedido
          .map((l) => {
                'idProducto': l.idProducto,
                'cantidad': l.cantidad,
              })
          .toList(),
    );
  }

  // --- SALIDA 2: NO COMPRÓ (Motivos 33–35, visitado: true) ---
  Future<void> _promptNoCompro(DayConfig config) async {
    final reasons = config.motivosVisita
        .where((m) => m.visitado || (m.codigo >= 33 && m.codigo <= 35))
        .toList();

    final chosen = await _showReasonSelectionModal(
      title: '¿Por qué no compró?',
      subtitle: 'La visita quedará cerrada como visitada sin venta:',
      reasons: reasons,
      accentColor: const Color(0xFFD97706),
    );
    if (chosen == null) return;

    final confirmed = await _showReasonEvidenceModal(
      reason: chosen,
      isIncidence: false,
      accentColor: const Color(0xFFD97706),
    );
    if (confirmed != true) return;

    final validPedido = _nextOrderLines
        .where((l) => l.cantidad > 0)
        .map((l) => {'idProducto': l.idProducto, 'cantidad': l.cantidad})
        .toList();

    await _executeVisitAction(
      motivo: chosen.codigo,
      pedido: validPedido,
    );
  }

  // --- SALIDA 3: NO PUDE ATENDER (Motivos 31, 32, 36, 37, visitado: false → Incidencia) ---
  Future<void> _promptNoPudeAtender(DayConfig config) async {
    final reasons = config.motivosVisita
        .where((m) =>
            !m.visitado || m.codigo == 31 || m.codigo == 32 || m.codigo >= 36)
        .toList();

    final chosen = await _showReasonSelectionModal(
      title: '¿Por qué no se pudo atender?',
      subtitle: 'Quedará registrada como incidencia para revisión:',
      reasons: reasons,
      accentColor: const Color(0xFFDC2626),
    );
    if (chosen == null) return;

    final confirmed = await _showReasonEvidenceModal(
      reason: chosen,
      isIncidence: true,
      accentColor: const Color(0xFFDC2626),
    );
    if (confirmed != true) return;

    await _executeVisitAction(motivo: chosen.codigo);
  }

  Future<bool?> _showReasonEvidenceModal({
    required VisitReason reason,
    required bool isIncidence,
    required Color accentColor,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final mq = MediaQuery.of(modalCtx);
            final isLandscape = mq.orientation == Orientation.landscape;
            final screenHeight = mq.size.height;

            return MediaQuery(
              data: mq.copyWith(textScaler: clampedScaler),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 540,
                    maxHeight:
                        isLandscape ? screenHeight * 0.95 : screenHeight * 0.90,
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(22)),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      18,
                      isLandscape ? 10 : 14,
                      18,
                      mq.viewInsets.bottom + (isLandscape ? 12 : 18),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 38,
                              height: 4,
                              margin:
                                  EdgeInsets.only(bottom: isLandscape ? 8 : 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          // Header con motivo seleccionado
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Motivo ${reason.codigo}',
                                  style: TextStyle(
                                    color: accentColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  reason.texto,
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isIncidence
                                ? 'Reporte de no atención (requiere foto de evidencia obligatoria).'
                                : 'Visita sin venta (requiere foto de evidencia obligatoria).',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Card de Evidencia Fotográfica (sin campo de comentarios)
                          Flexible(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildModalPhotoEvidenceCard(
                                    onStateChange: () => setModalState(() {}),
                                  ),
                                  if (_photoFiles.isEmpty) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: const Color(0xFFFCA5A5)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.camera_alt_outlined,
                                              color: Color(0xFFDC2626),
                                              size: 16),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Toma la foto primero usando el botón antes de confirmar y mandar.',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: Color(0xFF991B1B),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: const Color(0xFF86EFAC)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded,
                                              color: Color(0xFF16A34A),
                                              size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Foto capturada (${_photoFiles.length}). Ahora presiona Confirmar y Mandar.',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: Color(0xFF166534),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Botones de acción: Cancelar y Mandar / Confirmar
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 42,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF64748B),
                                      side: const BorderSide(
                                          color: Color(0xFFCBD5E1)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () =>
                                        Navigator.of(modalCtx).pop(false),
                                    child: const Text(
                                      'Cancelar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: SizedBox(
                                  height: 42,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accentColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () {
                                      // Exigir fotografía obligatoria: se debe tomar antes, NO auto-mandar
                                      if (_photoUuids.isEmpty) {
                                        SnackbarTop.showInfo(
                                          context,
                                          'Primero debes tomar la foto de evidencia antes de confirmar.',
                                          style: SnackbarTopStyle.appleCard,
                                        );
                                        return;
                                      }
                                      Navigator.of(modalCtx).pop(true);
                                    },
                                    icon: const Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 16),
                                    label: const Text(
                                      'Confirmar y Mandar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<VisitReason?> _showReasonSelectionModal({
    required String title,
    required String subtitle,
    required List<VisitReason> reasons,
    required Color accentColor,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );

    return showModalBottomSheet<VisitReason>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final isLandscape = mq.orientation == Orientation.landscape;
        final screenHeight = mq.size.height;

        return MediaQuery(
          data: mq.copyWith(textScaler: clampedScaler),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 540,
                maxHeight:
                    isLandscape ? screenHeight * 0.92 : screenHeight * 0.85,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      isLandscape ? 10 : 12,
                      20,
                      isLandscape ? 12 : 20,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            margin:
                                EdgeInsets.only(bottom: isLandscape ? 8 : 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: isLandscape ? 16 : 17,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        SizedBox(height: isLandscape ? 8 : 12),
                        Flexible(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: reasons
                                  .map(
                                    (r) => Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: ListTile(
                                        dense: isLandscape,
                                        visualDensity: isLandscape
                                            ? VisualDensity.compact
                                            : VisualDensity.standard,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: isLandscape ? 0 : 2,
                                        ),
                                        leading: CircleAvatar(
                                          radius: isLandscape ? 16 : 18,
                                          backgroundColor:
                                              accentColor.withOpacity(0.12),
                                          child: Text(
                                            '${r.codigo}',
                                            style: TextStyle(
                                              color: accentColor,
                                              fontWeight: FontWeight.w800,
                                              fontSize: isLandscape ? 11 : 12,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          r.texto,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: isLandscape ? 13 : 14,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        trailing: const Icon(
                                          Icons.chevron_right_rounded,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        onTap: () => Navigator.of(ctx).pop(r),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _executeVisitAction({
    List<Map<String, dynamic>> ventas = const [],
    List<Map<String, dynamic>> pedido = const [],
    int? motivo,
  }) async {
    // Si se está registrando un motivo (No compró o No se pudo atender), la fotografía es obligatoria
    if (motivo != null && _photoUuids.isEmpty) {
      SnackbarTop.showInfo(
        context,
        'Primero debes tomar la foto de evidencia antes de confirmar.',
        style: SnackbarTopStyle.appleCard,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final res = await ref.read(routesProvider.notifier).registrarVisita(
            idRuta: widget.idRuta,
            idParada: widget.idParada,
            idGuia: widget.visitGuia?.idGuia,
            idClie: widget.visitGuia == null ? widget.client.id : null,
            ventas: ventas,
            pedido: pedido,
            fechaPedido: _fechaPedido,
            motivo: motivo,
            nota: _noteCtrl.text,
            fotosUuids: _photoUuids,
          );

      if (!mounted) return;
      showServerNoticesFeedback(
        context,
        res.avisos,
        fallbackSuccessMessage: 'Visita a ${widget.client.nombre} registrada.',
      );
      if (res.queuedOrApplied) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routesProvider);
    final config = state.dayPackage?.config ?? const DayConfig();
    final isOutOfRoute = widget.visitGuia == null;

    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isSmallScreen = mediaQuery.size.width < 360;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF8FAFC),
          surfaceTintColor: Colors.transparent,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          toolbarHeight: 56,
          leadingWidth: 54,
          titleSpacing: 12,
          leading: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 36,
                    height: 36,
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
          title: const Text(
            'Visita',
            style: TextStyle(
              fontSize: 18.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          actions: const [],
        ),
        body: Column(
          children: [
            // Tarjeta superior del Cliente (compacto y unificado con CEDI / Preventa)
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
                          Icons.storefront_rounded,
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
                            widget.client.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isOutOfRoute
                                ? 'Visita FUERA de ruta · Cliente #${widget.client.id}'
                                : 'Folio ${widget.visitGuia!.folio} · ${widget.visitGuia!.visita == 2 ? "Con Pedido" : "Plan del Cliente"}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
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

            // Selector de pestaña estilo Píldora moderna (idéntico a CEDI y Preventa)
            // Selector de pestaña estilo Píldora moderna (idéntico a CEDI y Preventa)
            AbsorbPointer(
              absorbing: _isSubmitting,
              child: Container(
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
                          const Icon(Icons.shopping_bag_rounded, size: 14),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Venta Hoy (${_todayLines.where((l) => l.cantidad > 0).length})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      height: 34,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.event_repeat_rounded, size: 14),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Pedido Próxima (${_nextOrderLines.where((l) => l.cantidad > 0).length})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AbsorbPointer(
                absorbing: _isSubmitting,
                child: TabBarView(
                  controller: _tabController,
                  physics: _isSubmitting
                      ? const NeverScrollableScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  children: [
                    _buildTodayVisitTab(isSmallScreen),
                    _buildNextOrderTab(isSmallScreen),
                  ],
                ),
              ),
            ),
            // Contenedor sticky inferior blindado contra desbordamientos
            Container(
              padding: EdgeInsets.fromLTRB(
                isSmallScreen ? 10 : 14,
                8,
                isSmallScreen ? 10 : 14,
                8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        final isNextOrderTab = _tabController.index == 1;

                        // Textos y colores adaptativos para pestaña HOY
                        final String todayLabel;
                        final String todayValue;
                        final Color todayColor;
                        final Color todayDotColor;

                        if (!_hasSales && _hasDevolutions) {
                          todayLabel = 'Total a devolver:';
                          todayValue =
                              '-\$${_todayDevolutionTotal.toStringAsFixed(2)}';
                          todayColor = const Color(0xFFD97706);
                          todayDotColor = const Color(0xFFD97706);
                        } else if (!_hasSales && _hasChanges) {
                          todayLabel = 'Cambios físicos:';
                          todayValue = '$_todayChangePieces pza(s)';
                          todayColor = const Color(0xFF2563EB);
                          todayDotColor = const Color(0xFF2563EB);
                        } else if (_hasSales && _hasDevolutions) {
                          todayLabel = 'Total neto a cobrar:';
                          todayValue =
                              '\$${_approximateTodayTotal.toStringAsFixed(2)}';
                          todayColor = const Color(0xFF0F172A);
                          todayDotColor = const Color(0xFF059669);
                        } else {
                          todayLabel = 'Total venta hoy:';
                          todayValue =
                              '\$${_todaySalesTotal.toStringAsFixed(2)}';
                          todayColor = const Color(0xFF0F172A);
                          todayDotColor = const Color(0xFF059669);
                        }

                        final currentLabel = isNextOrderTab
                            ? 'Total próximo pedido:'
                            : todayLabel;
                        final currentValue = isNextOrderTab
                            ? '\$${_approximateNextOrderTotal.toStringAsFixed(2)}'
                            : todayValue;
                        final currentDotColor = isNextOrderTab
                            ? const Color(0xFF0886B5)
                            : todayDotColor;
                        final currentValColor = isNextOrderTab
                            ? const Color(0xFF0886B5)
                            : todayColor;

                        // Subtítulo con desglose completo
                        String? otherText;
                        Color? otherColor;
                        if (isNextOrderTab) {
                          if (_hasDevolutions && !_hasSales) {
                            otherText =
                                '(Devolución hoy: \$${_todayDevolutionTotal.toStringAsFixed(2)})';
                            otherColor = const Color(0xFFD97706);
                          } else if (_hasChanges && !_hasSales) {
                            otherText =
                                '(Cambios hoy: $_todayChangePieces pza(s))';
                            otherColor = const Color(0xFF2563EB);
                          } else if (_todaySalesTotal > 0) {
                            otherText =
                                '(Venta hoy: \$${_todaySalesTotal.toStringAsFixed(2)})';
                            otherColor = const Color(0xFF059669);
                          }
                        } else {
                          if (_hasSales && _hasDevolutions) {
                            otherText =
                                '(Venta: \$${_todaySalesTotal.toStringAsFixed(2)} · Devol.: -\$${_todayDevolutionTotal.toStringAsFixed(2)}${_todayChangePieces > 0 ? " · Cambios: $_todayChangePieces pza(s)" : ""})';
                            otherColor = const Color(0xFF64748B);
                          } else if (_hasSales && _todayChangePieces > 0) {
                            otherText =
                                '(Cambios físicos: $_todayChangePieces pza(s))';
                            otherColor = const Color(0xFF2563EB);
                          } else if (!_hasSales &&
                              _hasDevolutions &&
                              _todayChangePieces > 0) {
                            otherText =
                                '(Cambios físicos: $_todayChangePieces pza(s))';
                            otherColor = const Color(0xFF2563EB);
                          } else if (_approximateNextOrderTotal > 0) {
                            otherText =
                                '(Próx. pedido: \$${_approximateNextOrderTotal.toStringAsFixed(2)})';
                            otherColor = const Color(0xFF0886B5);
                          }
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.only(right: 5),
                                        decoration: BoxDecoration(
                                          color: currentDotColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          currentLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (otherText != null) ...[
                                    const SizedBox(height: 1),
                                    Text(
                                      otherText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: otherColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              currentValue,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: currentValColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Botón de acción principal consolidado (Confirmar Visita / Enviar Pedido)
                        Expanded(
                          flex: 5,
                          child: SizedBox(
                            height: 38,
                            child: Builder(
                              builder: (context) {
                                final isNextOrderOnly =
                                    !_hasAnyTodayProducts && _hasAnyNextOrder;

                                final String actionText = isNextOrderOnly
                                    ? 'Enviar Pedido'
                                    : 'Confirmar Visita';
                                final IconData actionIcon = isNextOrderOnly
                                    ? Icons.send_rounded
                                    : Icons.check_circle_rounded;
                                final Color actionBgColor = isNextOrderOnly
                                    ? const Color(0xFF0886B5)
                                    : const Color(0xFF059669);

                                return ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: actionBgColor,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        actionBgColor.withOpacity(0.5),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    minimumSize: Size.zero,
                                    elevation: _isSubmitting ? 0 : 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed:
                                      _isSubmitting ? null : _submitVendi,
                                  child: _isSubmitting
                                      ? Center(
                                          child: LoadingAnimationWidget
                                              .threeRotatingDots(
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(actionIcon, size: 15),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                actionText,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: isSmallScreen
                                                      ? 10.5
                                                      : 11.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Botón NO COMPRÓ
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 38,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD97706),
                                side: BorderSide(
                                    color: _isSubmitting
                                        ? const Color(0xFFF59E0B)
                                            .withOpacity(0.3)
                                        : const Color(0xFFF59E0B),
                                    width: 1.1),
                                backgroundColor: _isSubmitting
                                    ? const Color(0xFFF8FAFC)
                                    : const Color(0xFFFFFBEB),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _promptNoCompro(config),
                              child: Text(
                                'No compró',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: isSmallScreen ? 10 : 11,
                                  color: _isSubmitting
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Botón NO PUDE ATENDER
                        Expanded(
                          flex: 4,
                          child: SizedBox(
                            height: 38,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: BorderSide(
                                    color: _isSubmitting
                                        ? const Color(0xFFEF4444)
                                            .withOpacity(0.3)
                                        : const Color(0xFFEF4444),
                                    width: 1.1),
                                backgroundColor: _isSubmitting
                                    ? const Color(0xFFF8FAFC)
                                    : const Color(0xFFFEF2F2),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _promptNoPudeAtender(config),
                              child: Text(
                                'No pude atender',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: isSmallScreen ? 9.5 : 10.5,
                                  color: _isSubmitting
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Barra de estado de sincronización inferior
            const DriverSyncStatusBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayVisitTab(bool isSmallScreen) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 12 : 16,
        6,
        isSmallScreen ? 12 : 16,
        10,
      ),
      children: [
        // 2 BOTONES DE ACCIÓN RÁPIDA: AGREGAR VENTA Y AGREGAR DEVOLUCIÓN/CAMBIO (Compactos CEDI)
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFF059669).withOpacity(0.5),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () => _openCatalogPicker(
                          forNextOrder: false, defaultTipo: 1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_shopping_cart_rounded, size: 15),
                      SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Agregar Venta',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 38,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    backgroundColor: _isSubmitting
                        ? const Color(0xFFF8FAFC)
                        : const Color(0xFFFFFBEB),
                    side: BorderSide(
                      color: _isSubmitting
                          ? const Color(0xFFFDE68A).withOpacity(0.4)
                          : const Color(0xFFFDE68A),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () => _openCatalogPicker(
                          forNextOrder: false, defaultTipo: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_return_rounded,
                        size: 15,
                        color: _isSubmitting
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Devol. / Cambio',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: _isSubmitting
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // SECCIÓN 1: VENTA DE HOY (tipo == 1)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(
                    Icons.shopping_bag_rounded,
                    color: Color(0xFF059669),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Venta / Entrega Hoy (${_todayLines.where((l) => l.tipo == 1).length})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12.5 : 13.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_todaySalesTotal > 0) ...[
              const SizedBox(width: 6),
              Text(
                'Subtotal: \$${_todaySalesTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF059669),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        if (_todayLines.where((l) => l.tipo == 1).isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded,
                    color: Color(0xFF94A3B8), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sin productos de venta agregados.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                  ),
                ),
              ],
            ),
          )
        else
          ..._todayLines.where((l) => l.tipo == 1).map((line) {
            return _buildProductLineCard(
              line: line,
              showTypeSelector: false,
              isSmallScreen: isSmallScreen,
              isDisabled: _isSubmitting,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() => _todayLines.remove(line)),
            );
          }),

        const SizedBox(height: 6),

        // SECCIÓN 2: DEVOLUCIONES Y CAMBIOS (tipo == 2 || tipo == 3)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(
                    Icons.assignment_return_rounded,
                    color: Color(0xFFD97706),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Devoluciones y Cambios (${_todayLines.where((l) => l.tipo == 2 || l.tipo == 3).length})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12.5 : 13.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_todayDevolutionTotal > 0) ...[
              const SizedBox(width: 6),
              Text(
                'Devol.: -\$${_todayDevolutionTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFFD97706),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        if (_todayLines.where((l) => l.tipo == 2 || l.tipo == 3).isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: const [
                Icon(Icons.inventory_2_outlined,
                    color: Color(0xFF94A3B8), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No hay devoluciones ni cambios registrados.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                  ),
                ),
              ],
            ),
          )
        else
          ..._todayLines.where((l) => l.tipo == 2 || l.tipo == 3).map((line) {
            return _buildProductLineCard(
              line: line,
              showTypeSelector: true,
              isSmallScreen: isSmallScreen,
              isDisabled: _isSubmitting,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() => _todayLines.remove(line)),
            );
          }),
        const SizedBox(height: 10),

        // CARD NOTAS Y FOTO (Compartida e idéntica)
        _buildNotesAndEvidencesCard(),
      ],
    );
  }

  Widget _buildModalPhotoEvidenceCard({VoidCallback? onStateChange}) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.camera_alt_rounded,
                      color: Color(0xFF0886B5),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Evidencia Fotográfica (${_photoFiles.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 30,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0886B5),
                    side: BorderSide(
                      color: (_isTakingPhoto || _isSubmitting)
                          ? const Color(0xFF0886B5).withOpacity(0.4)
                          : const Color(0xFF0886B5),
                      width: 1.1,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: (_isTakingPhoto || _isSubmitting)
                      ? null
                      : () async {
                          await _takePhoto(onStateChange: onStateChange);
                          onStateChange?.call();
                        },
                  icon: _isTakingPhoto
                      ? SizedBox(
                          width: 13,
                          height: 13,
                          child: LoadingAnimationWidget.threeRotatingDots(
                            color: const Color(0xFF0886B5),
                            size: 13,
                          ),
                        )
                      : const Icon(Icons.camera_alt_rounded, size: 14),
                  label: Text(
                    _isTakingPhoto
                        ? 'Guardando...'
                        : (_photoFiles.isEmpty ? 'Tomar foto' : 'Tomar otra'),
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_photoFiles.isEmpty && !_isTakingPhoto)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: (_isTakingPhoto || _isSubmitting)
                  ? null
                  : () async {
                      await _takePhoto(onStateChange: onStateChange);
                      onStateChange?.call();
                    },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFCBD5E1),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF8FC),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: const Icon(
                        Icons.add_a_photo_rounded,
                        color: Color(0xFF0886B5),
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tocar para tomar foto de evidencia',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0886B5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Foto obligatoria para validar este reporte',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 70,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._photoFiles.asMap().entries.map((entry) {
                    final i = entry.key;
                    final file = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              file,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: _isSubmitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _photoFiles.removeAt(i);
                                        _photoUuids.removeAt(i);
                                      });
                                      onStateChange?.call();
                                    },
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_isTakingPhoto)
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF8FC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF0886B5).withOpacity(0.35),
                          width: 1.1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LoadingAnimationWidget.threeRotatingDots(
                            color: const Color(0xFF0886B5),
                            size: 18,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Guardando...',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0886B5),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesAndEvidencesCard({VoidCallback? onStateChange}) {
    return Container(
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_rounded,
                      color: Color(0xFF0886B5),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Notas y Evidencias (${_photoFiles.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 30,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0886B5),
                    side: BorderSide(
                      color: (_isTakingPhoto || _isSubmitting)
                          ? const Color(0xFF0886B5).withOpacity(0.4)
                          : const Color(0xFF0886B5),
                      width: 1.1,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: (_isTakingPhoto || _isSubmitting)
                      ? null
                      : () async {
                          await _takePhoto(onStateChange: onStateChange);
                          onStateChange?.call();
                        },
                  icon: _isTakingPhoto
                      ? SizedBox(
                          width: 13,
                          height: 13,
                          child: LoadingAnimationWidget.threeRotatingDots(
                            color: const Color(0xFF0886B5),
                            size: 13,
                          ),
                        )
                      : const Icon(Icons.camera_alt_rounded, size: 14),
                  label: Text(
                    _isTakingPhoto ? 'Guardando...' : 'Tomar foto',
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            enabled: !_isSubmitting,
            maxLines: 2,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Comentarios u observaciones de la visita...',
              hintStyle:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: const Color(0xFFE2E8F0).withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF0886B5)),
              ),
            ),
          ),
          if (_photoFiles.isNotEmpty || _isTakingPhoto) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._photoFiles.asMap().entries.map((entry) {
                    final i = entry.key;
                    final file = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              file,
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: _isSubmitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _photoFiles.removeAt(i);
                                        _photoUuids.removeAt(i);
                                      });
                                      onStateChange?.call();
                                    },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 11,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_isTakingPhoto)
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF8FC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF0886B5).withOpacity(0.35),
                          width: 1.1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LoadingAnimationWidget.threeRotatingDots(
                            color: const Color(0xFF0886B5),
                            size: 16,
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Guardando',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0886B5),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNextOrderTab(bool isSmallScreen) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 12 : 16,
        6,
        isSmallScreen ? 12 : 16,
        10,
      ),
      children: [
        // Card de Fecha (Compacto)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFF0F172A),
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fecha del próximo pedido',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _fechaPedido ??
                          'Automática (siguiente visita programada)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 30,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: BorderSide(
                        color: _isSubmitting
                            ? const Color(0xFF0F172A).withOpacity(0.3)
                            : const Color(0xFF0F172A),
                        width: 1.1),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: now.add(const Duration(days: 1)),
                            firstDate: now,
                            lastDate: now.add(const Duration(days: 90)),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFF0284C7),
                                    onPrimary: Colors.white,
                                    onSurface: Color(0xFF0F172A),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() {
                              _fechaPedido =
                                  DateFormat('yyyy-MM-dd').format(picked);
                            });
                          }
                        },
                  icon: const Icon(Icons.edit_calendar_rounded,
                      size: 13, color: Color(0xFF0F172A)),
                  label: const Text('Elegir',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A))),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 38,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0886B5),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF0886B5).withOpacity(0.5),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _isSubmitting
                ? null
                : () => _openCatalogPicker(forNextOrder: true),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.add_shopping_cart_rounded,
                    size: 15, color: Colors.white),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Agregar Producto del Catálogo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(
                    Icons.event_repeat_rounded,
                    color: Color(0xFF0886B5),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Preventa Próxima',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12.5 : 13.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Total: \$${_approximateNextOrderTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF0886B5),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_nextOrderLines.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.event_note_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sin productos para la próxima visita',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Use esta pestaña para levantar preventa y anticipar el siguiente pedido del cliente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                ),
              ],
            ),
          )
        else
          ..._nextOrderLines.map((line) {
            return _buildProductLineCard(
              line: line,
              showTypeSelector: false,
              isSmallScreen: isSmallScreen,
              isDisabled: _isSubmitting,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() => _nextOrderLines.remove(line)),
            );
          }),
      ],
    );
  }

  Widget _buildProductLineCard({
    required _EditableVisitLine line,
    required bool showTypeSelector,
    required bool isSmallScreen,
    bool isDisabled = false,
    required VoidCallback onChanged,
    required VoidCallback onRemove,
  }) {
    final subtotal = line.precio * line.cantidad;

    return Dismissible(
      key: ObjectKey(line),
      direction:
          isDisabled ? DismissDirection.none : DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Eliminar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            SizedBox(width: 6),
            Icon(
              Icons.delete_sweep_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: isDisabled
                              ? const Color(0xFF64748B)
                              : const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        line.tipo == 3
                            ? '\$${line.precio.toStringAsFixed(2)} c/u · ${line.cantidad} ${line.unidad}'
                            : (line.tipo == 2
                                ? '\$${line.precio.toStringAsFixed(2)} c/u · Devol.: -\$${subtotal.toStringAsFixed(2)}'
                                : '\$${line.precio.toStringAsFixed(2)} c/u · Subtotal: \$${subtotal.toStringAsFixed(2)}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDisabled
                              ? const Color(0xFF94A3B8)
                              : (line.tipo == 2
                                  ? const Color(0xFFD97706)
                                  : (line.tipo == 3
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF64748B))),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: isDisabled
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: isDisabled
                            ? null
                            : () {
                                if (line.cantidad > 1) {
                                  line.cantidad--;
                                  onChanged();
                                } else {
                                  onRemove();
                                }
                              },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Icon(
                            Icons.remove_rounded,
                            size: 16,
                            color: isDisabled
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${line.cantidad}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                          color: isDisabled
                              ? const Color(0xFF64748B)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Material(
                      color: isDisabled
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: isDisabled
                            ? null
                            : () {
                                line.cantidad++;
                                onChanged();
                              },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: isDisabled
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (showTypeSelector) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    _buildTypePill(
                      title: 'Devolución (-)',
                      isSelected: line.tipo == 2,
                      activeColor: const Color(0xFFD97706),
                      isDisabled: isDisabled,
                      onTap: () {
                        line.tipo = 2;
                        onChanged();
                      },
                    ),
                    const SizedBox(width: 3),
                    _buildTypePill(
                      title: 'Cambio Físico',
                      isSelected: line.tipo == 3,
                      activeColor: const Color(0xFF2563EB),
                      isDisabled: isDisabled,
                      onTap: () {
                        line.tipo = 3;
                        onChanged();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypePill({
    required String title,
    required bool isSelected,
    required Color activeColor,
    bool isDisabled = false,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? (isDisabled ? activeColor.withOpacity(0.5) : activeColor)
                  : (isDisabled
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// MODAL DE BÚSQUEDA DE PRODUCTOS DEL CATÁLOGO
// =============================================================================

class _CatalogSearchModal extends StatefulWidget {
  final List<CatalogProduct> catalog;

  const _CatalogSearchModal({required this.catalog});

  @override
  State<_CatalogSearchModal> createState() => _CatalogSearchModalState();
}

class _CatalogSearchModalState extends State<_CatalogSearchModal> {
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.catalog
        : widget.catalog.where((p) {
            return p.nombre.toLowerCase().contains(q) ||
                p.codigo.toLowerCase().contains(q);
          }).toList();

    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: DraggableScrollableSheet(
        initialChildSize: 0.80,
        minChildSize: 0.40,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Handle bar para arrastrar / scroll
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(top: 12, bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  // Encabezado con título y contador
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_rounded,
                          color: Color(0xFF0886B5),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Catálogo de Productos',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${filtered.length} art.',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Buscador
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: false,
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(
                          fontSize: 13.5, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre o SKU...',
                        hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Color(0xFF0886B5), size: 20),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 18, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF0886B5), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Lista scrolleable conectada a scrollController
                  Expanded(
                    child: filtered.isEmpty
                        ? SingleChildScrollView(
                            controller: scrollController,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF1F5F9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.search_off_rounded,
                                        color: Color(0xFF94A3B8),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'No se encontraron productos en el catálogo.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, idx) {
                              final p = filtered[idx];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F9FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    color: Color(0xFF0886B5),
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  p.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                subtitle: Text(
                                  'SKU: ${p.codigo} · ${p.unidad}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                trailing: Text(
                                  '\$${p.precio.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                                onTap: () => Navigator.of(context).pop(p),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// FUNCIÓN AUXILIAR DE FORMATEO DE FECHA Y HORA DE SINCRONIZACIÓN
// =============================================================================

String _formatSyncDateTime(String rawStr, {String? fallbackDate}) {
  final clean = rawStr.trim();
  if (clean.isEmpty) return '';

  // 1. Si ya contiene fecha y hora con espacio o T: ej. "2026-10-06 17:19:00" o "2026-10-06T17:19:00"
  final regExpFull = RegExp(r'^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})');
  final matchFull = regExpFull.firstMatch(clean);
  if (matchFull != null) {
    return '${matchFull.group(1)} ${matchFull.group(2)}';
  }

  // 2. Intenta parsear como DateTime ISO completo
  final dt = DateTime.tryParse(clean);
  if (dt != null) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
  }

  // 3. Si solo tiene hora (ej: "17:19" o "17:19:00")
  final regExpTime = RegExp(r'^(\d{2}:\d{2})');
  final matchTime = regExpTime.firstMatch(clean);
  if (matchTime != null) {
    final defaultDate = (fallbackDate != null &&
            fallbackDate.isNotEmpty &&
            RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(fallbackDate))
        ? fallbackDate.substring(0, 10)
        : DateFormat('yyyy-MM-dd').format(DateTime.now());
    return '$defaultDate ${matchTime.group(1)}';
  }

  return clean;
}

// =============================================================================
// CENTRO COMPLETO DE PREVENTA: CLIENTES, CATÁLOGO Y PEDIDOS
// Ronda 31 (a=clientes, a=catalogo, tipo="pedido", tipo="cliente")
// =============================================================================

class OrdersAndNewClientsView extends ConsumerStatefulWidget {
  final int? visitRouteIdForOutOfRoute;
  final Widget? topDateBar;
  final Widget? authBanner;

  const OrdersAndNewClientsView({
    super.key,
    this.visitRouteIdForOutOfRoute,
    this.topDateBar,
    this.authBanner,
  });

  @override
  ConsumerState<OrdersAndNewClientsView> createState() =>
      _OrdersAndNewClientsViewState();
}

class _OrdersAndNewClientsViewState
    extends ConsumerState<OrdersAndNewClientsView>
    with SingleTickerProviderStateMixin {
  late TabController _preventaTabCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _catalogSearchCtrl = TextEditingController();
  Timer? _debounce;
  bool _filterPorAprobarOnly = false;

  @override
  void initState() {
    super.initState();
    _preventaTabCtrl = TabController(length: 3, vsync: this);
    _preventaTabCtrl.addListener(() {
      if (!_preventaTabCtrl.indexIsChanging) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(routesProvider.notifier).loadClientsFromServer();
    });
  }

  @override
  void dispose() {
    _preventaTabCtrl.dispose();
    _debounce?.cancel();
    _searchCtrl.dispose();
    _catalogSearchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (val.trim().isNotEmpty) {
        ref
            .read(routesProvider.notifier)
            .loadClientsFromServer(query: val.trim());
      }
    });
  }

  Future<void> _openNewClientDialog() async {
    final createdClient = await showModalBottomSheet<RouteClient>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewClientFormSheet(),
    );

    if (createdClient != null && mounted) {
      await _openStandaloneOrderSheet(createdClient);
    }
  }

  Future<void> _openStandaloneOrderSheet(RouteClient client) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StandaloneOrderSheet(client: client),
    );
  }

  Future<void> _launchPhoneCall(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchNavigation(RouteClient client) async {
    Uri uri;
    if (client.lat != 0 || client.lng != 0) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${client.lat},${client.lng}&travelmode=driving',
      );
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(client.direccion)}',
      );
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routesProvider);
    final permisos = state.session?.permisos ?? const DriverPermissions();
    final allClients = state.clients;
    final query = _searchCtrl.text.trim().toLowerCase();
    final hasSearchQuery = query.isNotEmpty;

    List<RouteClient> clients;
    if (_filterPorAprobarOnly) {
      clients = allClients.where((c) => c.porAprobar).toList();
      if (hasSearchQuery) {
        clients = clients.where((c) {
          return c.nombre.toLowerCase().contains(query) ||
              c.codigo.toLowerCase().contains(query) ||
              c.telefono.contains(query);
        }).toList();
      }
    } else if (hasSearchQuery) {
      clients = allClients.where((c) {
        return c.nombre.toLowerCase().contains(query) ||
            c.codigo.toLowerCase().contains(query) ||
            c.telefono.contains(query) ||
            c.direccion.toLowerCase().contains(query);
      }).toList();
    } else {
      // Solo mostrar clientes si el usuario escribe en el buscador
      clients = [];
    }

    // Pedidos en cola local o rechazados
    final pendingOrders =
        state.pendingActions.where((a) => a.tipo == 'pedido').toList();
    final totalOrdersCount = pendingOrders.length + state.syncedOrders.length;

    final porAprobarCount = allClients.where((c) => c.porAprobar).length;
    final clientTabText = hasSearchQuery
        ? 'Clientes (${clients.length})'
        : (_filterPorAprobarOnly
            ? 'Por Aprobar ($porAprobarCount)'
            : 'Clientes');

    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isSmallScreen = mediaQuery.size.width < 360;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Container(
        color: const Color(0xFFF8FAFC),
        child: RefreshIndicator(
          color: const Color(0xFF0886B5),
          onRefresh: () async {
            if (_preventaTabCtrl.index == 0) {
              await ref
                  .read(routesProvider.notifier)
                  .loadClientsFromServer(query: _searchCtrl.text.trim());
            } else if (_preventaTabCtrl.index == 1) {
              await ref.read(routesProvider.notifier).loadCatalogFromServer();
            } else {
              await ref
                  .read(routesProvider.notifier)
                  .syncPendingQueueAndRefreshDay();
            }
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Selector de fecha y sincronización (Calendario)
              if (widget.topDateBar != null)
                SliverToBoxAdapter(child: widget.topDateBar!),
              if (widget.authBanner != null)
                SliverToBoxAdapter(child: widget.authBanner!),

              // 2. Sub-pestañas operativas (Clientes, Catálogo, Pedidos) fijas arriba al scrollear
              SliverPersistentHeader(
                pinned: true,
                delegate: _PreventaSubTabsHeaderDelegate(
                  height: 52,
                  child: Container(
                    color: const Color(0xFFF8FAFC),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _preventaTabCtrl,
                        onTap: (index) => setState(() {}),
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
                            fontWeight: FontWeight.w700, fontSize: 11.5),
                        unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 11.5),
                        tabs: [
                          Tab(
                            height: 36,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people_alt_rounded, size: 15),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    clientTabText,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Tab(
                            height: 36,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.inventory_2_rounded, size: 15),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'Catálogo (${state.catalog.length})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Tab(
                            height: 36,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.receipt_long_rounded,
                                    size: 15),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'Pedidos ($totalOrdersCount)',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Contenido dinámico según la sub-pestaña activa
              if (_preventaTabCtrl.index == 0)
                ..._buildClientsSlivers(clients, permisos, state)
              else if (_preventaTabCtrl.index == 1)
                ..._buildCatalogSlivers(state.catalog)
              else
                ..._buildOrdersHistorySlivers(pendingOrders, state),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildClientsSlivers(
    List<RouteClient> clients,
    DriverPermissions permisos,
    RoutesState state,
  ) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.normal,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, código o teléfono...',
                      hintStyle: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.normal,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF64748B),
                        size: 18,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  size: 15, color: Color(0xFF64748B)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 0),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF0886B5), width: 1.2),
                      ),
                    ),
                  ),
                ),
              ),
              if (permisos.clientesNuevos) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0886B5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _openNewClientDialog,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text(
                      'Nuevo',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              FilterChip(
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                label: const Text('Todos'),
                labelStyle: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: !_filterPorAprobarOnly
                      ? Colors.white
                      : const Color(0xFF64748B),
                ),
                selected: !_filterPorAprobarOnly,
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: !_filterPorAprobarOnly
                        ? Colors.transparent
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                onSelected: (_) =>
                    setState(() => _filterPorAprobarOnly = false),
              ),
              const SizedBox(width: 8),
              FilterChip(
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                label: Text(
                  'Por Aprobar (${state.clients.where((c) => c.porAprobar).length})',
                ),
                labelStyle: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _filterPorAprobarOnly
                      ? const Color(0xFF92400E)
                      : const Color(0xFF64748B),
                ),
                selected: _filterPorAprobarOnly,
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFFFEF3C7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: _filterPorAprobarOnly
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                onSelected: (val) =>
                    setState(() => _filterPorAprobarOnly = val),
              ),
            ],
          ),
        ),
      ),
      if (clients.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _searchCtrl.text.trim().isNotEmpty
                        ? Icons.search_off_rounded
                        : Icons.search_rounded,
                    size: 36,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _searchCtrl.text.trim().isNotEmpty
                      ? 'No se encontraron clientes'
                      : (_filterPorAprobarOnly
                          ? 'No hay clientes por aprobar'
                          : 'Buscar clientes'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _searchCtrl.text.trim().isNotEmpty
                      ? 'Ningún cliente coincide con "${_searchCtrl.text.trim()}".'
                      : (_filterPorAprobarOnly
                          ? 'No tienes clientes nuevos en espera de aprobación.'
                          : 'Escribe en el buscador de arriba para encontrar clientes por nombre, código o teléfono.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, idx) {
                final c = clients[idx];
                return _buildClientCard(c, permisos);
              },
              childCount: clients.length,
            ),
          ),
        ),
    ];
  }

  Widget _buildClientCard(RouteClient c, DriverPermissions permisos) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: c.porAprobar
                      ? const Color(0xFFFFFBEB)
                      : const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: c.porAprobar
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFFBAE6FD),
                  ),
                ),
                child: Center(
                  child: Icon(
                    c.porAprobar
                        ? Icons.hourglass_top_rounded
                        : Icons.storefront_rounded,
                    color: c.porAprobar
                        ? const Color(0xFFD97706)
                        : const Color(0xFF0284C7),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.nombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (c.porAprobar)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                              ),
                            ),
                            child: const Text(
                              'POR APROBAR',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB45309),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (c.codigo.isNotEmpty) 'Cód: ${c.codigo}',
                        if (c.contacto.isNotEmpty) 'Contacto: ${c.contacto}',
                        if (c.telefono.isNotEmpty) 'Tel: ${c.telefono}',
                      ].join(' · '),
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
          if (c.direccion.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 50),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      c.direccion,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (c.obs.isNotEmpty) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 50),
              child: Text(
                'Nota: ${c.obs}',
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
          if (c.diasVisita.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 50),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 11,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Días de visita: ${c.diasVisita}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (c.telefono.isNotEmpty) ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF334155),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(38, 38),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _launchPhoneCall(c.telefono),
                      child: const Icon(Icons.phone_outlined,
                          size: 16, color: Color(0xFF475569)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(38, 38),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _launchNavigation(c),
                    child: const Icon(Icons.navigation_outlined,
                        size: 16, color: Color(0xFF475569)),
                  ),
                ],
              ),
              if (permisos.pedidos)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    minimumSize: const Size(0, 38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _openStandaloneOrderSheet(c),
                  icon: const Icon(Icons.shopping_cart_checkout_rounded,
                      size: 15),
                  label: const Text(
                    'Levantar Pedido',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
            ],
          ),
          if (widget.visitRouteIdForOutOfRoute != null && c.id > 0) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  side: const BorderSide(
                    color: Color(0xFF0284C7),
                    width: 1.2,
                  ),
                  backgroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VisitRecordPage(
                        idRuta: widget.visitRouteIdForOutOfRoute!,
                        client: c,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.storefront_rounded,
                    size: 16, color: Color(0xFF0284C7)),
                label: const Text(
                  'Visita fuera de ruta',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildCatalogSlivers(List<CatalogProduct> catalog) {
    final query = _catalogSearchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? catalog
        : catalog.where((p) {
            return p.nombre.toLowerCase().contains(query) ||
                p.codigo.toLowerCase().contains(query);
          }).toList();

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _catalogSearchCtrl,
              onChanged: (_) => setState(() {}),
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.normal,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Buscar producto por nombre o SKU...',
                hintStyle: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.normal,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF64748B),
                  size: 18,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                suffixIcon: _catalogSearchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 15, color: Color(0xFF64748B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () {
                          _catalogSearchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF0886B5), width: 1.2),
                ),
              ),
            ),
          ),
        ),
      ),
      if (filtered.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 70),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    size: 36,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  query.isNotEmpty
                      ? 'No se encontraron productos'
                      : 'Catálogo vacío',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  query.isNotEmpty
                      ? 'Ningún producto coincide con "$query".'
                      : 'No hay productos disponibles en el catálogo. Desliza hacia abajo para sincronizar con el servidor.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, idx) {
                final p = filtered[idx];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            Icons.inventory_2_rounded,
                            color: Color(0xFF0284C7),
                            size: 19,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              p.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'SKU: ${p.codigo} · Presentación: ${p.unidad}',
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
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          '\$${p.precio.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: filtered.length,
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildOrdersHistorySlivers(
    List<QueuedAction> pendingOrders,
    RoutesState state,
  ) {
    final syncedOrders = state.syncedOrders;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SECCIÓN: PEDIDOS EN COLA LOCAL (PENDIENTES DE SUBIR)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Cola Local (Por Sincronizar)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: pendingOrders.isNotEmpty
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${pendingOrders.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: pendingOrders.isNotEmpty
                                ? const Color(0xFFB45309)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (pendingOrders.isNotEmpty)
                    IconButton(
                      onPressed: state.isSyncing
                          ? null
                          : () => ref
                              .read(routesProvider.notifier)
                              .syncPendingQueueAndRefreshDay(),
                      icon: state.isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded),
                      tooltip: 'Sincronizar ahora',
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (pendingOrders.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          color: Color(0xFF10B981), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sin pedidos pendientes por subir. Todo está sincronizado.',
                          style:
                              TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...pendingOrders.map((act) {
                  final payload = act.payload;
                  final lineas = payload['lineas'] as List<dynamic>? ?? [];
                  final fecha =
                      payload['fecha']?.toString() ?? 'Próxima visita';
                  String clienteNombre = (payload['cliente'] ?? '').toString();
                  if (clienteNombre.isEmpty && payload['idCliente'] != null) {
                    final idC = int.tryParse(payload['idCliente'].toString());
                    final found =
                        state.clients.where((c) => c.id == idC).firstOrNull;
                    if (found != null) clienteNombre = found.nombre;
                  }
                  if (clienteNombre.isEmpty && payload['clienteUuid'] != null) {
                    final cUuid = payload['clienteUuid'].toString();
                    final found = state.clients
                        .where((c) => c.localUuid == cUuid)
                        .firstOrNull;
                    if (found != null) clienteNombre = found.nombre;
                  }
                  if (clienteNombre.isEmpty) clienteNombre = 'Pedido local';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openOrderDetailsModal(localAction: act),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      clienteNombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.cloud_upload_outlined,
                                            size: 12, color: Color(0xFFB45309)),
                                        SizedBox(width: 4),
                                        Text(
                                          'EN COLA',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFB45309),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Folio local: ${act.uuid.substring(0, 8)} · ${lineas.length} producto(s) · Entrega: $fecha',
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Capturado: ${_formatSyncDateTime(act.createdAt, fallbackDate: fecha)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Row(
                                    children: [
                                      Text(
                                        'Ver productos',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0886B5),
                                        ),
                                      ),
                                      SizedBox(width: 2),
                                      Icon(Icons.chevron_right_rounded,
                                          size: 14, color: Color(0xFF0886B5)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 20),

              // 2. SECCIÓN: PEDIDOS CONFIRMADOS / SINCRONIZADOS EN EL SERVIDOR HOY
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Pedidos Confirmados en Servidor',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: syncedOrders.isNotEmpty
                              ? const Color(0xFFD1FAE5)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${syncedOrders.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: syncedOrders.isNotEmpty
                                ? const Color(0xFF047857)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (syncedOrders.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text(
                      'Aún no hay pedidos confirmados en el servidor en esta sesión.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ),
                )
              else
                ...syncedOrders.map((ord) {
                  final isDiscarded =
                      _isOrderClientDiscarded(ord, state.clients);
                  final isPending = _isOrderPendingApproval(ord, state.clients);

                  Color borderColor = const Color(0xFFA7F3D0);
                  Color cardBg = Colors.white;
                  if (isDiscarded) {
                    borderColor = const Color(0xFFFECACA);
                    cardBg = const Color(0xFFFFF8F8);
                  } else if (isPending) {
                    borderColor = const Color(0xFFFDE68A);
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: isDiscarded
                              ? const Color(0xFFFECACA)
                              : const Color(0xFFE2E8F0),
                          width: isDiscarded ? 1.5 : 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openOrderDetailsModal(syncedOrder: ord),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      ord.cliente,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isDiscarded) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEE2E2),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.cancel_rounded,
                                                  size: 12,
                                                  color: Color(0xFFDC2626)),
                                              SizedBox(width: 4),
                                              Text(
                                                'NO APLICADO',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFFDC2626),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ] else if (isPending) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.hourglass_top_rounded,
                                                  size: 12,
                                                  color: Color(0xFFB45309)),
                                              SizedBox(width: 4),
                                              Text(
                                                'POR APROBAR',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFFB45309),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ] else ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD1FAE5),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_circle_rounded,
                                                  size: 12,
                                                  color: Color(0xFF047857)),
                                              SizedBox(width: 4),
                                              Text(
                                                'APLICADO',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF047857),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Folio: ${ord.referencia} · ${ord.totalLineas} producto(s) · Entrega: ${ord.fecha}',
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF475569)),
                              ),
                              if (isDiscarded) ...[
                                const SizedBox(height: 4),
                                const Row(
                                  children: [
                                    Icon(Icons.error_outline_rounded,
                                        size: 13, color: Color(0xFFDC2626)),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'No se dio de alta el cliente (pedido cancelado)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (isPending) ...[
                                const SizedBox(height: 2),
                                const Text(
                                  'Cliente nuevo (pedido en espera de alta)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFB45309),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (ord.sincronizadoHora.isNotEmpty)
                                    Expanded(
                                      child: Text(
                                        'Sincronizado: ${_formatSyncDateTime(ord.sincronizadoHora, fallbackDate: ord.fecha)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF94A3B8)),
                                      ),
                                    )
                                  else
                                    const Spacer(),
                                  const SizedBox(width: 8),
                                  Row(
                                    children: [
                                      if (isDiscarded) ...[
                                        InkWell(
                                          onTap: () =>
                                              _confirmDeleteSyncedOrder(ord),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            child: Row(
                                              children: [
                                                Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 14,
                                                    color: Color(0xFFDC2626)),
                                                SizedBox(width: 3),
                                                Text(
                                                  'Eliminar',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFFDC2626),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      Text(
                                        'Ver productos',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: isDiscarded
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFF0886B5),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(Icons.chevron_right_rounded,
                                          size: 14,
                                          color: isDiscarded
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFF0886B5)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    ];
  }

  bool _isOrderClientDiscarded(SyncedOrder ord, List<RouteClient> clients) {
    if (!ord.porAprobar) return false;
    final normName = ord.cliente.trim().toLowerCase();
    final clientExists = clients.any((c) {
      if (ord.idCliente != null &&
          ord.idCliente! > 0 &&
          c.id == ord.idCliente) {
        return true;
      }
      return c.nombre.trim().toLowerCase() == normName;
    });
    return !clientExists;
  }

  bool _isOrderPendingApproval(SyncedOrder ord, List<RouteClient> clients) {
    if (!ord.porAprobar) return false;
    final normName = ord.cliente.trim().toLowerCase();
    final client = clients.cast<RouteClient?>().firstWhere(
          (c) =>
              (ord.idCliente != null &&
                  ord.idCliente! > 0 &&
                  c?.id == ord.idCliente) ||
              (c?.nombre.trim().toLowerCase() == normName),
          orElse: () => null,
        );
    return client != null && client.porAprobar;
  }

  Future<void> _confirmDeleteSyncedOrder(SyncedOrder ord) async {
    await showDeleteOrderDialogAndExecute(
      context: context,
      ref: ref,
      referencia: ord.referencia,
      cliente: ord.cliente,
      isDiscarded:
          _isOrderClientDiscarded(ord, ref.read(routesProvider).clients),
    );
  }

  void _openOrderDetailsModal({
    QueuedAction? localAction,
    SyncedOrder? syncedOrder,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailsModal(
        localAction: localAction,
        syncedOrder: syncedOrder,
      ),
    );
  }
}

Future<void> showDeleteOrderDialogAndExecute({
  required BuildContext context,
  required WidgetRef ref,
  required String referencia,
  required String cliente,
  bool isDiscarded = false,
  VoidCallback? onDeleted,
}) async {
  bool isDeleting = false;

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return PopScope(
            canPop: !isDeleting,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Text(
                    'Eliminar Pedido',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              content: Text(
                '¿Deseas eliminar este pedido con folio "$referencia" ($cliente) de tu historial local?',
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
              actions: [
                if (!isDeleting)
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                LoadingActionButton(
                  width: 104,
                  height: 38,
                  borderRadius: 8,
                  fontSize: 13,
                  loadingSize: 20,
                  backgroundColor: const Color(0xFFDC2626),
                  text: 'Eliminar',
                  isLoading: isDeleting,
                  onPressed: () async {
                    setDialogState(() => isDeleting = true);
                    // Reload ficticio (simulación visual suave)
                    await Future.delayed(const Duration(milliseconds: 700));
                    await ref
                        .read(routesProvider.notifier)
                        .deleteSyncedOrder(referencia);
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop(true);
                    }
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );

  if (confirmed == true && context.mounted) {
    onDeleted?.call();
    _showEliminadoTopSnackBar(context);
  }
}

void _showEliminadoTopSnackBar(BuildContext context) {
  SnackbarTop.showSuccess(
    context,
    'Eliminado',
    style: SnackbarTopStyle.appleCard,
  );
}

class _PreventaSubTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _PreventaSubTabsHeaderDelegate({required this.child, required this.height});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _PreventaSubTabsHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}

// =============================================================================
// MODAL DE DETALLE COMPLETO DEL PEDIDO (LOCAL O CONFIRMADO)
// =============================================================================

class _OrderDetailsModal extends ConsumerWidget {
  final QueuedAction? localAction;
  final SyncedOrder? syncedOrder;

  const _OrderDetailsModal({
    this.localAction,
    this.syncedOrder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(routesProvider);
    final catalog = state.catalog;

    final bool isLocal = localAction != null;
    final Map<String, dynamic> payload = localAction?.payload ?? {};

    // 1. Extraer Folio / Referencia
    final String referencia = isLocal
        ? 'APP-${localAction!.uuid.substring(0, 8)}'
        : (syncedOrder?.referencia ?? 'APP-PEDIDO');

    // 2. Extraer Cliente
    String clienteNombre = isLocal
        ? (payload['cliente'] ?? '').toString()
        : (syncedOrder?.cliente ?? 'Cliente');
    if (clienteNombre.isEmpty && payload['idCliente'] != null) {
      final idC = int.tryParse(payload['idCliente'].toString());
      final found = state.clients.where((c) => c.id == idC).firstOrNull;
      if (found != null) clienteNombre = found.nombre;
    }
    if (clienteNombre.isEmpty && payload['clienteUuid'] != null) {
      final cUuid = payload['clienteUuid'].toString();
      final found =
          state.clients.where((c) => c.localUuid == cUuid).firstOrNull;
      if (found != null) clienteNombre = found.nombre;
    }
    if (clienteNombre.isEmpty) clienteNombre = 'Cliente';

    // 3. Extraer Fecha y Hora
    final String fecha = isLocal
        ? (payload['fecha']?.toString() ?? 'Próxima visita')
        : (syncedOrder?.fecha ?? 'Próxima visita');
    final String hora = isLocal
        ? (localAction?.createdAt ?? '')
        : (syncedOrder?.sincronizadoHora ?? '');

    final String horaFormatted = _formatSyncDateTime(
      hora,
      fallbackDate: isLocal ? payload['fecha']?.toString() : syncedOrder?.fecha,
    );

    // 4. Extraer Líneas de Productos
    final List<dynamic> rawLineas = isLocal
        ? (payload['lineas'] as List<dynamic>? ?? [])
        : (syncedOrder?.rawLineas ?? []);

    // 5. Cruzar con el catálogo para nombres, sku y precios
    double totalEstimado = 0.0;
    final List<Map<String, dynamic>> resolvedLines = [];

    for (final item in rawLineas) {
      if (item is Map) {
        final idProd = int.tryParse((item['idProducto'] ?? '').toString()) ?? 0;
        final cant = int.tryParse((item['cantidad'] ?? '1').toString()) ?? 1;
        final prod = catalog.where((p) => p.idProducto == idProd).firstOrNull;

        final nombre =
            prod?.nombre ?? (item['nombre'] ?? 'Producto #$idProd').toString();
        final codigo = prod?.codigo ?? (item['codigo'] ?? '').toString();
        final unidad = prod?.unidad ?? (item['unidad'] ?? '').toString();
        final precio = prod?.precio ??
            (item['precio'] != null
                ? double.tryParse(item['precio'].toString()) ?? 0.0
                : 0.0);
        final subtotal = precio * cant;
        totalEstimado += subtotal;

        resolvedLines.add({
          'idProducto': idProd,
          'nombre': nombre,
          'codigo': codigo,
          'unidad': unidad,
          'precio': precio,
          'cantidad': cant,
          'subtotal': subtotal,
        });
      }
    }

    final bool isDiscarded = !isLocal &&
        syncedOrder != null &&
        syncedOrder!.porAprobar &&
        !state.clients.any((c) {
          if (syncedOrder!.idCliente != null &&
              syncedOrder!.idCliente! > 0 &&
              c.id == syncedOrder!.idCliente) {
            return true;
          }
          return c.nombre.trim().toLowerCase() ==
              syncedOrder!.cliente.trim().toLowerCase();
        });
    final bool isPending = !isLocal &&
        syncedOrder != null &&
        syncedOrder!.porAprobar &&
        !isDiscarded &&
        state.clients.any((c) =>
            ((syncedOrder!.idCliente != null &&
                    syncedOrder!.idCliente! > 0 &&
                    c.id == syncedOrder!.idCliente) ||
                (c.nombre.trim().toLowerCase() ==
                    syncedOrder!.cliente.trim().toLowerCase())) &&
            c.porAprobar);

    Color badgeBg = const Color(0xFFDCFCE7);
    Color badgeFg = const Color(0xFF15803D);
    Color badgeBorder = const Color(0xFF86EFAC);
    IconData badgeIcon = Icons.check_circle_rounded;
    String badgeText = 'APLICADO';

    if (isLocal) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeFg = const Color(0xFFB45309);
      badgeBorder = const Color(0xFFFDE68A);
      badgeIcon = Icons.cloud_upload_outlined;
      badgeText = 'EN COLA (Local)';
    } else if (isDiscarded) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeFg = const Color(0xFFDC2626);
      badgeBorder = const Color(0xFFFECACA);
      badgeIcon = Icons.cancel_rounded;
      badgeText = 'NO APLICADO';
    } else if (isPending) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeFg = const Color(0xFFB45309);
      badgeBorder = const Color(0xFFFDE68A);
      badgeIcon = Icons.hourglass_top_rounded;
      badgeText = 'POR APROBAR';
    }

    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final screenHeight = mediaQuery.size.height;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 580,
            maxHeight: isLandscape ? screenHeight * 0.94 : screenHeight * 0.85,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isLandscape ? 16 : 20,
                  isLandscape ? 10 : 12,
                  isLandscape ? 16 : 20,
                  isLandscape ? 12 : 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: EdgeInsets.only(bottom: isLandscape ? 8 : 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header con título y badge de estado
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            'Detalle del Pedido',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isLandscape ? 18 : 20,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: badgeBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                badgeIcon,
                                size: 13,
                                color: badgeFg,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                badgeText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: badgeFg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isLandscape ? 8 : 12),

                    // Contenido scrollable
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Chip de Folio no amontonado
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.tag_rounded,
                                      size: 13, color: Color(0xFF64748B)),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'Folio: ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      referencia,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'monospace',
                                        color: Color(0xFF1E293B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isLandscape ? 10 : 16),

                            // Tarjeta de información del cliente y entrega
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(isLandscape ? 12 : 16),
                              decoration: BoxDecoration(
                                color: isDiscarded
                                    ? const Color(0xFFFFF8F8)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDiscarded
                                      ? const Color(0xFFFECACA)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.storefront_outlined,
                                        size: isLandscape ? 18 : 20,
                                        color: isDiscarded
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF0886B5),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'CLIENTE',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              clienteNombre,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: isLandscape ? 14 : 15,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    height: 1,
                                    color: const Color(0xFFE2E8F0),
                                    margin: EdgeInsets.symmetric(
                                        vertical: isLandscape ? 8 : 12),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.calendar_today_outlined,
                                              size: 13,
                                              color: Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Entrega programada',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Color(0xFF94A3B8),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  Text(
                                                    fecha,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF334155),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (hora.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.schedule_rounded,
                                                size: 14,
                                                color: Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      isLocal
                                                          ? 'Capturado'
                                                          : 'Sincronizado',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color:
                                                            Color(0xFF94A3B8),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    Text(
                                                      horaFormatted,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            Color(0xFF334155),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (isDiscarded) ...[
                                    SizedBox(height: isLandscape ? 8 : 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: const Color(0xFFFCA5A5)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.error_outline_rounded,
                                              size: 15,
                                              color: Color(0xFFDC2626)),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'No se dio de alta el cliente. El pedido no se aplicó y fue cancelado.',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFDC2626),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            SizedBox(height: isLandscape ? 12 : 18),

                            // Encabezado de la lista de productos
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 16,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Artículos del Pedido (${resolvedLines.length})',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${resolvedLines.fold<int>(0, (sum, i) => sum + (i['cantidad'] as int? ?? 1))} uds.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Lista de productos
                            if (resolvedLines.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: Text(
                                    'No hay productos registrados en este pedido.',
                                    style: TextStyle(color: Color(0xFF64748B)),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: resolvedLines.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, idx) {
                                  final item = resolvedLines[idx];
                                  final sub = item['subtotal'] as double;
                                  final p = item['precio'] as double;
                                  final c = item['cantidad'] as int;

                                  return Container(
                                    padding:
                                        EdgeInsets.all(isLandscape ? 10 : 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${c}x',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['nombre'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${item['codigo'].isNotEmpty ? '${item['codigo']} · ' : ''}\$${p.toStringAsFixed(2)}${item['unidad'].isNotEmpty ? ' / ${item['unidad']}' : ''}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '\$${sub.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            SizedBox(height: isLandscape ? 10 : 14),

                            // Tarjeta Resumen Total
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: isLandscape ? 10 : 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'TOTAL ESTIMADO',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${resolvedLines.length} ${resolvedLines.length == 1 ? 'producto' : 'productos'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF94A3B8),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '\$${totalEstimado.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: isLandscape ? 18 : 20,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isLandscape ? 8 : 12),

                    // Botones inferiores
                    Row(
                      children: [
                        if (isLocal) ...[
                          Expanded(
                            flex: 3,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0886B5),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: isLandscape ? 10 : 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                ref
                                    .read(routesProvider.notifier)
                                    .syncPendingQueueAndRefreshDay();
                              },
                              icon: const Icon(Icons.sync_rounded, size: 18),
                              label: const Text(
                                'Sincronizar ahora',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ] else if (syncedOrder != null) ...[
                          Expanded(
                            flex: 3,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFFFEF2F2),
                                foregroundColor: const Color(0xFFDC2626),
                                side:
                                    const BorderSide(color: Color(0xFFFECACA)),
                                padding: EdgeInsets.symmetric(
                                    vertical: isLandscape ? 10 : 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () async {
                                final nav = Navigator.of(context);
                                await showDeleteOrderDialogAndExecute(
                                  context: context,
                                  ref: ref,
                                  referencia: syncedOrder!.referencia,
                                  cliente: syncedOrder!.cliente,
                                  isDiscarded: isDiscarded,
                                  onDeleted: () => nav.pop(),
                                );
                              },
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18),
                              label: Text(
                                isDiscarded
                                    ? 'Eliminar no aplicado'
                                    : 'Eliminar del historial',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: isLandscape ? 12 : 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0886B5),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                  vertical: isLandscape ? 10 : 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Cerrar',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: isLandscape ? 13 : 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ALTA DE CLIENTE NUEVO (tipo = "cliente")
// =============================================================================

class _NewClientFormSheet extends ConsumerStatefulWidget {
  const _NewClientFormSheet();

  @override
  ConsumerState<_NewClientFormSheet> createState() =>
      _NewClientFormSheetState();
}

class _NewClientFormSheetState extends ConsumerState<_NewClientFormSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _calleCtrl = TextEditingController();
  final _numCtrl = TextEditingController();
  final _coloniaCtrl = TextEditingController();
  final _cpCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _contactCtrl.dispose();
    _notesCtrl.dispose();
    _calleCtrl.dispose();
    _numCtrl.dispose();
    _coloniaCtrl.dispose();
    _cpCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveClient() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showServerNoticesFeedback(context, const [
        ServerNotice(
          nivel: 'error',
          codigo: 'CLIENTE_DATOS',
          texto: 'El nombre del negocio / cliente es obligatorio.',
        ),
      ]);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(routesProvider.notifier);
      final pos = await notifier.getFreshPositionNonBlocking();
      final dirMap = {
        'calle': _calleCtrl.text.trim(),
        'numero': _numCtrl.text.trim(),
        'colonia': _coloniaCtrl.text.trim(),
        'cp': _cpCtrl.text.trim(),
      };

      if (pos == null && dirMap.values.every((v) => v.isEmpty)) {
        showServerNoticesFeedback(context, const [
          ServerNotice(
            nivel: 'error',
            codigo: 'CLIENTE_UBICACION',
            texto:
                'Falta dónde está el cliente: active el GPS frente al negocio o capture la dirección.',
          ),
        ]);
        return;
      }

      final clientUuid = await notifier.registrarClienteNuevo(
        nombre: _nameCtrl.text,
        telefono: _phoneCtrl.text,
        contacto: _contactCtrl.text,
        notas: _notesCtrl.text,
        direccion: dirMap,
      );

      if (!mounted) return;
      final recent = ref.read(routesProvider).recentNotices;
      showServerNoticesFeedback(
        context,
        recent,
        fallbackSuccessMessage:
            'Cliente registrado (pendiente de alta). Ya puede levantarle pedidos.',
      );

      Navigator.of(context).pop(
        RouteClient(
          id: 0,
          codigo: 'APP-${clientUuid.substring(0, 6).toUpperCase()}',
          nombre: _nameCtrl.text.trim(),
          telefono: _phoneCtrl.text.trim(),
          contacto: _contactCtrl.text.trim(),
          direccion: dirMap.values.where((v) => v.isNotEmpty).join(', '),
          porAprobar: true,
          localUuid: clientUuid,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration fieldDeco(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF0886B5)),
        filled: true,
        fillColor:
            _isSaving ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.03)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0886B5), width: 1.5),
        ),
      );
    }

    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isSmallScreen = mediaQuery.size.width < 360;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: AbsorbPointer(
              absorbing: _isSaving,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 44,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Color(0xFF0886B5),
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alta de Cliente Nuevo',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Registro de prospecto (pendiente de alta)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nameCtrl,
                      enabled: !_isSaving,
                      decoration: fieldDeco(
                          'Nombre del negocio *', Icons.storefront_rounded),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _contactCtrl,
                            enabled: !_isSaving,
                            decoration: fieldDeco(
                                'Contacto / Encargado', Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _phoneCtrl,
                            enabled: !_isSaving,
                            keyboardType: TextInputType.phone,
                            decoration:
                                fieldDeco('Teléfono', Icons.phone_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _calleCtrl,
                            enabled: !_isSaving,
                            decoration:
                                fieldDeco('Calle', Icons.location_on_outlined),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _numCtrl,
                            enabled: !_isSaving,
                            decoration: fieldDeco('Número', Icons.tag_rounded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _coloniaCtrl,
                            enabled: !_isSaving,
                            decoration:
                                fieldDeco('Colonia', Icons.map_outlined),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _cpCtrl,
                            enabled: !_isSaving,
                            keyboardType: TextInputType.number,
                            decoration: fieldDeco(
                                'C.P.', Icons.local_post_office_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _notesCtrl,
                      enabled: !_isSaving,
                      decoration: fieldDeco(
                        'Notas / Referencias (ej. Junto a la farmacia)',
                        Icons.notes_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LoadingActionButton(
                      text: 'Registrar Cliente',
                      isLoading: _isSaving,
                      onPressed: _saveClient,
                      icon: Icons.save_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// MODAL PARA LEVANTAR PEDIDO SUELTO (tipo = "pedido")
// =============================================================================

class _StandaloneOrderSheet extends ConsumerStatefulWidget {
  final RouteClient client;

  const _StandaloneOrderSheet({required this.client});

  @override
  ConsumerState<_StandaloneOrderSheet> createState() =>
      _StandaloneOrderSheetState();
}

class _StandaloneOrderSheetState extends ConsumerState<_StandaloneOrderSheet> {
  final List<_EditableVisitLine> _lines = [];
  String? _fecha;
  bool _isSaving = false;

  Future<void> _addProduct() async {
    if (_isSaving) return;
    final catalog = ref.read(routesProvider).catalog;
    final selected = await showModalBottomSheet<CatalogProduct>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CatalogSearchModal(catalog: catalog),
    );
    if (selected != null) {
      setState(() {
        final idx =
            _lines.indexWhere((l) => l.idProducto == selected.idProducto);
        if (idx >= 0) {
          _lines[idx].cantidad++;
        } else {
          _lines.add(
            _EditableVisitLine(
              idProducto: selected.idProducto,
              codigo: selected.codigo,
              nombre: selected.nombre,
              unidad: selected.unidad,
              precio: selected.precio,
              cantidad: 1,
            ),
          );
        }
      });
    }
  }

  Future<void> _submitOrder() async {
    if (_isSaving) return;
    final valid = _lines.where((l) => l.cantidad > 0).toList();
    if (valid.isEmpty) {
      showServerNoticesFeedback(context, const [
        ServerNotice(
          nivel: 'error',
          codigo: 'VACIA',
          texto: 'Agregue al menos un producto al pedido.',
        ),
      ]);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final res = await ref.read(routesProvider.notifier).registrarPedidoSuelto(
            idCliente: widget.client.id > 0 ? widget.client.id : null,
            clienteUuid: widget.client.localUuid,
            clienteNombre: widget.client.nombre,
            lineas: valid
                .map((l) => {
                      'idProducto': l.idProducto,
                      'cantidad': l.cantidad,
                      'nombre': l.nombre,
                      'precio': l.precio,
                    })
                .toList(),
            fecha: _fecha,
          );
      if (!mounted) return;
      showServerNoticesFeedback(
        context,
        res.avisos,
        fallbackSuccessMessage:
            'Pedido levantado para ${widget.client.nombre}.',
      );
      if (res.queuedOrApplied) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _lines.fold<double>(
      0,
      (sum, l) => sum + (l.precio * l.cantidad),
    );

    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final screenHeight = mediaQuery.size.height;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: PopScope(
        canPop: !_isSaving,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 580,
              maxHeight:
                  isLandscape ? screenHeight * 0.94 : screenHeight * 0.85,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isLandscape ? 16 : 20,
                    isLandscape ? 10 : 20,
                    isLandscape ? 16 : 20,
                    isLandscape ? 12 : 20,
                  ),
                  child: AbsorbPointer(
                    absorbing: _isSaving,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.receipt_long_rounded,
                              color: Color(0xFF0886B5),
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pedido: ${widget.client.nombre}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _fecha != null
                                        ? 'Entrega: $_fecha'
                                        : 'Próxima visita programada',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0886B5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0F172A),
                                backgroundColor: const Color(0xFFF8FAFC),
                                side: BorderSide(
                                    color: Colors.black.withOpacity(0.06)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                              ),
                              onPressed: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: now.add(const Duration(days: 1)),
                                  firstDate: now,
                                  lastDate: now.add(const Duration(days: 90)),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Color(0xFF0284C7),
                                          onPrimary: Colors.white,
                                          onSurface: Color(0xFF0F172A),
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setState(() {
                                    _fecha =
                                        DateFormat('yyyy-MM-dd').format(picked);
                                  });
                                }
                              },
                              icon: const Icon(Icons.event_rounded, size: 16),
                              label: const Text(
                                'Fecha',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0886B5),
                              backgroundColor: const Color(0xFFF8FAFC),
                              side: BorderSide(
                                  color: Colors.black.withOpacity(0.06)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _addProduct,
                            icon: const Icon(Icons.add_shopping_cart_rounded,
                                size: 17),
                            label: const Text(
                              'Agregar Producto del Catálogo',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _lines.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF8FAFC),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.add_shopping_cart_rounded,
                                          size: 36,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'No hay productos agregados',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Toca "Agregar Producto" para armar el pedido.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _lines.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, idx) {
                                    final l = _lines[idx];
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color:
                                                Colors.black.withOpacity(0.04)),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  l.nombre,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 13.5,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '\$${l.precio.toStringAsFixed(2)} c/u · Subtotal: \$${(l.precio * l.cantidad).toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF64748B),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton.filledTonal(
                                                style: IconButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  foregroundColor:
                                                      const Color(0xFF0886B5),
                                                ),
                                                onPressed: () => setState(() {
                                                  if (l.cantidad > 1) {
                                                    l.cantidad--;
                                                  } else {
                                                    _lines.removeAt(idx);
                                                  }
                                                }),
                                                icon: const Icon(
                                                  Icons.remove_rounded,
                                                  size: 16,
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8),
                                                child: Text(
                                                  '${l.cantidad}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 15,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                              IconButton.filledTonal(
                                                style: IconButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  foregroundColor:
                                                      const Color(0xFF0886B5),
                                                ),
                                                onPressed: () => setState(
                                                    () => l.cantidad++),
                                                icon: const Icon(
                                                    Icons.add_rounded,
                                                    size: 16),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total estimado',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '\$${total.toStringAsFixed(2)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            LoadingActionButton(
                              text: 'Guardar Pedido',
                              isLoading: _isSaving,
                              onPressed: _submitOrder,
                              icon: Icons.send_rounded,
                              width: 175,
                              height: 48,
                              borderRadius: 14,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
