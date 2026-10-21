import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:mark_v3/models/Vehicles_/insurance_model.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/Error_/unexpectedErrorPage.dart';
import 'package:mark_v3/providers/Vehicles_/insurance_provider.dart';
import 'package:mark_v3/services/ConnectionNotification_/NotificationCon_service.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/apple_detail_row.dart';
import 'package:mark_v3/widgets/apple_group_card.dart';
import 'package:mark_v3/widgets/apple_section_title.dart';
import 'package:mark_v3/widgets/document_photo_box.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/doc_foto_widget.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

// Autor: Josue Hernandez
class InsurancePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> vehicle;
  final String insurancePermission;
  final String idMainAccount;
  final String userId;

  const InsurancePage({
    super.key,
    required this.insurancePermission,
    required this.vehicle,
    required this.idMainAccount,
    required this.userId,
  });

  @override
  ConsumerState<InsurancePage> createState() => _InsurancePageState();
}

class _InsurancePageState extends ConsumerState<InsurancePage> {
  List<Map<String, dynamic>> _companias = [];
  List<Map<String, dynamic>> _coberturas = [];
  String _typeSource = '';
  bool _isDisposed = false;
  bool _isEditing = false;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final _polizaNumController = TextEditingController();
  final _deducibleController = TextEditingController();
  final _montoController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _fechaInicioController = TextEditingController();
  final _fechaVencimientoController = TextEditingController();

  String? _selectedCompaniaId;
  String? _selectedCoberturaId;
  DateTime? _selectedFechaInicio;
  DateTime? _selectedFechaVencimiento;

