import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';
import 'package:mark_v3/pages/Routes_/route_distance_page.dart';
import 'package:mark_v3/pages/Routes_/cedi_warehouse_page.dart';
import 'package:mark_v3/providers/Routes_/routes_provider.dart';
import 'package:mark_v3/pages/Routes_/driver_sync_widgets.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

enum GuiaOperationType { recojo, entrega, incidencia }

/// Pantalla de ejecución de Recojo, Entrega o Incidencia sobre una Guía
class DeliverPage extends ConsumerStatefulWidget {
  final int idRuta;
  final int idParada;
  final GuiaItem guia;
  final bool isPickupGuia;
  final GuiaOperationType initialOperation;

  const DeliverPage({
    super.key,
    required this.idRuta,
    required this.idParada,
    required this.guia,
    this.isPickupGuia = false,
    this.initialOperation = GuiaOperationType.entrega,
  });

  @override
  ConsumerState<DeliverPage> createState() => _DeliverPageState();
}

class _DeliverPageState extends ConsumerState<DeliverPage> {
  late GuiaOperationType _activeOp;
  final ImagePicker _picker = ImagePicker();

  // Campos de Recojo
  late int _bultosCount;
  final List<String> _scannedCodes = [];

  // Campos de Entrega
  final TextEditingController _code4Ctrl = TextEditingController();
  final TextEditingController _recipientNameCtrl = TextEditingController();
  bool _useNoCodeFallback = false;

  // Campos de Incidencia
  int? _selectedIncidentMotivo;

