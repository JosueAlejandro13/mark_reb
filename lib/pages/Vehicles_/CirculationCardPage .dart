import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:mark_v3/models/Vehicles_/circulation_card_model.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/Error_/unexpectedErrorPage.dart';
import 'package:mark_v3/providers/Vehicles_/circulation_card_provider.dart';
import 'package:mark_v3/services/ConnectionNotification_/NotificationCon_service.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/doc_foto_widget.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

// Autor: Josue Hernandez
class CirculationCardPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> vehicle;
  final String circulationCardPermission;
  final String idMainAccount;
  final String userId;

  const CirculationCardPage({
    super.key,
    required this.vehicle,
    required this.circulationCardPermission,
    required this.idMainAccount,
    required this.userId,
  });

  @override
  ConsumerState<CirculationCardPage> createState() =>
      _CirculationCardPageState();
}

class _CirculationCardPageState extends ConsumerState<CirculationCardPage> {
  String _typeSource = '';
  bool _isDisposed = false;
  bool _isEditing = false;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final _numTarjetaController = TextEditingController();
  final _fecExpedicionController = TextEditingController();
  final _fecVencimientoController = TextEditingController();
  final _montoController = TextEditingController();

  DateTime? _selectedFechaExpedicion;
  DateTime? _selectedFechaVencimiento;