  // Fotografías de la póliza y estado de OCR
  File? _frontImage;
  File? _backImage;
  bool _isScanningOcr = false;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _fetchCatalogs();
    _fetchTypeSource();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInsurance();
    });
  }

  Future<void> _fetchCatalogs() async {
    try {
      final dbService = VehiclesconService();
      final results = await Future.wait([
        dbService.obtenerCompanias(),
        dbService.obtenerTipoCobertura(),
      ]);
      if (!_isDisposed && mounted) {
        setState(() {
          _companias = results[0];
          _coberturas = results[1];

          final insurances = ref.read(insuranceProvider).insurances;
          if (insurances.isNotEmpty && _isEditing) {
            final seguro = insurances.first;
            if (_selectedCompaniaId == null ||
                !_companias.any((c) => c['id']?.toString() == _selectedCompaniaId)) {
              _selectedCompaniaId = _resolveIdFromList(_companias, seguro.idCompania);
            }
            if (_selectedCoberturaId == null ||
                !_coberturas.any((c) => c['id']?.toString() == _selectedCoberturaId)) {
              _selectedCoberturaId = _resolveIdFromList(_coberturas, seguro.idTipoCobertura);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error al cargar catálogos de seguros: $e');
    }
  }

  void _loadInsurance() {
    ref.read(insuranceProvider.notifier).fetchInsurances(
          widget.vehicle['id'].toString(),
          widget.idMainAccount.toString(),
        );
  }

  Future<void> _fetchTypeSource() async {
    if (_isDisposed || !mounted) return;
    try {
      final Map<String, dynamic> data =
          await NotificationService().gettypSource('vehic_insurance');
      if (!_isDisposed && mounted && data.containsKey('id')) {
        setState(() {
          _typeSource = data['id'].toString();
        });
      }
    } catch (e) {
      debugPrint('Error al obtener typeSource de seguro: $e');
    }
  }

  Future<void> _refreshData() async {
    if (_isDisposed || !mounted) return;
    _loadInsurance();
    _fetchCatalogs();
  }

  // --- PERMISOS BITWISE Y FLOTA ---
  bool get _canEdit =>
      MarkApiClient.instance.flota.can('seguro', 'editar') ||
      ((int.tryParse(widget.insurancePermission) ?? 0) & 8 == 8);

  bool get _canDelete => false;

  bool get _canCreate =>
      MarkApiClient.instance.flota.can('seguro', 'crear') ||
      ((int.tryParse(widget.insurancePermission) ?? 0) & 4 == 4);

  // --- FORMATEO Y PARSEO DE FECHAS SEGURO ---
  String _formatDisplayDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is DateTime) {
      return DateFormat('dd / MM / yyyy').format(date);
    }
    final str = date.toString().trim();
    if (str.isEmpty) return 'N/A';

    try {
      final parsed = DateFormat('yyyy-MM-dd').parse(str);
      return DateFormat('dd / MM / yyyy').format(parsed);
    } catch (_) {}

    try {
      final parsed = DateFormat('dd/MM/yyyy').parse(str);
      return DateFormat('dd / MM / yyyy').format(parsed);
    } catch (_) {}

    try {
      final parsed = DateTime.parse(str);
      return DateFormat('dd / MM / yyyy').format(parsed);
    } catch (_) {}

    return str;
  }

  DateTime? _parseDateSafe(dynamic date) {
    if (date == null) return null;
    if (date is DateTime) return date;
    final str = date.toString().trim();
    if (str.isEmpty) return null;

    try {
      return DateFormat('yyyy-MM-dd').parse(str);
    } catch (_) {}

    try {
      return DateFormat('dd/MM/yyyy').parse(str);
    } catch (_) {}

    try {
      return DateTime.parse(str);
    } catch (_) {}

    return null;
  }

  int _calculateDaysDifference(DateTime targetDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return target.difference(today).inDays;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _polizaNumController.dispose();
    _deducibleController.dispose();
    _montoController.dispose();
    _observacionesController.dispose();
    _fechaInicioController.dispose();
    _fechaVencimientoController.dispose();
    super.dispose();
  }

  // =========================================================================
  // CAPTURA Y ESCANEO OCR DE FOTOGRAFÍAS
  // =========================================================================
  Future<void> _pickAndScanFrontImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1920,
      );

      if (pickedFile == null) return;

      setState(() {
        _frontImage = File(pickedFile.path);
        _isScanningOcr = true;
      });

      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (!mounted) return;

      _applyOcrResults(recognizedText);

      setState(() {
        _isScanningOcr = false;
      });

      SnackbarTop.showSuccess(
        context,
        'Póliza procesada con IA. Revisa y confirma los campos detectados.',
      );
    } catch (e) {
      debugPrint('Error en OCR de póliza de seguro: $e');
      if (mounted) {
        setState(() {
          _isScanningOcr = false;
        });
        SnackbarTop.showWarning(
          context,
          'No se pudieron extraer datos automáticamente. Puedes completarlos manualmente.',
        );
      }
    }
  }

  Future<void> _pickBackImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1920,
      );

      if (pickedFile == null) return;

      setState(() {
        _backImage = File(pickedFile.path);
      });
    } catch (e) {
      debugPrint('Error al capturar reverso: $e');
    }
  }

  void _showPhotoSourceDialog({required bool isFront}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                isFront
                    ? 'Capturar Carátula de Póliza'
                    : 'Capturar Tarjeta / Respaldo',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isFront
                    ? 'La carátula se escaneará con IA para autocompletar póliza, aseguradora y vigencias.'
                    : 'Adjunta una fotografía de respaldo de la tarjeta o contrato.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Color(0xFF0284C7)),
                ),
                title: const Text(
                  'Tomar Fotografía con Cámara',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (isFront) {
                    _pickAndScanFrontImage(ImageSource.camera);
                  } else {
                    _pickBackImage(ImageSource.camera);
                  }
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded,
                      color: Color(0xFF2563EB)),
                ),
                title: const Text(
                  'Seleccionar de la Galería',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (isFront) {
                    _pickAndScanFrontImage(ImageSource.gallery);
                  } else {
                    _pickBackImage(ImageSource.gallery);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MOTOR HEURÍSTICO OCR PARA PÓLIZAS DE SEGURO ---
  void _applyOcrResults(RecognizedText recognizedText) {
    final fullText = recognizedText.text;

    // 1. Extraer Número de Póliza
    final detectedPoliza = _extractPolizaNumber(fullText, recognizedText);
    if (detectedPoliza != null && detectedPoliza.isNotEmpty) {
      _polizaNumController.text = detectedPoliza;
    }

    // 2. Extraer Aseguradora / Compañía
    _extractCompaniaFromOcr(fullText);

    // 3. Extraer Tipo de Cobertura
    _extractCoberturaFromOcr(fullText);

    // 4. Extraer Fecha de Inicio
    final detectedInicio = _extractDateByKeywords(
      fullText,
      recognizedText,
      [
        'DESDE',
        'INICIO',
        'DESDE LAS',
        'VIGENCIA DESDE',
        'EMISION',
        'FECHA DE EMISION',
        'DESDE EL'
      ],
    );
    if (detectedInicio != null) {
      setState(() {
        _selectedFechaInicio = detectedInicio;
        _fechaInicioController.text =
            DateFormat('dd / MM / yyyy').format(detectedInicio);

        // Si no se detectó vencimiento, por defecto póliza anual (+1 año)
        if (_selectedFechaVencimiento == null) {
          final nextYear = DateTime(
            detectedInicio.year + 1,
            detectedInicio.month,
            detectedInicio.day,
          );
          _selectedFechaVencimiento = nextYear;
          _fechaVencimientoController.text =
              DateFormat('dd / MM / yyyy').format(nextYear);
        }
      });
    }

    // 5. Extraer Fecha de Vencimiento
    final detectedFin = _extractDateByKeywords(
      fullText,
      recognizedText,
      [
        'HASTA',
        'VENCE',
        'HASTA LAS',
        'VIGENCIA HASTA',
        'TERMINO',
        'VENCIMIENTO',
        'HASTA EL'
      ],
    );
    if (detectedFin != null) {
      setState(() {
        _selectedFechaVencimiento = detectedFin;
        _fechaVencimientoController.text =
            DateFormat('dd / MM / yyyy').format(detectedFin);
      });
    }

    // 6. Extraer Deducible
    final detectedDeducible = _extractDeducible(fullText);
    if (detectedDeducible != null &&
        (_deducibleController.text.trim().isEmpty ||
            _deducibleController.text == '0.00' ||
            _deducibleController.text == '0')) {
      _deducibleController.text = detectedDeducible.toStringAsFixed(2);
    }

    // 7. Extraer Monto / Prima Total
    final detectedMonto = _extractMonto(fullText);
    if (detectedMonto != null &&
        (_montoController.text.trim().isEmpty ||
            _montoController.text == '0.00' ||
            _montoController.text == '0')) {
      _montoController.text = detectedMonto.toStringAsFixed(2);
    }
  }

  String? _extractPolizaNumber(String fullText, RecognizedText recognizedText) {
    final keywordRegex = RegExp(
      r'(?:P[OÓ]LIZA(?:\s*NO\.?|\s*NUMERO|\s*NUM)?|NO\.?\s*DE\s*P[OÓ]LIZA|CERTIFICADO|INCISO)\s*[:.\-]?\s*([A-Z0-9\-]{5,22})',
      caseSensitive: false,
    );
    for (final m in keywordRegex.allMatches(fullText)) {
      final cand =
          m.group(1)!.replaceAll(' ', '').replaceAll('-', '').toUpperCase();
      if (_isValidPolizaNumber(cand)) {
        return cand;
      }
    }

    for (final block in recognizedText.blocks) {
      for (int i = 0; i < block.lines.length; i++) {
        final lineRaw = block.lines[i].text.toUpperCase();
        if (lineRaw.contains('POLIZA') || lineRaw.contains('PÓLIZA')) {
          if (i + 1 < block.lines.length) {
            final nextClean = block.lines[i + 1].text
                .toUpperCase()
                .replaceAll(' ', '')
                .replaceAll('-', '');
            if (_isValidPolizaNumber(nextClean)) {
              return nextClean;
            }
          }
        }
      }
    }

    return null;
  }

  bool _isValidPolizaNumber(String cand) {
    if (cand.length < 5 || cand.length > 25) return false;
    if (!RegExp(r'\d{3,}').hasMatch(cand)) return false;

    final forbidden = [
      'SERIE',
      'MOTOR',
      'CHASIS',
      'VIN',
      'NIV',
      'RFC',
      'CURP',
      'PLACA',
      'ESTADO',
      'GOBIERNO',
      'VEHICULAR',
      'SECRETARIA',
      'MOVILIDAD',
      'TRANSPORTE',
      'EXPEDICION',
      'VIGENCIA',
      'VENCIMIENTO',
      'MODELO',
      'MARCA',
      'CLASE',
      'TIPO',
      'COMBUSTIBLE',
      'CILINDROS',
      'ORIGEN',
      'PROPIETARIO',
      'DOMICILIO',
      'DERECHOS',
      'IMPORTE',
      'PAGO',
      'SEGURO',
      'SEGUROS',
      'QUALITAS',
      'GNP',
      'AXA',
      'MAPFRE',
      'BANORTE'
    ];
    for (final word in forbidden) {
      if (cand.contains(word)) return false;
    }

    final currentPlates = (widget.vehicle['placas'] ??
            widget.vehicle['plate'] ??
            '')
        .toString()
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .toUpperCase();
    if (currentPlates.isNotEmpty && cand == currentPlates) {
      return false;
    }

    return true;
  }

  void _extractCompaniaFromOcr(String fullText) {
    final upper = fullText.toUpperCase();
    if (_companias.isEmpty) return;

    for (final c in _companias) {
      final name = (c['nombre'] ?? c['name'] ?? '').toString().toUpperCase().trim();
      final id = (c['id'] ?? '').toString();
      if (name.isNotEmpty && upper.contains(name)) {
        setState(() => _selectedCompaniaId = id);
        return;
      }
    }
  }

  void _extractCoberturaFromOcr(String fullText) {
    final upper = fullText.toUpperCase();
    if (_coberturas.isEmpty) return;

    for (final c in _coberturas) {
      final name = (c['nombre'] ?? c['name'] ?? c['type'] ?? '').toString().toUpperCase().trim();
      final id = (c['id'] ?? '').toString();
      if (name.isNotEmpty && upper.contains(name)) {
        setState(() => _selectedCoberturaId = id);
        return;
      }
    }

    for (final c in _coberturas) {
      final name = (c['nombre'] ?? c['name'] ?? c['type'] ?? '').toString().toUpperCase();
      final id = (c['id'] ?? '').toString();
      if (upper.contains('AMPLIA PLUS') && name.contains('PLUS')) {
        setState(() => _selectedCoberturaId = id);
        return;
      } else if (upper.contains('AMPLIA') &&
          name.contains('AMPLIA') &&
          !name.contains('PLUS')) {
        setState(() => _selectedCoberturaId = id);
        return;
      } else if (upper.contains('LIMITADA') && name.contains('LIMITADA')) {
        setState(() => _selectedCoberturaId = id);
        return;
      } else if ((upper.contains('RESPONSABILIDAD CIVIL') ||
              upper.contains(' R.C. ') ||
              upper.contains(' RC ')) &&
          (name.contains('RESPONSABILIDAD') || name.contains('RC'))) {
        setState(() => _selectedCoberturaId = id);
        return;
      }
    }
  }

  DateTime? _extractDateByKeywords(
    String fullText,
    RecognizedText recognizedText,
    List<String> keywords,
  ) {
    final dateRegex =
        RegExp(r'\b(\d{1,2})[\/\.\-](\d{1,2})[\/\.\-](\d{2,4})\b');
    final dateIsoRegex =
        RegExp(r'\b(\d{4})[\/\.\-](\d{1,2})[\/\.\-](\d{1,2})\b');

    for (final block in recognizedText.blocks) {
      for (int i = 0; i < block.lines.length; i++) {
        final line = block.lines[i].text.toUpperCase();
        for (final kw in keywords) {
          if (line.contains(kw)) {
            var m = dateRegex.firstMatch(block.lines[i].text);
            if (m != null) {
              final d = int.tryParse(m.group(1)!);
              final mo = int.tryParse(m.group(2)!);
              var y = int.tryParse(m.group(3)!);
              if (d != null &&
                  mo != null &&
                  y != null &&
                  mo >= 1 &&
                  mo <= 12 &&
                  d >= 1 &&
                  d <= 31) {
                if (y < 100) y += 2000;
                return DateTime(y, mo, d);
              }
            }
            var mIso = dateIsoRegex.firstMatch(block.lines[i].text);
            if (mIso != null) {
              final y = int.tryParse(mIso.group(1)!);
              final mo = int.tryParse(mIso.group(2)!);
              final d = int.tryParse(mIso.group(3)!);
              if (d != null &&
                  mo != null &&
                  y != null &&
                  mo >= 1 &&
                  mo <= 12 &&
                  d >= 1 &&
                  d <= 31) {
                return DateTime(y, mo, d);
              }
            }

            if (i + 1 < block.lines.length) {
              final nextText = block.lines[i + 1].text;
              m = dateRegex.firstMatch(nextText);
              if (m != null) {
                final d = int.tryParse(m.group(1)!);
                final mo = int.tryParse(m.group(2)!);
                var y = int.tryParse(m.group(3)!);
                if (d != null &&
                    mo != null &&
                    y != null &&
                    mo >= 1 &&
                    mo <= 12 &&
                    d >= 1 &&
                    d <= 31) {
                  if (y < 100) y += 2000;
                  return DateTime(y, mo, d);
                }
              }
              mIso = dateIsoRegex.firstMatch(nextText);
              if (mIso != null) {
                final y = int.tryParse(mIso.group(1)!);
                final mo = int.tryParse(mIso.group(2)!);
                final d = int.tryParse(mIso.group(3)!);
                if (d != null &&
                    mo != null &&
                    y != null &&
                    mo >= 1 &&
                    mo <= 12 &&
                    d >= 1 &&
                    d <= 31) {
                  return DateTime(y, mo, d);
                }
              }
            }
          }
        }
      }
    }
    return null;
  }

  double? _extractDeducible(String fullText) {
    final regex = RegExp(
      r'(?:DEDUCIBLE|DM|D\.M\.)\s*[:.\-]?\s*\$?\s*([0-9]{1,4}(?:[,\.][0-9]{2,3})*(?:\.[0-9]{2})?)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(fullText);
    if (match != null) {
      final str = match.group(1)!.replaceAll(',', '');
      return double.tryParse(str);
    }
    return null;
  }

  double? _extractMonto(String fullText) {
    final regex = RegExp(
      r'(?:PRIMA\s*TOTAL|TOTAL\s*A\s*PAGAR|IMPORTE\s*TOTAL|COSTO|TOTAL|\$)\s*[:.\-]?\s*\$?\s*([0-9]{1,4}(?:[,\.][0-9]{2,3})*(?:\.[0-9]{2})?)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(fullText);
    if (match != null) {
      final str = match.group(1)!.replaceAll(',', '');
      return double.tryParse(str);
    }
    return null;
  }

  Future<void> _selectDate(
    BuildContext context, {
    required String title,
    DateTime? initialDate,
    required ValueChanged<DateTime> onDateSelected,
  }) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: title,
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
      onDateSelected(picked);
    }
  }

  // =========================================================================
  // SUBMIT FORMULARIO (CREAR O ACTUALIZAR)
  // =========================================================================
  Future<void> _submitForm({required bool isEditing}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCompaniaId == null || _selectedCompaniaId!.isEmpty) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona una compañía aseguradora.',
      );
      return;
    }

    if (_selectedCoberturaId == null || _selectedCoberturaId!.isEmpty) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona el tipo de cobertura.',
      );
      return;
    }

    if (_selectedFechaInicio == null) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona la fecha de inicio del seguro.',
      );
      return;
    }

    if (_selectedFechaVencimiento == null) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona la fecha de vencimiento.',
      );
      return;
    }

    if (_selectedFechaInicio!.isAfter(_selectedFechaVencimiento!)) {
      SnackbarTop.showInfo(
        context,
        'La fecha de inicio no puede ser posterior a la fecha de vencimiento.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String polizaNum = _polizaNumController.text.trim();
    final double deducible =
        double.tryParse(_deducibleController.text.trim()) ?? 0.0;
    final double monto = double.tryParse(_montoController.text.trim()) ?? 0.0;
    final String observaciones = _observacionesController.text.trim();

    final String formattedFechaInicio =
        DateFormat('yyyy-MM-dd').format(_selectedFechaInicio!);
    final String formattedFechaVencimiento =
        DateFormat('yyyy-MM-dd').format(_selectedFechaVencimiento!);

    final vehicleId = widget.vehicle['id'].toString();
    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        '';

    try {
      // 1. Subir fotografías a la API si están presentes
      final List<String> photoUuids = [];
      if (_frontImage != null) {
        final uuidFront = const Uuid().v4();
        final ok = await MarkApiClient.instance.uploadPhoto(
          uuid: uuidFront,
          tipo: 1,
          filePath: _frontImage!.path,
        );
        if (ok) {
          photoUuids.add(uuidFront);
        }
      }

      if (_backImage != null &&
          (_frontImage == null || _frontImage!.path != _backImage!.path)) {
        final uuidBack = const Uuid().v4();
        final ok = await MarkApiClient.instance.uploadPhoto(
          uuid: uuidBack,
          tipo: 1,
          filePath: _backImage!.path,
        );
        if (ok) {
          photoUuids.add(uuidBack);
        }
      }

      if (isEditing) {
        // --- ACTUALIZACIÓN DE SEGURO ---
        await VehiclesconService().actualizarSeguroPorVehiculo(
          vehicleId,
          widget.idMainAccount,
          _selectedCompaniaId!,
          polizaNum,
          _selectedCoberturaId!,
          formattedFechaInicio,
          formattedFechaVencimiento,
          deducible,
          monto,
          observaciones,
          fotos: photoUuids,
        );

        // Notificación de actualización
        try {
          const nameNotice = 'vehicle_insurance_updated';
          final noticeTemplate =
              await NotificationService().getNoticeByName(nameNotice);

          if (noticeTemplate != null) {
            String message = '';
            final rawMsg = noticeTemplate['message'];
            if (rawMsg is List<int>) {
              try {
                message = utf8.decode(rawMsg);
              } catch (_) {
                message = rawMsg.toString();
              }
            } else {
              message = rawMsg?.toString() ?? '';
            }

            final formattedMessage = message
                .replaceAll('{vehicle_plate}', plates)
                .replaceAll('{insurance_company}', _selectedCompaniaId!)
                .replaceAll('{policy_number}', polizaNum)
                .replaceAll('{coverage_type}', _selectedCoberturaId!)
                .replaceAll('{start_date}', formattedFechaInicio)
                .replaceAll('{due_date}', formattedFechaVencimiento);

            final title = (noticeTemplate['title']?.toString() ?? '')
                .replaceAll('{vehicle_plate}', plates);

            final finalMessage =
                '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

            final currentInsurances =
                ref.read(insuranceProvider).insurances;
            final int idinsurance =
                currentInsurances.isNotEmpty ? currentInsurances.first.id : 0;

            await NotificationService().insertNotification({
              'typeSource': _typeSource,
              'idOrigin': idinsurance,
              'typEvent': 2,
              'date': DateTime.now().toIso8601String(),
              'message': finalMessage,
              'colNotice': 'insurance_Edit',
              'idMainAcoount': widget.idMainAccount,
              'codUsGenerator': widget.userId,
              'idDev': widget.userId,
            });
          }
        } catch (notifErr) {
          debugPrint(
              'Error en notificación de actualización de seguro: $notifErr');
        }

        // Actualizar control de gestión
        await VehiclesconService().updateManagementControlINS(
          widget.idMainAccount,
          vehicleId,
          formattedFechaVencimiento,
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
            _isEditing = false;
            _frontImage = null;
            _backImage = null;
          });
          SnackbarTop.showSuccess(
            context,
            'Póliza de seguro actualizada exitosamente.',
          );
          _refreshData();
        }
      } else {
        // --- CREACIÓN DE SEGURO ---
        final int idinsurance = await VehiclesconService().crearSeguro(
          vehicleId,
          _selectedCompaniaId!,
          widget.idMainAccount,
          polizaNum,
          _selectedCoberturaId!,
          formattedFechaInicio,
          formattedFechaVencimiento,
          deducible.toString(),
          monto.toString(),
          observaciones,
          fotos: photoUuids,
        );

        // Notificación de nuevo seguro
        try {
          const nameNotice = 'vehicle_insurance_added';
          final noticeTemplate =
              await NotificationService().getNoticeByName(nameNotice);

          if (noticeTemplate != null) {
            String message = '';
            final rawMsg = noticeTemplate['message'];
            if (rawMsg is List<int>) {
              try {
                message = utf8.decode(rawMsg);
              } catch (_) {
                message = rawMsg.toString();
              }
            } else {
              message = rawMsg?.toString() ?? '';
            }

            final formattedMessage = message
                .replaceAll('{vehicle_plate}', plates)
                .replaceAll('{insurance_company}', _selectedCompaniaId!)
                .replaceAll('{policy_number}', polizaNum)
                .replaceAll('{coverage_type}', _selectedCoberturaId!)
                .replaceAll('{start_date}', formattedFechaInicio)
                .replaceAll('{due_date}', formattedFechaVencimiento);

            final title = (noticeTemplate['title']?.toString() ?? '')
                .replaceAll('{vehicle_plate}', plates);

            final finalMessage =
                '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

            await NotificationService().insertNotification({
              'typeSource': _typeSource,
              'idOrigin': idinsurance,
              'typEvent': 1,
              'date': DateTime.now().toIso8601String(),
              'message': finalMessage,
              'colNotice': 'insurance_New',
              'idMainAcoount': widget.idMainAccount,
              'codUsGenerator': widget.userId,
              'idDev': widget.userId,
            });
          }
        } catch (notifErr) {
          debugPrint(
              'Error en notificación de creación de seguro: $notifErr');
        }

        // Insertar control de gestión
        await VehiclesconService().insertManagementControlINS(
          widget.idMainAccount,
          vehicleId,
          _selectedFechaVencimiento!,
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
            _isEditing = false;
            _frontImage = null;
            _backImage = null;
          });
          SnackbarTop.showSuccess(
            context,
            'Póliza de seguro registrada correctamente.',
          );
          _refreshData();
        }
      }
    } catch (e) {
      debugPrint('Error al guardar seguro: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        SnackbarTop.showError(
          context,
          'Ocurrió un error al procesar la solicitud: ${e.toString().replaceAll('Exception:', '').trim()}',
        );
      }
    }
  }

  // =========================================================================
  // BUILD PRINCIPAL
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isSmallScreen = mediaQuery.size.width < 360;
    final insuranceState = ref.watch(insuranceProvider);

    if (insuranceState.isConnectionError) {
      return ConnectionErrorPage(onRetry: _refreshData);
    }
    if (insuranceState.isServerError) {
      return ServerErrorPage(onRetry: _refreshData);
    }
    if (insuranceState.isUnexpectedError) {
      return Unexpectederrorpage(onRetry: _refreshData);
    }

    final hasInsurance = insuranceState.insurances.isNotEmpty;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: RefreshIndicator(
            color: const Color(0xFF0284C7),
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12.0 : 16.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, hasInsurance: hasInsurance),
                  const SizedBox(height: 12),
                  if (!_canEdit && !_canCreate && !hasInsurance)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFBFDBFE),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Modo solo lectura: Tu rol cuenta con permisos para consultar la póliza de seguro y sus vigencias, pero no para registrar o modificar datos.',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    const Color(0xFF1E3A8A).withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (insuranceState.isLoading)
                    _buildSkeleton(isSmallScreen)
                  else if (_isEditing)
                    _buildFormSection(isEditing: hasInsurance)
                  else if (!hasInsurance)
                    _buildEmptyState()
                  else
                    _buildInsuranceDetails(insuranceState.insurances.first),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // HEADER SUPERIOR ESTILO APPLE
  // =========================================================================
  Widget _buildHeader(BuildContext context, {required bool hasInsurance}) {
    final make = widget.vehicle['make']?.toString() ?? '';
    final model = widget.vehicle['model']?.toString() ?? '';
    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        'Sin Placas';

    final subtitle = (make.isNotEmpty || model.isNotEmpty)
        ? '$make $model · Placas: $plates'
        : 'Placas: $plates';

    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (_isEditing && hasInsurance) {
                setState(() => _isEditing = false);
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF0F172A),
                  size: 15,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing
                    ? (hasInsurance ? 'Editar Póliza' : 'Registrar Póliza')
                    : 'Póliza de Seguro',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        if (!_isEditing) ...[
          const SizedBox(width: 8),
          _buildHeaderActionMenu(context),
        ],
      ],
    );
  }

  Widget _buildHeaderActionMenu(BuildContext context) {
    final List<PopupMenuEntry<String>> menuItems = [];
    final hasInsurance =
        ref.watch(insuranceProvider).insurances.isNotEmpty;

    if (hasInsurance && _canEdit) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'edit',
          title: 'Editar Póliza',
          icon: Icons.edit_rounded,
          iconColor: const Color(0xFF0284C7),
        ),
      );
    }

    if (hasInsurance && _canDelete) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'delete',
          title: 'Eliminar Póliza',
          icon: Icons.delete_outline_rounded,
          iconColor: const Color(0xFFEF4444),
          textColor: const Color(0xFFEF4444),
        ),
      );
    }

    if (!hasInsurance && _canCreate) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'create',
          title: 'Registrar Póliza',
          icon: Icons.add_circle_outline_rounded,
          iconColor: const Color(0xFF0284C7),
        ),
      );
    }

    if (menuItems.isEmpty) {
      return const SizedBox(width: 38, height: 38);
    }

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Opciones de seguro',
        padding: EdgeInsets.zero,
        icon: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.more_horiz_rounded,
              color: Color(0xFF0F172A),
              size: 20,
            ),
          ),
        ),
        itemBuilder: (context) => menuItems,
        onSelected: (action) {
          if (action == 'edit') {
            final insurances = ref.read(insuranceProvider).insurances;
            if (insurances.isNotEmpty) {
              _startEditing(insurances.first);
            }
          } else if (action == 'delete') {
            _showDeleteConfirmationDialog();
          } else if (action == 'create') {
            _startCreating();
          }
        },
      ),
    );
  }

  PopupMenuEntry<String> _buildPopupMenuItem({
    required String value,
    required String title,
    required IconData icon,
    required Color iconColor,
    Color textColor = const Color(0xFF0F172A),
  }) {
    return PopupMenuItem<String>(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _startEditing(InsuranceModel seguro) {
    setState(() {
      _isEditing = true;
      _polizaNumController.text = seguro.polizaNum;
      _deducibleController.text = seguro.deducible;
      _montoController.text = seguro.monto;
      _observacionesController.text = seguro.observaciones;

      _selectedFechaInicio = _parseDateSafe(seguro.fechaInicio);
      _fechaInicioController.text = _selectedFechaInicio != null
          ? DateFormat('dd / MM / yyyy').format(_selectedFechaInicio!)
          : '';

      _selectedFechaVencimiento = _parseDateSafe(seguro.fechaVencimiento);
      _fechaVencimientoController.text = _selectedFechaVencimiento != null
          ? DateFormat('dd / MM / yyyy').format(_selectedFechaVencimiento!)
          : '';

      _selectedCompaniaId = _resolveIdFromList(
          _companias, seguro.idCompania);

      _selectedCoberturaId = _resolveIdFromList(
          _coberturas, seguro.idTipoCobertura);

      _frontImage = null;
      _backImage = null;
    });
  }

  void _startCreating() {
    setState(() {
      _isEditing = true;
      _polizaNumController.clear();
      _deducibleController.text = '0.00';
      _montoController.text = '0.00';
      _observacionesController.clear();
      _fechaInicioController.clear();
      _fechaVencimientoController.clear();
      _selectedFechaInicio = null;
      _selectedFechaVencimiento = null;
      _selectedCompaniaId = null;
      _selectedCoberturaId = null;
      _frontImage = null;
      _backImage = null;
    });
  }

  String? _resolveIdFromList(List<Map<String, dynamic>> list, String val) {
    if (val.trim().isEmpty || list.isEmpty) return null;
    final cleanVal = val.trim().toLowerCase();
    for (final item in list) {
      final id = item['id']?.toString().trim().toLowerCase();
      final name = (item['nombre'] ?? item['name'] ?? item['type'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (id == cleanVal || name == cleanVal) {
        return item['id']?.toString();
      }
    }
    return null;
  }

  // =========================================================================
  // VISTA DE FORMULARIO ESTILO APPLE HIG (EN PÁGINA)
  // =========================================================================
  Widget _buildFormSection({required bool isEditing}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. FOTOGRAFÍAS DE LA PÓLIZA DE SEGURO
          _buildSectionTitle('FOTOGRAFÍAS DE LA PÓLIZA DE SEGURO'),
          _buildAppleGroupContainer(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildPhotoBox(
                      title: 'Carátula de Póliza',
                      tag: 'IA OCR',
                      image: _frontImage,
                      isScanning: _isScanningOcr,
                      onTap: () => _showPhotoSourceDialog(isFront: true),
                      onRemove: () => setState(() => _frontImage = null),
                      isRequired: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPhotoBox(
                      title: 'Tarjeta / Respaldo',
                      tag: 'OPCIONAL',
                      image: _backImage,
                      isScanning: false,
                      onTap: () => _showPhotoSourceDialog(isFront: false),
                      onRemove: () => setState(() => _backImage = null),
                      isRequired: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0284C7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'El escaneo con IA completará automáticamente la póliza, aseguradora, coberturas y vigencias detectadas. Podrás revisar o editar la información antes de guardar.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0369A1),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. DATOS DE LA PÓLIZA
          _buildSectionTitle('DATOS DE LA PÓLIZA'),
          _buildAppleGroupContainer(
            children: [
              // Número de Póliza
              _buildFieldLabel('Número de Póliza *'),
              TextFormField(
                controller: _polizaNumController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 30,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
                decoration: _buildInputDecoration(
                  hint: 'Ej. 01-94820194-00',
                  prefixIcon: Icons.badge_outlined,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Ingresa el número de póliza.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Aseguradora Dropdown
              _buildFieldLabel('Compañía Aseguradora *'),
              _buildCompaniaDropdown(),
              const SizedBox(height: 14),

              // Cobertura Dropdown
              _buildFieldLabel('Tipo de Cobertura *'),
              _buildCoberturaDropdown(),
              const SizedBox(height: 14),

              // Fechas (Inicio y Vencimiento)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Fecha de Inicio *'),
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            _selectDate(
                              context,
                              title: 'Fecha de Inicio de Seguro',
                              initialDate: _selectedFechaInicio,
                              onDateSelected: (date) {
                                setState(() {
                                  _selectedFechaInicio = date;
                                  _fechaInicioController.text =
                                      DateFormat('dd / MM / yyyy')
                                          .format(date);

                                  if (_selectedFechaVencimiento == null) {
                                    final nextYear = DateTime(
                                      date.year + 1,
                                      date.month,
                                      date.day,
                                    );
                                    _selectedFechaVencimiento = nextYear;
                                    _fechaVencimientoController.text =
                                        DateFormat('dd / MM / yyyy')
                                            .format(nextYear);
                                  }
                                });
                              },
                            );
                          },
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: _fechaInicioController,
                              readOnly: true,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                              decoration: _buildInputDecoration(
                                hint: 'dd / mm / aaaa',
                                prefixIcon: Icons.event_available_rounded,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Selecciona la fecha.';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Fecha de Vencimiento *'),
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            _selectDate(
                              context,
                              title: 'Fecha de Vencimiento',
                              initialDate: _selectedFechaVencimiento,
                              onDateSelected: (date) {
                                setState(() {
                                  _selectedFechaVencimiento = date;
                                  _fechaVencimientoController.text =
                                      DateFormat('dd / MM / yyyy')
                                          .format(date);
                                });
                              },
                            );
                          },
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: _fechaVencimientoController,
                              readOnly: true,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                              decoration: _buildInputDecoration(
                                hint: 'dd / mm / aaaa',
                                prefixIcon: Icons.event_busy_rounded,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Selecciona la fecha.';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Deducible y Monto Total
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Deducible (%) *'),
                        TextFormField(
                          controller: _deducibleController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'),
                            ),
                          ],
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          decoration: _buildInputDecoration(
                            hint: '0.00',
                            prefixIcon: Icons.percent_rounded,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresa el deducible.';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Prima Total / Costo *'),
                        TextFormField(
                          controller: _montoController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'),
                            ),
                          ],
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          decoration: _buildInputDecoration(
                            hint: '0.00',
                            prefixIcon: Icons.attach_money_rounded,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresa la prima total.';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Observaciones
              _buildFieldLabel('Observaciones / Notas'),
              TextFormField(
                controller: _observacionesController,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F172A),
                ),
                decoration: _buildInputDecoration(
                  hint: 'Notas adicionales, cláusulas o endosos...',
                  prefixIcon: Icons.notes_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 3. BOTONES DE ACCIÓN
          Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF475569),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () => setState(() => _isEditing = false),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: LoadingActionButton(
                  text: isEditing
                      ? 'Guardar Cambios'
                      : 'Registrar Póliza',
                  icon: isEditing ? Icons.check_rounded : Icons.add_rounded,
                  isLoading: _isLoading,
                  height: 48,
                  borderRadius: 14,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onPressed: () => _submitForm(isEditing: isEditing),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCompaniaDropdown() {
    if (_companias.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF0284C7),
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Cargando aseguradoras...',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    final bool hasValidCompania = _selectedCompaniaId != null &&
        _companias.any((c) => c['id']?.toString() == _selectedCompaniaId);
    final String? currentCompaniaValue =
        hasValidCompania ? _selectedCompaniaId : null;

    return DropdownButtonFormField2<String>(
      value: currentCompaniaValue,
      isExpanded: true,
      decoration: _buildInputDecoration(
        hint: 'Selecciona la aseguradora',
        prefixIcon: Icons.business_rounded,
      ),
      items: _companias.map((compania) {
        final rawName =
            (compania['nombre'] ?? compania['name'] ?? compania['aseguradora'] ?? '')
                .toString()
                .trim();
        final name = rawName.isNotEmpty ? rawName : 'Aseguradora';
        return DropdownMenuItem<String>(
          value: compania['id']?.toString(),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCompaniaId = value;
        });
      },
      buttonStyleData: const ButtonStyleData(
        padding: EdgeInsets.only(right: 8),
      ),
      iconStyleData: const IconStyleData(
        icon: Icon(
          Icons.arrow_drop_down_rounded,
          color: Color(0xFF64748B),
          size: 24,
        ),
      ),
      dropdownStyleData: DropdownStyleData(
        maxHeight: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
      menuItemStyleData: const MenuItemStyleData(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
    );
  }

  Widget _buildCoberturaDropdown() {
    if (_coberturas.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF0284C7),
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Cargando coberturas...',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    final bool hasValidCobertura = _selectedCoberturaId != null &&
        _coberturas.any((c) => c['id']?.toString() == _selectedCoberturaId);
    final String? currentCoberturaValue =
        hasValidCobertura ? _selectedCoberturaId : null;

    return DropdownButtonFormField2<String>(
      value: currentCoberturaValue,
      isExpanded: true,
      decoration: _buildInputDecoration(
        hint: 'Selecciona el tipo de cobertura',
        prefixIcon: Icons.shield_outlined,
      ),
      items: _coberturas.map((cobertura) {
        final rawName =
            (cobertura['nombre'] ?? cobertura['name'] ?? cobertura['type'] ?? '')
                .toString()
                .trim();
        final name = rawName.isNotEmpty ? rawName : 'Cobertura';
        return DropdownMenuItem<String>(
          value: cobertura['id']?.toString(),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCoberturaId = value;
        });
      },
      buttonStyleData: const ButtonStyleData(
        padding: EdgeInsets.only(right: 8),
      ),
      iconStyleData: const IconStyleData(
        icon: Icon(
          Icons.arrow_drop_down_rounded,
          color: Color(0xFF64748B),
          size: 24,
        ),
      ),
      dropdownStyleData: DropdownStyleData(
        maxHeight: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
      menuItemStyleData: const MenuItemStyleData(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
    );
  }

  // =========================================================================
  // CAJA DE FOTOGRAFÍA ESTILO APPLE CARD
  // =========================================================================
  Widget _buildPhotoBox({
    required String title,
    required String tag,
    required File? image,
    required bool isScanning,
    required VoidCallback onTap,
    required VoidCallback onRemove,
    required bool isRequired,
  }) {
    return DocumentPhotoBox(
      title: title,
      tag: tag,
      image: image,
      isScanning: isScanning,
      onTap: onTap,
      onRemove: onRemove,
      isRequired: isRequired,
    );
  }

  Widget _buildPhotoBoxOld_UNUSED({
    required String title,
    required String tag,
    required File? image,
    required bool isScanning,
    required VoidCallback onTap,
    required VoidCallback onRemove,
    required bool isRequired,
  }) {
    final hasImage = image != null;
    final isOcrFront = tag == 'IA OCR';

    return GestureDetector(
      onTap: isScanning ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 132,
        decoration: BoxDecoration(
          color: hasImage ? Colors.black : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasImage
                ? const Color(0xFF0284C7)
                : (isOcrFront
                    ? const Color(0xFFBAE6FD)
                    : const Color(0xFFE2E8F0)),
            width: hasImage ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage) ...[
                Image.file(
                  image,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.65),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 11, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          isOcrFront ? 'Frente listo' : 'Reverso listo',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3), width: 1),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cached_rounded,
                            size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Cambiar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOcrFront
                          ? const Color(0xFFE0F2FE)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isOcrFront
                            ? const Color(0xFFBAE6FD)
                            : const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isOcrFront) ...[
                          const Icon(Icons.auto_awesome,
                              size: 10, color: Color(0xFF0284C7)),
                          const SizedBox(width: 3),
                        ],
                        Text(
                          tag,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: isOcrFront
                                ? const Color(0xFF0284C7)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: isScanning
                      ? const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Escaneando IA...',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: isOcrFront
                                      ? [
                                          const Color(0xFFE0F2FE),
                                          const Color(0xFFBAE6FD)
                                        ]
                                      : [
                                          const Color(0xFFF1F5F9),
                                          const Color(0xFFE2E8F0)
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Icon(
                                isOcrFront
                                    ? Icons.document_scanner_rounded
                                    : Icons.flip_to_back_rounded,
                                color: isOcrFront
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF64748B),
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isOcrFront
                                  ? 'Escanear Carátula'
                                  : 'Foto Reverso',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isOcrFront
                                  ? 'Cámara o Galería'
                                  : 'Respaldo opcional',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF94A3B8),
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
    );
  }

  // =========================================================================
  // DETALLES DE LA PÓLIZA (APPLE WALLET HERO COLOR ÍNDIGO NOCTURNO)
  // =========================================================================
  Widget _buildInsuranceDetails(InsuranceModel seguro) {
    String companiaName = seguro.idCompania;
    if (_companias.isNotEmpty) {
      final cleanComp = seguro.idCompania.trim().toLowerCase();
      for (final c in _companias) {
        final id = c['id']?.toString().trim().toLowerCase();
        final name =
            (c['nombre'] ?? c['name'] ?? '').toString().trim().toLowerCase();
        if (id == cleanComp || name == cleanComp) {
          final n = (c['nombre'] ?? c['name'])?.toString().trim();
          if (n != null && n.isNotEmpty) companiaName = n;
          break;
        }
      }
    }

    String coberturaName = seguro.idTipoCobertura;
    if (_coberturas.isNotEmpty) {
      final cleanCob = seguro.idTipoCobertura.trim().toLowerCase();
      for (final c in _coberturas) {
        final id = c['id']?.toString().trim().toLowerCase();
        final name = (c['nombre'] ?? c['name'] ?? c['type'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (id == cleanCob || name == cleanCob) {
          final n =
              (c['nombre'] ?? c['name'] ?? c['type'])?.toString().trim();
          if (n != null && n.isNotEmpty) coberturaName = n;
          break;
        }
      }
    }

    final compania =
        companiaName.trim().isNotEmpty ? companiaName : 'Aseguradora';
    final policyNum =
        seguro.polizaNum.trim().isNotEmpty ? seguro.polizaNum : 'Sin Póliza';
    final tipoCobertura = coberturaName.trim().isNotEmpty
        ? coberturaName
        : 'Cobertura Estándar';

    final deducible = double.tryParse(seguro.deducible) ?? 0.0;
    final monto = double.tryParse(seguro.monto) ?? 0.0;

    final fechaInicioStr = _formatDisplayDate(seguro.fechaInicio);
    final fechaVencimientoStr = _formatDisplayDate(seguro.fechaVencimiento);
    final observaciones = seguro.observaciones.trim();

    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        'OFICIAL';

    final parsedExpiry = _parseDateSafe(seguro.fechaVencimiento);

    int daysRemaining = 0;
    bool isExpired = false;
    bool isToday = false;
    bool isClose = false;

    Color badgeBg;
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (parsedExpiry == null) {
      badgeBg = const Color(0xFF6366F1).withOpacity(0.2);
      badgeColor = const Color(0xFFA5B4FC);
      badgeText = 'REGISTRADA';
      badgeIcon = Icons.verified_rounded;
    } else {
      daysRemaining = _calculateDaysDifference(parsedExpiry);
      if (daysRemaining < 0) {
        isExpired = true;
        badgeBg = const Color(0xFFEF4444).withOpacity(0.25);
        badgeColor = const Color(0xFFFCA5A5);
        badgeText = 'VENCIDA';
        badgeIcon = Icons.error_rounded;
      } else if (daysRemaining == 0) {
        isToday = true;
        badgeBg = const Color(0xFFEA580C).withOpacity(0.25);
        badgeColor = const Color(0xFFFDBA74);
        badgeText = 'VENCE HOY';
        badgeIcon = Icons.warning_amber_rounded;
      } else if (daysRemaining <= 30) {
        isClose = true;
        badgeBg = const Color(0xFFEA580C).withOpacity(0.25);
        badgeColor = const Color(0xFFFDBA74);
        badgeText = 'POR VENCER';
        badgeIcon = Icons.warning_amber_rounded;
      } else {
        badgeBg = const Color(0xFF10B981).withOpacity(0.25);
        badgeColor = const Color(0xFF6EE7B7);
        badgeText = 'VIGENTE';
        badgeIcon = Icons.check_circle_rounded;
      }
    }

    // Extraer IDs de fotografías registradas
    final List<int> fotoIds = [];
    for (final f in seguro.fotos) {
      int? p;
      if (f is int) {
        p = f;
      } else if (f is Map && f['id'] != null) {
        p = int.tryParse(f['id'].toString());
      } else if (f != null) {
        p = int.tryParse(f.toString());
      }
      if (p != null && !fotoIds.contains(p)) {
        fotoIds.add(p);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. TARJETA DIGITAL APPLE WALLET HERO (MIDNIGHT INDIGO & ROYAL AMETHYST)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1E1B4B),
                Color(0xFF2E1065),
                Color(0xFF6366F1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E1B4B).withOpacity(0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned(
                  top: -40,
                  right: -30,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -60,
                  left: -40,
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Icon(
                                    Icons.shield_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'PÓLIZA DE SEGURO',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white
                                              .withOpacity(0.95),
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                      Text(
                                        'COBERTURA & PROTECCIÓN VEHICULAR',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white
                                              .withOpacity(0.65),
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 11,
                                  color: Color(0xFFA5B4FC),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  plates.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.28),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.business_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          compania.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cobertura: $tipoCobertura',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.75),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'NÚMERO DE PÓLIZA',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.65),
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    policyNum,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'VENCIMIENTO',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.65),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  fechaVencimientoStr,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: badgeColor.withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(badgeIcon, size: 12, color: badgeColor),
                                const SizedBox(width: 5),
                                Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: badgeColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 2. SECCIÓN: ESTATUS DE COBERTURA Y VIGENCIA
        _buildSectionTitle('ESTATUS DE COBERTURA Y VIGENCIA'),
        _buildAppleGroupContainer(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isExpired
                        ? const Color(0xFFFEE2E2)
                        : (isClose || isToday
                            ? const Color(0xFFFFF7ED)
                            : const Color(0xFFDCFCE7)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      isExpired
                          ? Icons.error_outline_rounded
                          : (isClose || isToday
                              ? Icons.warning_amber_rounded
                              : Icons.verified_user_rounded),
                      color: isExpired
                          ? const Color(0xFFEF4444)
                          : (isClose || isToday
                              ? const Color(0xFFEA580C)
                              : const Color(0xFF10B981)),
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
                        isExpired
                            ? 'Póliza de Seguro Vencida'
                            : (isToday
                                ? 'Póliza Vence el Día de Hoy'
                                : (isClose
                                    ? 'Próxima a Vencer'
                                    : 'Seguro Activo y Vigente')),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isExpired
                            ? 'Expiró hace ${-daysRemaining} días. La unidad carece de cobertura financiera.'
                            : (isToday
                                ? 'La validez del seguro termina hoy a las 23:59 hrs.'
                                : (isClose
                                    ? 'Quedan $daysRemaining días antes de que expire la cobertura.'
                                    : 'Quedan $daysRemaining días de respaldo activo ante siniestros.')),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isExpired
                              ? 'CONDICIÓN: UNIDAD DESPROTEGIDA ANTE ACCIDENTES'
                              : (isClose || isToday
                                  ? 'CONDICIÓN: RENOVACIÓN DE PÓLIZA REQUERIDA'
                                  : 'CONDICIÓN: COBERTURA Y RESPALDO COMPLETO'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isExpired
                                ? const Color(0xFFDC2626)
                                : (isClose || isToday
                                    ? const Color(0xFFC2410C)
                                    : const Color(0xFF15803D)),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isExpired
                              ? 'Renueva el contrato de inmediato para evitar multas de tránsito y pérdidas patrimoniales.'
                              : 'Póliza legal para circular en carreteras y vías públicas del país.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpired
                        ? Icons.report_problem_rounded
                        : (isClose || isToday
                            ? Icons.alarm_rounded
                            : Icons.check_circle_outline_rounded),
                    color: isExpired
                        ? const Color(0xFFEF4444)
                        : (isClose || isToday
                            ? const Color(0xFFEA580C)
                            : const Color(0xFF10B981)),
                    size: 22,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 3. SECCIÓN: DETALLES DE LA PÓLIZA
        _buildSectionTitle('DETALLES DE LA PÓLIZA'),
        _buildAppleGroupContainer(
          children: [
            _buildDetailRow(
              icon: Icons.business_rounded,
              label: 'Compañía Aseguradora',
              value: compania,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.shield_outlined,
              label: 'Tipo de Cobertura',
              value: tipoCobertura,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.description_outlined,
              label: 'Número de Póliza',
              value: policyNum,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.percent_rounded,
              label: 'Deducible',
              value: _currencyFormat.format(deducible),
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.event_available_rounded,
              label: 'Fecha de Contratación / Inicio',
              value: fechaInicioStr,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.event_busy_rounded,
              label: 'Fecha de Vencimiento',
              value: fechaVencimientoStr,
            ),
            if (observaciones.isNotEmpty) ...[
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _buildDetailRow(
                icon: Icons.notes_rounded,
                label: 'Observaciones',
                value: observaciones,
              ),
            ],
            const Divider(height: 20, color: Color(0xFFE2E8F0)),
            _buildDetailRow(
              icon: Icons.monetization_on_outlined,
              label: 'Prima Total / Monto',
              value: _currencyFormat.format(monto),
              isHighlight: true,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 4. FOTOGRAFÍAS REGISTRADAS DE LA PÓLIZA (SI EXISTEN)
        if (fotoIds.isNotEmpty) ...[
          _buildSectionTitle('FOTOGRAFÍAS DE LA PÓLIZA'),
          _buildAppleGroupContainer(
            children: [
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: fotoIds.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 190,
                        color: const Color(0xFFF1F5F9),
                        child: DocFotoWidget(
                          idFoto: fotoIds[index],
                          width: 190,
                          height: 130,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.touch_app_outlined,
                      size: 14, color: Color(0xFF0284C7)),
                  SizedBox(width: 6),
                  Text(
                    'Toca cualquier imagen para verla en pantalla completa.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  // --- FILA DE DETALLE ESTILO APPLE ---
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    return AppleDetailRow(
      icon: icon,
      label: label,
      value: value,
      isHighlight: isHighlight,
    );
  }

  Widget _buildSectionTitle(String title) {
    return AppleSectionTitle(
      title,
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
    );
  }

  Widget _buildAppleGroupContainer({required List<Widget> children}) {
    return AppleGroupCard(children: children);
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 12.5,
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: const Color(0xFF0284C7),
        size: 19,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      counterText: '',
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }

  // =========================================================================
  // SKELETON LOADER
  // =========================================================================
  Widget _buildSkeleton(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppShimmerBox.card(
          height: 195,
          borderRadius: 20,
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: AppShimmerBox.text(width: 160, height: 12),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              AppShimmerBox.text(width: double.infinity, height: 14),
              SizedBox(height: 12),
              AppShimmerBox.text(width: double.infinity, height: 14),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // ESTADO VACÍO (SIN PÓLIZA REGISTRADA)
  // =========================================================================
  Widget _buildEmptyState() {
    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        'este vehículo';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Color(0xFF0284C7),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin Póliza de Seguro Registrada',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No se encontró ningún registro de seguro automotriz vigente para $plates.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            if (_canCreate) ...[
              const SizedBox(height: 24),
              LoadingActionButton(
                text: 'Registrar Seguro',
                icon: Icons.add_circle_outline_rounded,
                isLoading: false,
                height: 46,
                borderRadius: 14,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onPressed: _startCreating,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // DIÁLOGO DE CONFIRMACIÓN DE ELIMINACIÓN
  // =========================================================================
  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text(
                'Eliminar Póliza',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: const Text(
            '¿Estás seguro de que deseas eliminar este registro de póliza de seguro?',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteInsurance();
              },
              child: const Text(
                'Eliminar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteInsurance() async {
    try {
      final seguros = ref.read(insuranceProvider).insurances;
      if (seguros.isEmpty) {
        SnackbarTop.showWarning(
          context,
          'No se encontraron pólizas para eliminar.',
        );
        return;
      }

      await VehiclesconService().eliminarSeguro(
        widget.vehicle['id'].toString(),
        widget.idMainAccount,
      );

      // Notificación de eliminación
      try {
        const nameNotice = 'vehicle_insurance_deleted';
        final noticeTemplate =
            await NotificationService().getNoticeByName(nameNotice);

        if (noticeTemplate != null) {
          final vehiclePlates = widget.vehicle['placas']?.toString() ??
              widget.vehicle['plate']?.toString() ??
              '';

          final title = (noticeTemplate['title']?.toString() ?? '')
              .replaceAll('{vehicle_plate}', vehiclePlates);

          final finalMessage =
              '$title|Póliza de seguro eliminada|${noticeTemplate['icon'] ?? ''}';

          await NotificationService().insertNotification({
            'typeSource': _typeSource,
            'idOrigin': seguros.first.id,
            'typEvent': 3,
            'date': DateTime.now().toIso8601String(),
            'message': finalMessage,
            'colNotice': 'insurance_Delete',
            'idMainAcoount': widget.idMainAccount,
            'codUsGenerator': widget.userId,
            'idDev': widget.userId,
          });
        }
      } catch (notifErr) {
        debugPrint(
            'Error al enviar notificación de eliminación de seguro: $notifErr');
      }

      if (mounted) {
        SnackbarTop.showSuccess(
          context,
          'Póliza de seguro eliminada correctamente.',
        );
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        SnackbarTop.showError(
          context,
          'Error al eliminar la póliza de seguro. Inténtalo de nuevo.',
        );
      }
    }
  }
}