  // Campos comunes (Fotos, Firma, Nota)
  final List<File> _photoFiles = [];
  final List<String> _photoUuids = [];
  Uint8List? _signaturePng;
  String? _signatureUuid;
  final TextEditingController _noteCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _isTakingPhoto = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _activeOp = widget.initialOperation;
    _bultosCount = widget.guia.bultos > 0 ? widget.guia.bultos : 1;
    if (widget.guia.destinatario != null &&
        widget.guia.destinatario!.nombre.isNotEmpty) {
      _recipientNameCtrl.text = widget.guia.destinatario!.nombre;
    }
  }

  @override
  void dispose() {
    _code4Ctrl.dispose();
    _recipientNameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (_isTakingPhoto) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked == null) return;
      if (mounted) setState(() => _isTakingPhoto = true);
      final file = File(picked.path);
      final uuid =
          await ref.read(routesProvider.notifier).registerLocalPhoto(file);
      if (mounted) {
        setState(() {
          _photoFiles.add(file);
          _photoUuids.add(uuid);
        });
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
      }
    }
  }

  Future<void> _captureSignature() async {
    final pngBytes = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SignaturePadSheet(
        recipientName: _recipientNameCtrl.text.trim(),
      ),
    );
    if (pngBytes != null) {
      final sigUuid = await ref
          .read(routesProvider.notifier)
          .registerLocalSignature(pngBytes);
      setState(() {
        _signaturePng = pngBytes;
        _signatureUuid = sigUuid;
      });
    }
  }

  Future<void> _openLabelScanner(DayConfig config) async {
    // 1. Si la guía ya tiene etiquetas asignadas, solo esas etiquetas son válidas
    Set<String>? validSet;
    if (widget.guia.etiquetas.isNotEmpty) {
      validSet = <String>{};
      for (final e in widget.guia.etiquetas) {
        final norm = LabelCode.normalizeScannedCode(e.codigo);
        if (norm.isNotEmpty) validSet.add(norm);
        validSet.add(e.codigo.trim().toUpperCase());
      }
    }

    // 2. Prohibir códigos y folios de cualquier OTRA guía asignada al chofer
    final Map<String, String> forbiddenCodes = {};
    final dayPkg = ref.read(routesProvider).dayPackage;
    if (dayPkg != null) {
      for (final r in dayPkg.rutas) {
        for (final p in r.paradas) {
          final stopGuias = [...p.recoger, ...p.entregar];
          for (final g in stopGuias) {
            if (g.idGuia != widget.guia.idGuia) {
              final desc = g.folio;
              // Folio de la otra guía
              final normFolio = LabelCode.normalizeScannedCode(g.folio);
              if (normFolio.isNotEmpty) forbiddenCodes[normFolio] = desc;
              forbiddenCodes[g.folio.trim().toUpperCase()] = desc;

              // Etiquetas de la otra guía
              for (final etq in g.etiquetas) {
                final normEtq = LabelCode.normalizeScannedCode(etq.codigo);
                if (normEtq.isNotEmpty) forbiddenCodes[normEtq] = desc;
                forbiddenCodes[etq.codigo.trim().toUpperCase()] = desc;
              }
            }
          }
        }
      }
    }

    final scanned = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LabelScannerSheet(
        title: 'Escanear Bultos',
        subtitle: config.modoEtiqueta == 2 && _activeOp == GuiaOperationType.recojo
            ? 'Pegue una etiqueta de su rollo en cada bulto y escanéela'
            : 'Escanee el QR o código de barras de cada bulto',
        burstMode: true,
        initialCodes: _scannedCodes,
        validNormalizedCodes: validSet,
        forbiddenNormalizedCodes: forbiddenCodes,
        invalidCodeAlertTitle: '¡ETIQUETA NO VÁLIDA PARA ESTA GUÍA!',
        invalidCodeAlertMessage: widget.guia.etiquetas.isNotEmpty
            ? 'La guía ${widget.guia.folio} ya tiene sus etiquetas asignadas en el sistema. Debe escanear las etiquetas oficiales de la guía, no use stickers de rollo.'
            : (_activeOp == GuiaOperationType.recojo
                ? 'Este bulto no corresponde a esta recolección.'
                : 'Este bulto no corresponde a esta entrega.'),
      ),
    );
    if (scanned != null) {
      setState(() {
        _scannedCodes
          ..clear()
          ..addAll(scanned);
        if (_scannedCodes.isNotEmpty) {
          _bultosCount = _scannedCodes.length;
        }
      });
    }
  }

  // ===========================================================================
  // ENVÍO DE RECOJO, ENTREGA E INCIDENCIA CON VALIDACIÓN DE REGLAS DEL SERVIDOR
  // ===========================================================================

  Future<void> _submitPickup(
    DayConfig config, {
    bool confirmarDiferencia = false,
  }) async {
    final requiresScan = config.modoEtiqueta == 1 || config.modoEtiqueta == 2;
    if (requiresScan && _scannedCodes.isEmpty) {
      showServerNoticesFeedback(context, const [
        ServerNotice(
          nivel: 'error',
          codigo: 'ESCANEO',
          texto: 'La configuración de la cuenta exige escanear las etiquetas de los bultos.',
        ),
      ]);
      await _openLabelScanner(config);
      return;
    }

    final effectiveBultos =
        _scannedCodes.isNotEmpty ? _scannedCodes.length : _bultosCount;

    // Si hay menos bultos de los que dice la guía y aún no ha confirmado diferencia, preguntar localmente
    if (!confirmarDiferencia && effectiveBultos < widget.guia.bultos) {
      final confirmed = await _showConfirmBultosDialog(
        captured: effectiveBultos,
        expected: widget.guia.bultos,
      );
      if (!confirmed) return;
      confirmarDiferencia = true;
    }

    setState(() => _isSubmitting = true);
    try {
      final res = await ref.read(routesProvider.notifier).registrarRecojo(
            idRuta: widget.idRuta,
            idParada: widget.idParada,
            idGuia: widget.guia.idGuia,
            bultos: config.modoEtiqueta == 0 ||
                    (config.modoEtiqueta == 3 && _scannedCodes.isEmpty)
                ? effectiveBultos
                : null,
            codigos: _scannedCodes,
            fotosUuids: _photoUuids,
            nota: _noteCtrl.text,
            confirmarDiferencia: confirmarDiferencia,
          );

      if (!mounted) return;

      if (res.needsConfirmDifference && !confirmarDiferencia) {
        final bNotice = res.avisos.firstWhere(
          (a) => a.codigo == 'BULTOS' || a.codigo == 'PENDIENTES',
          orElse: () => const ServerNotice(nivel: '', codigo: '', texto: ''),
        );
        final confirmed = await _showConfirmBultosDialog(
          captured: effectiveBultos,
          expected: widget.guia.bultos,
          serverMessage: bNotice.texto.isNotEmpty ? bNotice.texto : null,
        );
        if (confirmed && mounted) {
          await _submitPickup(config, confirmarDiferencia: true);
        }
        return;
      }

      showServerNoticesFeedback(
        context,
        res.avisos,
        fallbackSuccessMessage: 'Recojo de ${widget.guia.folio} registrado.',
      );

      if (res.queuedOrApplied) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool> _showConfirmBultosDialog({
    required int captured,
    required int expected,
    String? serverMessage,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Bultos incompletos o con diferencia',
          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
        ),
        content: Text(
          serverMessage != null
              ? '$serverMessage\n\n¿Desea confirmar la diferencia para continuar?'
              : (captured >= expected
                  ? 'El servidor reporta una discrepancia en las etiquetas de la guía ${widget.guia.folio}.\n\n¿Desea confirmar la diferencia?'
                  : 'Se registraron $captured de $expected bultos en la guía ${widget.guia.folio}.\n\n¿Desea escanear/contar el bulto faltante o confirmar la diferencia?'),
          style: const TextStyle(fontSize: 13, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Corregir / Escanear'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar diferencia'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _submitDelivery(DayConfig config, bool isOnline) async {
    // Verificar si la guía ya pasó por CEDI a «En reparto»
    final route = ref.read(routesProvider).findRoute(widget.idRuta);
    GuiaItem currentGuia = widget.guia;
    if (route != null) {
      for (final p in route.paradas) {
        for (final g in [...p.recoger, ...p.entregar]) {
          if (g.idGuia == widget.guia.idGuia) {
            currentGuia = g;
            break;
          }
        }
      }
    }

    if (currentGuia.estado == 1 || currentGuia.estado == 2) {
      final goToCedi = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warehouse_rounded, color: Color(0xFFDC2626), size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Guía no está en reparto',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(
            currentGuia.estado == 1
                ? 'La guía ${currentGuia.folio} está «Recogida».\n\nEl sistema exige procesarla en CEDI (Descarga y Carga) para que pase a «En reparto» antes de poder entregarla.'
                : 'La guía ${currentGuia.folio} está «En CEDI».\n\nPrimero debes cargarla al vehículo en el módulo CEDI para que pase a «En reparto».',
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0886B5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              label: const Text('Ir al CEDI'),
            ),
          ],
        ),
      );

      if (goToCedi == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CediOperationsPage(
              idRuta: widget.idRuta,
              initialTab: currentGuia.estado == 1 ? 0 : 1,
            ),
          ),
        );
      }
      return;
    }

    final pruebaModo = config.pruebaEntrega; // 1 = solo código, 2 = código o foto+nombre, 3 = foto+nombre
    final requiresSignature = config.firmaEntrega == 1;

    final code = _code4Ctrl.text.trim();
    final recipient = _recipientNameCtrl.text.trim();

    // Regla línea 195:
    // "Sin señal: guarda la entrega con el código que dictó el cliente y pide también foto + nombre.
    // Si el código no coincide pero vienen foto y nombre, el servidor la acepta como entrega sin código."
    final needsPhotoAndName = pruebaModo == 3 ||
        (pruebaModo == 2 && _useNoCodeFallback) ||
        !isOnline;

    final needsCode = pruebaModo == 1 ||
        (pruebaModo == 2 && !_useNoCodeFallback);

    if (needsCode && code.length < 4) {
      showServerNoticesFeedback(context, const [
        ServerNotice(
          nivel: 'error',
          codigo: 'PIDE_CODIGO',
          texto: 'Ingrese el código de entrega de 4 dígitos que tiene quien recibe.',
        ),
      ]);
      return;
    }

    if (needsPhotoAndName) {
      if (_photoUuids.isEmpty || recipient.isEmpty) {
        showServerNoticesFeedback(context, [
          ServerNotice(
            nivel: 'error',
            codigo: 'PRUEBA',
            texto: !isOnline
                ? 'Sin señal se requiere también foto del paquete entregado y nombre de quien recibe como respaldo.'
                : 'Se requiere foto del paquete entregado y el nombre de quien recibe.',
          ),
        ]);
        return;
      }
      if (requiresSignature && _signatureUuid == null) {
        showServerNoticesFeedback(context, const [
          ServerNotice(
            nivel: 'error',
            codigo: 'FIRMA',
            texto: 'La cuenta solicita la firma en pantalla de quien recibe.',
          ),
        ]);
        await _captureSignature();
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final res = await ref.read(routesProvider.notifier).registrarEntrega(
            idRuta: widget.idRuta,
            idParada: widget.idParada,
            idGuia: widget.guia.idGuia,
            codigo: code.isNotEmpty ? code : null,
            fotosUuids: _photoUuids,
            nombreRecibe: recipient.isNotEmpty ? recipient : null,
            firmaUuid: _signatureUuid,
            codigosEtiquetas: _scannedCodes,
            nota: _noteCtrl.text,
          );

      if (!mounted) return;
      showServerNoticesFeedback(
        context,
        res.avisos,
        fallbackSuccessMessage: 'Entrega de ${widget.guia.folio} registrada.',
      );

      // Si el servidor rechazó por CODIGO y la cuenta está en modo 2, ofrecer abrir foto + nombre
      if (!res.queuedOrApplied &&
          res.avisos.any((n) => n.codigo == 'CODIGO') &&
          pruebaModo == 2) {
        setState(() => _useNoCodeFallback = true);
        return;
      }

      if (res.queuedOrApplied) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitIncident(DayConfig config) async {
    if (_selectedIncidentMotivo == null) {
      showServerNoticesFeedback(context, const [
        ServerNotice(
          nivel: 'error',
          codigo: 'MOTIVO',
          texto: 'Seleccione un motivo de incidencia de la lista.',
        ),
      ]);
      return;
    }

    if (config.fotoIncidencia == 1 && _photoUuids.isEmpty) {
      showServerNoticesFeedback(context, const [
        ServerNotice(
          nivel: 'error',
          codigo: 'FOTO',
          texto: 'La cuenta exige tomar una foto de evidencia para registrar la incidencia.',
        ),
      ]);
      await _takePhoto();
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final res = await ref.read(routesProvider.notifier).registrarIncidencia(
            idRuta: widget.idRuta,
            idParada: widget.idParada,
            idGuia: widget.guia.idGuia,
            motivo: _selectedIncidentMotivo!,
            nota: _noteCtrl.text,
            fotosUuids: _photoUuids,
          );

      if (!mounted) return;
      showServerNoticesFeedback(
        context,
        res.avisos,
        fallbackSuccessMessage:
            'Incidencia registrada en la guía ${widget.guia.folio}.',
      );
      if (res.queuedOrApplied) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  List<IncidentReason> _getFilteredIncidentReasons(DayConfig config) {
    final filtered = config.motivosIncidencia.where((m) {
      return widget.isPickupGuia ? m.isForPickup : m.isForDelivery;
    }).toList();

    if (filtered.isNotEmpty) return filtered;

    // Motivos por defecto según especificación (11–19 recojo, 21–29 entrega)
    if (widget.isPickupGuia) {
      return const [
        IncidentReason(codigo: 11, texto: 'Local cerrado / No había nadie', para: 'recojo'),
        IncidentReason(codigo: 12, texto: 'Paquete aún no estaba listo', para: 'recojo'),
        IncidentReason(codigo: 13, texto: 'Dirección incorrecta o incompleta', para: 'recojo'),
        IncidentReason(codigo: 14, texto: 'Cliente canceló el envío', para: 'recojo'),
      ];
    } else {
      return const [
        IncidentReason(codigo: 21, texto: 'No había nadie', para: 'entrega'),
        IncidentReason(codigo: 22, texto: 'Rechazado por el destinatario', para: 'entrega'),
        IncidentReason(codigo: 23, texto: 'Dirección no localizada / inaccesible', para: 'entrega'),
        IncidentReason(codigo: 24, texto: 'Negocio cerrado', para: 'entrega'),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routesProvider);
    final config = state.dayPackage?.config ?? const DayConfig();
    final isOnline = state.isOnline;

    final route = state.findRoute(widget.idRuta);
    GuiaItem currentGuia = widget.guia;
    if (route != null) {
      for (final p in route.paradas) {
        for (final g in [...p.recoger, ...p.entregar]) {
          if (g.idGuia == widget.guia.idGuia) {
            currentGuia = g;
            break;
          }
        }
      }
    }

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
                        size: 16,
                        color: Color(0xFF0F172A),
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
              Text(
                widget.isPickupGuia ? 'Recoger' : 'Entregar',
                style: const TextStyle(
                  fontSize: 18.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Guía ${widget.guia.folio} · ${widget.guia.bultos} bulto(s) · ${widget.guia.pesoKg} kg',
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
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          children: [
            // Selector de modo: Recojo / Entrega vs Incidencia (estilo cápsula compacto)
            Container(
              height: 36,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModeTabButton(
                      selected: _activeOp != GuiaOperationType.incidencia,
                      icon: widget.isPickupGuia
                          ? Icons.inventory_2_rounded
                          : Icons.local_shipping_rounded,
                      label: widget.isPickupGuia
                          ? 'Recoger Paquete'
                          : 'Entregar Paquete',
                      activeColor: const Color(0xFF0F172A),
                      onTap: () => setState(() {
                        _activeOp = widget.isPickupGuia
                            ? GuiaOperationType.recojo
                            : GuiaOperationType.entrega;
                      }),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildModeTabButton(
                      selected: _activeOp == GuiaOperationType.incidencia,
                      icon: Icons.warning_amber_rounded,
                      label: 'Reportar Incidencia',
                      activeColor: const Color(0xFF0F172A),
                      onTap: () => setState(() {
                        _activeOp = GuiaOperationType.incidencia;
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Aviso preventivo si la guía no se encuentra en estado «En reparto»
            if (_activeOp == GuiaOperationType.entrega &&
                (currentGuia.estado == 1 || currentGuia.estado == 2)) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA), width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC2626).withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.warehouse_rounded,
                          color: Color(0xFFDC2626),
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
                            currentGuia.estado == 1
                                ? 'Guía en estado «Recogida» — Pendiente de CEDI'
                                : 'Guía «En CEDI» — Pendiente de Cargar al Vehículo',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF991B1B),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            currentGuia.estado == 1
                                ? 'Esta guía fue recolectada pero el servidor exige procesarla en CEDI (Bajar y Subir al vehículo) para ponerla «En reparto» antes de poder entregarla.'
                                : 'Esta guía está en CEDI pero aún debe cargarse al vehículo para ponerse «En reparto».',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF7F1D1D),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CediOperationsPage(
                                      idRuta: widget.idRuta,
                                      initialTab: currentGuia.estado == 1 ? 0 : 1,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                              label: Text(
                                currentGuia.estado == 1
                                    ? 'Ir a CEDI (Bajar bultos)'
                                    : 'Ir a CEDI (Subir a reparto)',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Ficha de destinatario u observaciones de la guía
            if (widget.guia.destinatario != null ||
                widget.guia.obs.isNotEmpty) ...[
              Container(
                width: double.infinity,
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          Icons.person_pin_circle_rounded,
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
                          if (widget.guia.destinatario != null) ...[
                            Text(
                              'Recibe: ${widget.guia.destinatario!.nombre}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (widget.guia.destinatario!.telefono.isNotEmpty)
                              Text(
                                widget.guia.destinatario!.telefono,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                          if (widget.guia.obs.isNotEmpty) ...[
                            if (widget.guia.destinatario != null)
                              const SizedBox(height: 3),
                            Text(
                              'Indicaciones: ${widget.guia.obs}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // CONTENIDO SEGÚN OPERACIÓN ACTIVA
            if (_activeOp == GuiaOperationType.recojo)
              _buildPickupSection(config, isSmallScreen)
            else if (_activeOp == GuiaOperationType.entrega)
              _buildDeliverySection(config, isOnline, isSmallScreen)
            else
              _buildIncidentSection(config, isSmallScreen),

            const SizedBox(height: 14),

            // SECCIÓN COMÚN: FOTOS Y NOTAS
            _buildPhotosAndNotesSection(config, isOnline, isSmallScreen),

            const SizedBox(height: 14),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(
                isSmallScreen ? 12 : 16,
                10,
                isSmallScreen ? 12 : 16,
                14,
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
                bottom: false,
                child: _SwipeToConfirmButton(
                  key: ValueKey(_activeOp),
                  isLoading: _isSubmitting,
                  label: _activeOp == GuiaOperationType.incidencia
                      ? 'Desliza para reportar incidencia'
                      : (_activeOp == GuiaOperationType.recojo
                          ? 'Desliza para confirmar recojo'
                          : 'Desliza para confirmar entrega'),
                  themeColor: _activeOp == GuiaOperationType.incidencia
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF0886B5),
                  icon: _activeOp == GuiaOperationType.incidencia
                      ? Icons.warning_rounded
                      : (_activeOp == GuiaOperationType.recojo
                          ? Icons.inventory_2_rounded
                          : Icons.local_shipping_rounded),
                  onConfirmed: () async {
                    if (_activeOp == GuiaOperationType.recojo) {
                      await _submitPickup(config);
                    } else if (_activeOp == GuiaOperationType.entrega) {
                      await _submitDelivery(config, isOnline);
                    } else {
                      await _submitIncident(config);
                    }
                  },
                ),
              ),
            ),
            const DriverSyncStatusBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTabButton({
    required bool selected,
    required IconData icon,
    required String label,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SECCIÓN RECOJO ---
  Widget _buildPickupSection(DayConfig config, bool isSmallScreen) {
    final modo = config.modoEtiqueta; // 0 sin escaneo, 1 guía impresa, 2 rollo chofer, 3 cualquiera
    String modoDesc = 'Puede escanear las etiquetas o confirmar el número de bultos.';
    if (modo == 0) {
      modoDesc = 'Modo conteo: indique el número de bultos recogidos.';
    } else if (modo == 1) {
      modoDesc = 'Modo Guía Impresa (obligatorio): escanee el QR de cada bulto.';
    } else if (modo == 2) {
      modoDesc =
          'Modo Rollo del Chofer (obligatorio): pegue una etiqueta de su rollo en cada bulto y escanéela.';
    }

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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Etiquetas y Bultos a Recoger',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            modoDesc,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          if (modo != 0) ...[
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0886B5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _openLabelScanner(config),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                label: Text(
                  _scannedCodes.isEmpty
                      ? 'Escanear Bultos (Esperados: ${widget.guia.bultos})'
                      : 'Escaneados: ${_scannedCodes.length} de ${widget.guia.bultos} bultos',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (_scannedCodes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _scannedCodes
                    .map(
                      (c) => Chip(
                        backgroundColor: const Color(0xFFF1F5F9),
                        deleteIconColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        label: Text(
                          LabelCode.normalizeScannedCode(c),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                        onDeleted: () => setState(() {
                          _scannedCodes.remove(c);
                          if (_scannedCodes.isNotEmpty) {
                            _bultosCount = _scannedCodes.length;
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
          ],

          if (modo == 0 || (modo == 3 && _scannedCodes.isEmpty)) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bultos contados',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Esperados: ${widget.guia.bultos}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _bultosCount > 1
                            ? () => setState(() => _bultosCount--)
                            : null,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _bultosCount > 1
                                ? const Color(0xFFF1F5F9)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _bultosCount > 1
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Icon(
                            Icons.remove_rounded,
                            size: 15,
                            color: _bultosCount > 1
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 34),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '$_bultosCount',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _bultosCount++),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0886B5),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF0886B5).withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- SECCIÓN ENTREGA ---
  Widget _buildDeliverySection(
      DayConfig config, bool isOnline, bool isSmallScreen) {
    final prueba = config.pruebaEntrega; // 1 solo código, 2 código o foto+nombre, 3 foto+nombre
    final showCodeInput = prueba == 1 || (prueba == 2 && !_useNoCodeFallback);
    final showPhotoAndNameInputs =
        prueba == 3 || (prueba == 2 && _useNoCodeFallback) || !isOnline;

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
              Row(
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
                        Icons.verified_rounded,
                        color: Color(0xFF0284C7),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Prueba de Entrega',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              if (!isOnline)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text(
                    'Sin señal: código + foto',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'Valide la entrega mediante código de 4 dígitos o evidencia fotográfica:',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          // Botón opcional para validar que el bulto escaneado sí sea de esta guía (ETQ_OTRA)
          if (config.modoEtiqueta != 0) ...[
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0886B5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _openLabelScanner(config),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                label: Text(
                  _scannedCodes.isEmpty
                      ? 'Verificar Etiqueta del Bulto'
                      : 'Etiquetas verificadas (${_scannedCodes.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (_scannedCodes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bultos / etiquetas escaneadas (${_scannedCodes.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() {
                      _scannedCodes.clear();
                    }),
                    child: const Text(
                      'Limpiar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _scannedCodes
                    .map(
                      (c) => Chip(
                        backgroundColor: const Color(0xFFF0FDF4),
                        side: const BorderSide(color: Color(0xFFBAE6FD)),
                        deleteIconColor: const Color(0xFF0284C7),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        label: Text(
                          LabelCode.normalizeScannedCode(c),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                        onDeleted: () => setState(() {
                          _scannedCodes.remove(c);
                        }),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
          ],

          if (showCodeInput) ...[
            const Text(
              'Código de entrega de 4 dígitos (lo dicta quien recibe):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _code4Ctrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 14,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••',
                hintStyle: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  letterSpacing: 14,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0886B5)),
                ),
              ),
            ),
            if (prueba == 2) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _useNoCodeFallback = true),
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: const Text(
                    'No tiene el código → Foto y nombre',
                    style: TextStyle(
                      color: Color(0xFF0886B5),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],

          if (showPhotoAndNameInputs) ...[
            if (prueba == 2 && _useNoCodeFallback)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _useNoCodeFallback = false),
                  child: const Text(
                    '← Volver a usar código de 4 dígitos',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0886B5),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            TextField(
              controller: _recipientNameCtrl,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                labelText: 'Nombre completo de quien recibe *',
                labelStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.person_outline, size: 18),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF0886B5)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nota: Tome foto del paquete entregado (no se toma foto de identificaciones).',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            if (config.firmaEntrega == 1) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0886B5),
                    side: const BorderSide(color: Color(0xFF0886B5), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _captureSignature,
                  icon: Icon(
                    _signatureUuid != null
                        ? Icons.verified_rounded
                        : Icons.draw_rounded,
                    size: 16,
                    color: _signatureUuid != null
                        ? const Color(0xFF059669)
                        : const Color(0xFF0886B5),
                  ),
                  label: Text(
                    _signatureUuid != null
                        ? 'Firma capturada (toque para repetir)'
                        : 'Capturar Firma en Pantalla *',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (_signaturePng != null) ...[
                const SizedBox(height: 8),
                Container(
                  height: 80,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.memory(_signaturePng!, fit: BoxFit.contain),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  // --- SECCIÓN INCIDENCIA ---
  Widget _buildIncidentSection(DayConfig config, bool isSmallScreen) {
    final reasons = _getFilteredIncidentReasons(config);
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
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
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
              Expanded(
                child: Text(
                  widget.isPickupGuia
                      ? 'Motivo de Incidencia en Recojo'
                      : 'Motivo de Incidencia en Entrega',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF991B1B),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'Seleccione el motivo por el cual no se completó la operación:',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          ...reasons.map((r) {
            final selected = _selectedIncidentMotivo == r.codigo;
            return Container(
              margin: const EdgeInsets.only(bottom: 7),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _selectedIncidentMotivo = r.codigo),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFE2E8F0),
                        width: selected ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF94A3B8),
                              width: 1.8,
                            ),
                            color: selected
                                ? const Color(0xFFDC2626)
                                : Colors.transparent,
                          ),
                          child: selected
                              ? const Center(
                                  child: Icon(Icons.check,
                                      size: 11, color: Colors.white),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.texto,
                                style: TextStyle(
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  fontSize: 12.5,
                                  color: selected
                                      ? const Color(0xFF991B1B)
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Código ${r.codigo}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: selected
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF64748B),
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
            );
          }),
          if (config.fotoIncidencia == 1) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.camera_alt_rounded,
                      color: Color(0xFFDC2626), size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Esta cuenta solicita foto obligatoria para reportar incidencia.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF991B1B),
                      ),
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

  // --- SECCIÓN FOTOS Y NOTA ---
  Widget _buildPhotosAndNotesSection(
      DayConfig config, bool isOnline, bool isSmallScreen) {
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
              Row(
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
                        Icons.camera_alt_rounded,
                        color: Color(0xFF0284C7),
                        size: 19,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Notas y Evidencias (${_photoFiles.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  backgroundColor: Colors.white,
                  side: const BorderSide(
                    color: Color(0xFF0284C7),
                    width: 1.0,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isTakingPhoto ? null : _takePhoto,
                icon: _isTakingPhoto
                    ? SizedBox(
                        width: 13,
                        height: 13,
                        child: LoadingAnimationWidget.threeRotatingDots(
                          color: const Color(0xFF0886B5),
                          size: 13,
                        ),
                      )
                    : const Icon(Icons.camera_alt_rounded, size: 13),
                label: Text(
                  _isTakingPhoto ? 'Guardando...' : 'Tomar foto',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Comentarios u observaciones de la entrega/recojo...',
              hintStyle:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF0886B5)),
              ),
            ),
          ),
          if (_photoFiles.isNotEmpty || _isTakingPhoto) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 60,
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
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _photoFiles.removeAt(i);
                                  _photoUuids.removeAt(i);
                                });
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
                                  size: 12,
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
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF8FC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF0886B5).withOpacity(0.35),
                          width: 1.2,
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
                            'Guardando',
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
}

class _SwipeToConfirmButton extends StatefulWidget {
  final Future<void> Function() onConfirmed;
  final String label;
  final Color themeColor;
  final IconData icon;
  final bool isLoading;

  const _SwipeToConfirmButton({
    super.key,
    required this.onConfirmed,
    required this.label,
    required this.themeColor,
    this.icon = Icons.arrow_forward_rounded,
    this.isLoading = false,
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
    const double height = 52.0;
    const double handlePadding = 4.0;
    const double handleSize = height - (handlePadding * 2);
    final effectiveLoading = widget.isLoading || _localLoading;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag =
            constraints.maxWidth - handleSize - (handlePadding * 2);

        return Container(
          height: height,
          width: constraints.maxWidth,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Barra de relleno con el color temático que sigue el arrastre
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: (_dragPosition + handleSize + handlePadding * 2)
                    .clamp(0.0, constraints.maxWidth),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.themeColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),

              // Contenido central (Icono de la operación + Texto + Flechas)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: 48, right: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.icon,
                        color: widget.themeColor,
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: widget.themeColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_double_arrow_right_rounded,
                        color: widget.themeColor.withOpacity(0.7),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),

              // Agarradera / Handle circular deslizable
              Positioned(
                left: handlePadding + _dragPosition,
                top: handlePadding,
                child: GestureDetector(
                  onHorizontalDragUpdate: effectiveLoading || _isFinished
                      ? null
                      : (details) {
                          if (_animController.isAnimating) return;
                          setState(() {
                            _dragPosition = (_dragPosition + details.delta.dx)
                                .clamp(0.0, maxDrag);
                          });
                        },
                  onHorizontalDragEnd: effectiveLoading || _isFinished
                      ? null
                      : (details) async {
                          if (_animController.isAnimating) return;
                          // Umbral de activación al 75%
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
                      color: widget.themeColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.themeColor.withOpacity(0.38),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: effectiveLoading
                          ? LoadingAnimationWidget.threeRotatingDots(
                              color: Colors.white,
                              size: 18,
                            )
                          : const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
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