  // Fotografías de la credencial y estado de OCR
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
    _fetchTypeSource();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCirculationCard();
    });
  }

  void _loadCirculationCard() {
    ref.read(circulationCardProvider.notifier).fetchCards(
          widget.vehicle['id'].toString(),
          widget.idMainAccount.toString(),
        );
  }

  Future<void> _fetchTypeSource() async {
    if (_isDisposed || !mounted) return;
    try {
      final Map<String, dynamic> data =
          await NotificationService().gettypSource('vehic_circulationCard');
      if (!_isDisposed && mounted && data.containsKey('id')) {
        setState(() {
          _typeSource = data['id'].toString();
        });
      }
    } catch (e) {
      debugPrint('Error al obtener typeSource de tarjeta de circulación: $e');
    }
  }

  Future<void> _refreshData() async {
    if (_isDisposed || !mounted) return;
    _loadCirculationCard();
  }

  // --- PERMISOS BITWISE Y FLOTA ---
  bool get _canEdit =>
      MarkApiClient.instance.flota.can('tarjeta', 'editar') ||
      ((int.tryParse(widget.circulationCardPermission) ?? 0) & 8 == 8);

  bool get _canDelete => false;

  bool get _canCreate =>
      MarkApiClient.instance.flota.can('tarjeta', 'crear') ||
      ((int.tryParse(widget.circulationCardPermission) ?? 0) & 4 == 4);

  // --- FORMATEO Y PARSEO DE FECHAS ---
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
    _numTarjetaController.dispose();
    _fecExpedicionController.dispose();
    _fecVencimientoController.dispose();
    _montoController.dispose();
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
        'Frente procesado. Revisa y confirma los campos detectados.',
      );
    } catch (e) {
      debugPrint('Error en OCR de tarjeta de circulación: $e');
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
                    ? 'Capturar Frente de Tarjeta'
                    : 'Capturar Reverso de Tarjeta',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isFront
                    ? 'El frente se escaneará con IA para autocompletar el folio y fechas.'
                    : 'Adjunta el reverso para tener respaldo completo del documento.',
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

  // --- MOTOR HEURÍSTICO OCR PARA TARJETA DE CIRCULACIÓN ---
  void _applyOcrResults(RecognizedText recognizedText) {
    final fullText = recognizedText.text;

    // 1. Extraer Folio / Número de Tarjeta
    final detectedFolio = _extractCirculationNumber(fullText, recognizedText);
    if (detectedFolio != null && detectedFolio.isNotEmpty) {
      _numTarjetaController.text = detectedFolio;
    }

    // 2. Extraer Fecha de Expedición
    final detectedExp = _extractDateByKeywords(
      fullText,
      recognizedText,
      ['EXPEDICION', 'EMISION', 'EXPEDIDA', 'FECHA EXP', 'FECHA DE EXP'],
    );
    if (detectedExp != null) {
      setState(() {
        _selectedFechaExpedicion = detectedExp;
        _fecExpedicionController.text =
            DateFormat('dd / MM / yyyy').format(detectedExp);
      });
    }

    // 3. Extraer Fecha de Vencimiento / Vigencia
    final detectedVen = _extractDateByKeywords(
      fullText,
      recognizedText,
      ['VIGENCIA', 'VENCE', 'VENCIMIENTO', 'HASTA', 'EXPIRA', 'FECHA VENC'],
    );
    if (detectedVen != null) {
      setState(() {
        _selectedFechaVencimiento = detectedVen;
        _fecVencimientoController.text =
            DateFormat('dd / MM / yyyy').format(detectedVen);
      });
    } else {
      final upper = fullText.toUpperCase();
      if (upper.contains('PERMANENTE') ||
          upper.contains('INDEFINIDA') ||
          upper.contains('INDETERMINAD')) {
        setState(() {
          _selectedFechaVencimiento = DateTime(2099, 12, 31);
          _fecVencimientoController.text =
              DateFormat('dd / MM / yyyy').format(_selectedFechaVencimiento!);
        });
      }
    }

    // 4. Extraer Monto / Derechos
    final detectedMonto = _extractMonto(fullText);
    if (detectedMonto != null && _montoController.text.trim().isEmpty) {
      _montoController.text = detectedMonto.toStringAsFixed(2);
    }
  }

  String? _extractCirculationNumber(
      String fullText, RecognizedText recognizedText) {
    final upperFull = fullText.toUpperCase();

    // Heurística A: Patrón con palabra clave
    final keywordRegex = RegExp(
      r'(?:FOLIO(?:\s*NO\.?|\s*DE\s*TARJETA|\s*TARJETA)?|NO\.?\s*DE\s*TARJETA|TARJETA(?:\s*NO\.?)?|CONTROL|NO\.)\s*[:.\-]?\s*([A-Z0-9\-]{5,18})',
      caseSensitive: false,
    );
    for (final m in keywordRegex.allMatches(fullText)) {
      final cand = m.group(1)!
          .replaceAll(' ', '')
          .replaceAll('-', '')
          .toUpperCase();
      if (_isValidCirculationNumber(cand)) {
        return cand;
      }
    }

    // Heurística B: Bloques adyacentes a palabras clave FOLIO o TARJETA
    for (final block in recognizedText.blocks) {
      for (int i = 0; i < block.lines.length; i++) {
        final lineRaw = block.lines[i].text.toUpperCase();
        if (lineRaw.contains('FOLIO') ||
            lineRaw.contains('TARJETA') ||
            lineRaw.contains('NO. CONTROL')) {
          if (i + 1 < block.lines.length) {
            final nextClean = block.lines[i + 1].text
                .toUpperCase()
                .replaceAll(' ', '')
                .replaceAll('-', '');
            if (_isValidCirculationNumber(nextClean)) {
              return nextClean;
            }
          }
        }

        final lineClean = lineRaw.replaceAll(' ', '').replaceAll('-', '');
        if (_isValidCirculationNumber(lineClean)) {
          return lineClean;
        }
      }
    }

    // Heurística C: Formato estándar común en México (TC seguido de números o 7 a 12 dígitos)
    final standardRegex = RegExp(r'\b(TC\s*\d{6,10}|\d{7,12})\b');
    final match = standardRegex.firstMatch(upperFull);
    if (match != null) {
      final cand = match.group(1)!.replaceAll(' ', '');
      if (_isValidCirculationNumber(cand)) {
        return cand;
      }
    }

    return null;
  }

  bool _isValidCirculationNumber(String cand) {
    if (cand.length < 5 || cand.length > 20) return false;
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
      'PAGO'
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

  double? _extractMonto(String fullText) {
    final regex = RegExp(
      r'(?:TOTAL|IMPORTE|MONTO|DERECHOS|\$)\s*[:.\-]?\s*\$?\s*([0-9]{1,4}(?:[,\.][0-9]{2,3})*(?:\.[0-9]{2})?)',
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

    if (_selectedFechaExpedicion == null) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona la fecha de expedición.',
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

    if (_selectedFechaExpedicion!.isAfter(_selectedFechaVencimiento!)) {
      SnackbarTop.showInfo(
        context,
        'La fecha de expedición no puede ser posterior a la fecha de vencimiento.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String numTarjeta = _numTarjetaController.text.trim();
    final double monto = double.tryParse(_montoController.text.trim()) ?? 0.0;

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

      final int idVehic = int.parse(widget.vehicle['id'].toString());
      final int idUs = int.parse(widget.idMainAccount.toString());

      if (isEditing) {
        // --- ACTUALIZACIÓN DE TARJETA ---
        await VehiclesconService().actualizarTarjetaCirculacion(
          idVehic,
          idUs,
          numTarjeta,
          DateFormat('yyyy-MM-dd').format(_selectedFechaExpedicion!),
          DateFormat('yyyy-MM-dd').format(_selectedFechaVencimiento!),
          monto,
          fotos: photoUuids,
        );

        // Notificación de actualización
        try {
          final circu = await VehiclesconService().obtenerTarjetaCirculacion(
            widget.vehicle['id'].toString(),
            widget.idMainAccount.toString(),
          );

          if (circu != null && circu.isNotEmpty && circu['id'] != null) {
            final int idcircu = circu['id'] is int
                ? circu['id']
                : int.tryParse(circu['id'].toString()) ?? 0;
            const nameNotice = 'vehicle_registration_card_updated';
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

              final vehiclePlates = widget.vehicle['placas']?.toString() ??
                  widget.vehicle['plate']?.toString() ??
                  '';

              final formattedMessage = message
                  .replaceAll('{vehicle_plate}', vehiclePlates)
                  .replaceAll('{card_number}', numTarjeta)
                  .replaceAll(
                      '{issue_date}',
                      DateFormat('dd/MM/yyyy')
                          .format(_selectedFechaExpedicion!))
                  .replaceAll(
                      '{expiry_date}',
                      DateFormat('dd/MM/yyyy')
                          .format(_selectedFechaVencimiento!));

              final title = (noticeTemplate['title']?.toString() ?? '')
                  .replaceAll('{vehicle_plate}', vehiclePlates);

              final finalMessage =
                  '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

              await NotificationService().insertNotification({
                'typeSource': _typeSource,
                'idOrigin': idcircu,
                'typEvent': 2,
                'date': DateTime.now().toIso8601String(),
                'message': finalMessage,
                'colNotice': 'tc_Edit',
                'idMainAcoount': widget.idMainAccount.toString(),
                'codUsGenerator': widget.userId.toString(),
                'idDev': widget.userId.toString(),
              });
            }
          }
        } catch (notifErr) {
          debugPrint(
              'Error al enviar notificación de actualización: $notifErr');
        }

        // Actualizar control de gestión
        await VehiclesconService().updateManagementControlTJ(
          idUs,
          idVehic,
          DateFormat('yyyy-MM-dd').format(_selectedFechaVencimiento!),
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
            'Tarjeta de circulación actualizada exitosamente.',
          );
          _refreshData();
        }
      } else {
        // --- CREACIÓN DE NUEVA TARJETA ---
        final DateTime fechaExpUTC = _selectedFechaExpedicion!.toUtc();
        final DateTime fechaVenUTC = _selectedFechaVencimiento!.toUtc();

        await VehiclesconService().crearTarjetaCirculacion(
          widget.vehicle['id'].toString(),
          widget.idMainAccount.toString(),
          numTarjeta,
          fechaExpUTC,
          fechaVenUTC,
          monto,
          fotos: photoUuids,
        );

        // Notificación de creación
        try {
          final circu = await VehiclesconService().obtenerTarjetaCirculacion(
            widget.vehicle['id'].toString(),
            widget.idMainAccount.toString(),
          );

          if (circu != null && circu.isNotEmpty && circu['id'] != null) {
            final int idcircu = circu['id'] is int
                ? circu['id']
                : int.tryParse(circu['id'].toString()) ?? 0;
            const nameNotice = 'vehicle_registration_card_added';
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

              final vehiclePlates = widget.vehicle['placas']?.toString() ??
                  widget.vehicle['plate']?.toString() ??
                  '';

              final formattedMessage = message
                  .replaceAll('{vehicle_plate}', vehiclePlates)
                  .replaceAll('{card_number}', numTarjeta)
                  .replaceAll(
                      '{issue_date}',
                      DateFormat('dd/MM/yyyy')
                          .format(_selectedFechaExpedicion!))
                  .replaceAll(
                      '{expiry_date}',
                      DateFormat('dd/MM/yyyy')
                          .format(_selectedFechaVencimiento!));

              final title = (noticeTemplate['title']?.toString() ?? '')
                  .replaceAll('{vehicle_plate}', vehiclePlates);

              final finalMessage =
                  '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

              await NotificationService().insertNotification({
                'typeSource': _typeSource,
                'idOrigin': idcircu,
                'typEvent': 1,
                'date': DateTime.now().toIso8601String(),
                'message': finalMessage,
                'colNotice': 'tc_New',
                'idMainAcoount': widget.idMainAccount.toString(),
                'codUsGenerator': widget.userId.toString(),
                'idDev': widget.userId.toString(),
              });
            }
          }
        } catch (notifErr) {
          debugPrint('Error al enviar notificación de creación: $notifErr');
        }

        // Insertar control de gestión
        await VehiclesconService().insertManagementControlTJ(
          widget.idMainAccount.toString(),
          widget.vehicle['id'].toString(),
          fechaVenUTC,
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
            'Tarjeta de circulación creada exitosamente.',
          );
          _refreshData();
        }
      }
    } catch (e) {
      debugPrint('Error al guardar tarjeta de circulación: $e');
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
    final cardState = ref.watch(circulationCardProvider);

    if (cardState.isConnectionError) {
      return ConnectionErrorPage(onRetry: _refreshData);
    }
    if (cardState.isServerError) {
      return ServerErrorPage(onRetry: _refreshData);
    }
    if (cardState.isUnexpectedError) {
      return Unexpectederrorpage(onRetry: _refreshData);
    }

    final hasCard = cardState.cards.isNotEmpty;

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
                  _buildHeader(context, hasCard: hasCard),
                  const SizedBox(height: 12),
                  if (!_canEdit && !_canCreate && !hasCard)
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
                              'Modo solo lectura: Tu rol cuenta con permisos para consultar la tarjeta de circulación y sus vigencias, pero no para registrar o modificar datos.',
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
                  if (cardState.isLoading)
                    _buildSkeleton(isSmallScreen)
                  else if (_isEditing)
                    _buildFormSection(isEditing: hasCard)
                  else if (!hasCard)
                    _buildEmptyState()
                  else
                    _buildCardDetails(cardState.cards.first),
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
  Widget _buildHeader(BuildContext context, {required bool hasCard}) {
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
              if (_isEditing && hasCard) {
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
                    ? (hasCard
                        ? 'Editar Tarjeta'
                        : 'Registrar Tarjeta')
                    : 'Tarjeta de Circulación',
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
    final hasCirculationCard =
        ref.watch(circulationCardProvider).cards.isNotEmpty;

    if (hasCirculationCard && _canEdit) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'edit',
          title: 'Editar Tarjeta',
          icon: Icons.edit_rounded,
          iconColor: const Color(0xFF0284C7),
        ),
      );
    }

    if (hasCirculationCard && _canDelete) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'delete',
          title: 'Eliminar Tarjeta',
          icon: Icons.delete_outline_rounded,
          iconColor: const Color(0xFFEF4444),
          textColor: const Color(0xFFEF4444),
        ),
      );
    }

    if (!hasCirculationCard && _canCreate) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'create',
          title: 'Registrar Tarjeta',
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
        tooltip: 'Opciones de tarjeta',
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
            final cards = ref.read(circulationCardProvider).cards;
            if (cards.isNotEmpty) {
              _startEditing(cards.first);
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

  void _startEditing(CirculationCardModel tarjeta) {
    setState(() {
      _isEditing = true;
      _numTarjetaController.text = tarjeta.numTarjeta;
      _selectedFechaExpedicion = _parseDateSafe(tarjeta.fecExpedicion);
      _fecExpedicionController.text = _selectedFechaExpedicion != null
          ? DateFormat('dd / MM / yyyy').format(_selectedFechaExpedicion!)
          : '';
      _selectedFechaVencimiento = _parseDateSafe(tarjeta.fecVencimiento);
      _fecVencimientoController.text = _selectedFechaVencimiento != null
          ? DateFormat('dd / MM / yyyy').format(_selectedFechaVencimiento!)
          : '';
      _montoController.text = tarjeta.monto;
      _frontImage = null;
      _backImage = null;
    });
  }

  void _startCreating() {
    setState(() {
      _isEditing = true;
      _numTarjetaController.clear();
      _fecExpedicionController.clear();
      _fecVencimientoController.clear();
      _montoController.text = '0.00';
      _selectedFechaExpedicion = null;
      _selectedFechaVencimiento = null;
      _frontImage = null;
      _backImage = null;
    });
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
          // 1. FOTOGRAFÍAS DE LA TARJETA (FRENTE CON IA OCR Y REVERSO)
          _buildSectionTitle('FOTOGRAFÍAS DE LA TARJETA DE CIRCULACIÓN'),
          _buildAppleGroupContainer(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildPhotoBox(
                      title: 'Frente de la Tarjeta',
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
                      title: 'Reverso de la Tarjeta',
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
                        'El escaneo con IA completará automáticamente los campos detectados de la tarjeta. Podrás revisar o editar la información antes de guardar.',
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

          // 2. DATOS DEL DOCUMENTO
          _buildSectionTitle('DATOS DEL DOCUMENTO'),
          _buildAppleGroupContainer(
            children: [
              // Folio / Número de Tarjeta
              _buildFieldLabel('Número de Tarjeta / Folio *'),
              TextFormField(
                controller: _numTarjetaController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 25,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
                decoration: _buildInputDecoration(
                  hint: 'Ej. TC-94820194',
                  prefixIcon: Icons.badge_outlined,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Ingresa el número o folio de la tarjeta.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Fechas (Expedición y Vencimiento)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Fecha de Expedición *'),
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            _selectDate(
                              context,
                              title: 'Fecha de Expedición',
                              initialDate: _selectedFechaExpedicion,
                              onDateSelected: (date) {
                                setState(() {
                                  _selectedFechaExpedicion = date;
                                  _fecExpedicionController.text =
                                      DateFormat('dd / MM / yyyy')
                                          .format(date);
                                });
                              },
                            );
                          },
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: _fecExpedicionController,
                              readOnly: true,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                              decoration: _buildInputDecoration(
                                hint: 'dd / mm / aaaa',
                                prefixIcon: Icons.calendar_today_rounded,
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
                                  _fecVencimientoController.text =
                                      DateFormat('dd / MM / yyyy')
                                          .format(date);
                                });
                              },
                            );
                          },
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: _fecVencimientoController,
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
                ],
              ),
              const SizedBox(height: 14),

              // Monto Pagado / Derechos
              _buildFieldLabel('Monto Pagado / Derechos *'),
              TextFormField(
                controller: _montoController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
                    return 'Ingresa el monto de derechos.';
                  }
                  final parsed = double.tryParse(v);
                  if (parsed == null || parsed < 0) {
                    return 'Monto inválido.';
                  }
                  return null;
                },
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
                  text: isEditing ? 'Guardar Cambios' : 'Registrar Tarjeta',
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
                                  ? 'Escanear Frente'
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
  // DETALLES DE LA TARJETA (ESTILO APPLE HERO COLOR ESMERALDA / PETRÓLEO)
  // =========================================================================
  Widget _buildCardDetails(CirculationCardModel tarjeta) {
    final numTarjeta = tarjeta.numTarjeta.trim().isNotEmpty
        ? tarjeta.numTarjeta
        : 'Sin Folio';
    final fecExpStr = _formatDisplayDate(tarjeta.fecExpedicion);
    final fecVenStr = _formatDisplayDate(tarjeta.fecVencimiento);
    final monto = double.tryParse(tarjeta.monto) ?? 0.0;

    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        'OFICIAL';

    final parsedExpiry = _parseDateSafe(tarjeta.fecVencimiento);

    int daysRemaining = 0;
    bool isExpired = false;
    bool isToday = false;
    bool isClose = false;

    Color badgeBg;
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (parsedExpiry == null || parsedExpiry.year >= 2090) {
      badgeBg = const Color(0xFF042F2E).withOpacity(0.3);
      badgeColor = const Color(0xFF5EEAD4);
      badgeText = 'PERMANENTE';
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
    for (final f in tarjeta.fotos) {
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
        // 1. TARJETA DIGITAL APPLE WALLET HERO (PETROL TEAL GRADIENT)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF042F2E),
                Color(0xFF0F766E),
                Color(0xFF0D9488),
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
                color: const Color(0xFF042F2E).withOpacity(0.30),
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
                                    Icons.credit_card_rounded,
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
                                        'TARJETA DE CIRCULACIÓN',
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
                                        'REGISTRO VEHICULAR OFICIAL',
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
                                  color: Color(0xFF5EEAD4),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FOLIO DE TARJETA',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withOpacity(0.65),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  numTarjeta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.0,
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
                              borderRadius: BorderRadius.circular(10),
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
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'EXPEDICIÓN',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withOpacity(0.55),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    fecExpStr,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 24,
                              color: Colors.white.withOpacity(0.12),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'VENCIMIENTO',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withOpacity(0.55),
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      fecVenStr,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isExpired
                                            ? const Color(0xFFFCA5A5)
                                            : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 24,
                              color: Colors.white.withOpacity(0.12),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'DERECHOS',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withOpacity(0.55),
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _currencyFormat.format(monto),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFFDE047),
                                      ),
                                    ),
                                  ],
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
            ),
          ),
        ),
        const SizedBox(height: 18),

        // 2. SECCIÓN: ESTATUS & VIGENCIA OFICIAL
        _buildSectionTitle('ESTATUS & VIGENCIA OFICIAL'),
        _buildAppleGroupContainer(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isExpired
                          ? const Color(0xFFFEE2E2)
                          : (isClose || isToday
                              ? const Color(0xFFFFEDD5)
                              : const Color(0xFFDCFCE7)),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      badgeIcon,
                      color: isExpired
                          ? const Color(0xFFEF4444)
                          : (isClose || isToday
                              ? const Color(0xFFEA580C)
                              : const Color(0xFF10B981)),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parsedExpiry == null || parsedExpiry.year >= 2090
                              ? 'Tarjeta con Vigencia Permanente'
                              : (isExpired
                                  ? 'Vencida hace ${daysRemaining.abs()} días'
                                  : (isToday
                                      ? '¡Vence el día de hoy!'
                                      : 'Vigente · Vence en $daysRemaining días')),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isExpired
                                ? const Color(0xFFDC2626)
                                : (isClose || isToday
                                    ? const Color(0xFFC2410C)
                                    : const Color(0xFF0F172A)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Fecha registrada: $fecVenStr',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 22, color: Color(0xFFF1F5F9)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isExpired
                    ? const Color(0xFFFEF2F2)
                    : (isClose || isToday
                        ? const Color(0xFFFFF7ED)
                        : const Color(0xFFF0FDF4)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isExpired
                              ? 'TRÁMITE DE RENOVACIÓN URGENTE'
                              : (isClose || isToday
                                  ? 'RENOVACIÓN PRÓXIMA'
                                  : 'DOCUMENTO VIGENTE PARA CIRCULAR'),
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
                              ? 'Renueva el documento en la oficina de control vehicular para evitar remisiones al corralón.'
                              : 'Documento oficial indispensable para libre circulación y trámites vehiculares.',
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

        // 3. SECCIÓN: DETALLES DE LA TARJETA
        _buildSectionTitle('DATOS DE LA TARJETA'),
        _buildAppleGroupContainer(
          children: [
            _buildDetailRow(
              icon: Icons.credit_card_rounded,
              label: 'Número / Folio',
              value: numTarjeta,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Fecha de Expedición',
              value: fecExpStr,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.event_available_rounded,
              label: 'Fecha de Vencimiento',
              value: fecVenStr,
            ),
            const Divider(height: 20, color: Color(0xFFE2E8F0)),
            _buildDetailRow(
              icon: Icons.attach_money_rounded,
              label: 'Monto / Derechos',
              value: _currencyFormat.format(monto),
              isHighlight: true,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 4. FOTOGRAFÍAS REGISTRADAS DE LA TARJETA (SI EXISTEN)
        if (fotoIds.isNotEmpty) ...[
          _buildSectionTitle('FOTOGRAFÍAS DE LA TARJETA DE CIRCULACIÓN'),
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
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isHighlight
                ? const Color(0xFFCCFBF1)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isHighlight
                ? const Color(0xFF0F766E)
                : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
              color: isHighlight
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF475569),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 14.5 : 13,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            color: isHighlight
                ? const Color(0xFF0F766E)
                : const Color(0xFF0F172A),
            letterSpacing: isHighlight ? -0.2 : 0,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildAppleGroupContainer({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
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
  // ESTADO VACÍO (SIN TARJETA REGISTRADA)
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
                Icons.credit_card_rounded,
                color: Color(0xFF0284C7),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin Tarjeta de Circulación',
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
              'No se encontró ningún registro oficial de tarjeta de circulación para $plates.',
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
                text: 'Registrar Tarjeta',
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
                'Eliminar Tarjeta',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: const Text(
            '¿Estás seguro de que deseas eliminar este registro de tarjeta de circulación?',
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
                _deleteCirculationCard();
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

  Future<void> _deleteCirculationCard() async {
    try {
      await VehiclesconService().eliminarTarjetaCirculacion(
        widget.vehicle['id'].toString(),
        widget.idMainAccount.toString(),
      );
      if (mounted) {
        SnackbarTop.showSuccess(
          context,
          'Tarjeta de circulación eliminada con éxito.',
        );
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        SnackbarTop.showError(
          context,
          'Error al eliminar la tarjeta. Inténtalo de nuevo.',
        );
      }
    }
  }
}
