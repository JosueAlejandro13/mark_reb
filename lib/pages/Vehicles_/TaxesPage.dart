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

import 'package:mark_v3/models/Vehicles_/tax_model.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/Error_/unexpectedErrorPage.dart';
import 'package:mark_v3/providers/Vehicles_/tax_provider.dart';
import 'package:mark_v3/services/ConnectionNotification_/NotificationCon_service.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/apple_detail_row.dart';
import 'package:mark_v3/widgets/apple_empty_state.dart';
import 'package:mark_v3/widgets/apple_group_card.dart';
import 'package:mark_v3/widgets/apple_section_title.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/doc_foto_widget.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

// Autor: Josue Hernandez
class TaxesPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> vehicle;
  final String taxesPermission;
  final String circulationCardPermission;
  final String idMainAccount;
  final String userId;

  const TaxesPage({
    super.key,
    required this.circulationCardPermission,
    required this.vehicle,
    required this.taxesPermission,
    required this.idMainAccount,
    required this.userId,
  });

  @override
  ConsumerState<TaxesPage> createState() => _TaxesPageState();
}

class _TaxesPageState extends ConsumerState<TaxesPage> {
  String _typeSource = '';
  bool _isDisposed = false;
  bool _isEditing = false;
  bool _isLoading = false;
  int? _editingTaxId;

  final _formKey = GlobalKey<FormState>();
  final _yearController = TextEditingController();
  final _paymentDateController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _tenancyController = TextEditingController();
  final _renewalController = TextEditingController();

  DateTime? _selectedPaymentDate;
  DateTime? _selectedExpiryDate;

  // Fotografías del comprobante fiscal y estado de OCR
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
    Future.microtask(() => _refreshData());
  }

  @override
  void dispose() {
    _isDisposed = true;
    _yearController.dispose();
    _paymentDateController.dispose();
    _expiryDateController.dispose();
    _tenancyController.dispose();
    _renewalController.dispose();
    super.dispose();
  }

  Future<void> _fetchTypeSource() async {
    if (_isDisposed || !mounted) return;
    try {
      final Map<String, dynamic> data =
          await NotificationService().gettypSource('vehic_taxs');
      if (!_isDisposed && mounted && data.containsKey('id')) {
        setState(() {
          _typeSource = data['id'].toString();
        });
      }
    } catch (e) {
      debugPrint('Error al obtener typeSource: $e');
    }
  }

  Future<void> _refreshData() async {
    if (_isDisposed || !mounted) return;
    await ref.read(taxProvider.notifier).loadTaxes(
          vehicleId: widget.vehicle['id'].toString(),
          userId: widget.idMainAccount.toString(),
        );
  }

  // --- PERMISOS BITWISE Y FLOTA ---
  bool get _canEdit =>
      MarkApiClient.instance.flota.can('tenencia', 'editar') ||
      ((int.tryParse(widget.taxesPermission) ?? 0) & 8 == 8);

  bool get _canDelete => false;

  bool get _canCreate =>
      MarkApiClient.instance.flota.can('tenencia', 'crear') ||
      ((int.tryParse(widget.taxesPermission) ?? 0) & 4 == 4);

  bool get _isChofer {
    final session = MarkApiClient.instance.currentSession;
    final rol = (session?.rol ?? '').trim().toLowerCase();
    return rol == 'chofer' || (session?.isChofer ?? false);
  }

  bool get _canSeeCostos => !_isChofer;

  // --- FORMATO DE FECHAS SEGURO ---
  String _formatDisplayDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is DateTime) {
      return DateFormat('dd / MM / yyyy').format(date);
    }
    final str = date.toString().trim();
    if (str.isEmpty) return 'N/A';

    try {
      DateTime parsed = DateFormat('yyyy-MM-dd').parse(str);
      return DateFormat('dd / MM / yyyy').format(parsed);
    } catch (_) {}

    try {
      DateTime parsed = DateFormat('dd/MM/yyyy').parse(str);
      return DateFormat('dd / MM / yyyy').format(parsed);
    } catch (_) {}

    try {
      DateTime parsed = DateTime.parse(str);
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

  // =========================================================================
  // CAPTURA Y ESCANEO OCR DE COMPROBANTES FISCALES
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
        'Comprobante escaneado con éxito. Revisa los datos detectados.',
      );
    } catch (e) {
      debugPrint('Error en OCR de tenencia vehicular: $e');
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
                    ? 'Capturar Comprobante Fiscal'
                    : 'Capturar Respaldo / Sello Digital',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isFront
                    ? 'El frente se escaneará con IA para autocompletar ejercicio, fechas e importes.'
                    : 'Adjunta una fotografía de respaldo o detalle complementario.',
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

  // --- MOTOR HEURÍSTICO OCR PARA COMPROBANTES DE TENENCIA Y REFRENDO ---
  void _applyOcrResults(RecognizedText recognizedText) {
    final fullText = recognizedText.text;

    // 1. Extraer Año / Ejercicio Fiscal
    _extractYearFromOcr(fullText, recognizedText);

    // 2. Extraer Fecha de Pago
    final detectedPago = _extractDateByKeywords(
      fullText,
      recognizedText,
      [
        'FECHA DE PAGO',
        'FECHA PAGO',
        'PAGADO EL',
        'FECHA DE EMISION',
        'FECHA EMISION',
        'FECHA DE OPERACION',
        'FECHA DE APLICACION',
        'PAGO',
        'FECHA',
      ],
    );
    if (detectedPago != null) {
      setState(() {
        _selectedPaymentDate = detectedPago;
        _paymentDateController.text =
            DateFormat('dd / MM / yyyy').format(detectedPago);

        if (_selectedExpiryDate == null) {
          final nextYear = DateTime(detectedPago.year + 1, 3, 31);
          _selectedExpiryDate = nextYear;
          _expiryDateController.text =
              DateFormat('dd / MM / yyyy').format(nextYear);
        }
      });
    }

    // 3. Extraer Fecha de Expiración / Vigencia
    final detectedExpiry = _extractDateByKeywords(
      fullText,
      recognizedText,
      [
        'FECHA DE VENCIMIENTO',
        'FECHA LIMITE',
        'VENCIMIENTO',
        'VIGENCIA HASTA',
        'VIGENCIA',
        'VENCE',
        'HASTA',
      ],
    );
    if (detectedExpiry != null) {
      setState(() {
        _selectedExpiryDate = detectedExpiry;
        _expiryDateController.text =
            DateFormat('dd / MM / yyyy').format(detectedExpiry);
      });
    }

    // 4. Extraer Desglose de Montos (Tenencia y Refrendo)
    _extractAmountsFromOcr(fullText, recognizedText);
  }

  void _extractYearFromOcr(String fullText, RecognizedText recognizedText) {
    final yearRegex = RegExp(
      r'(?:EJERCICIO|PERIODO|AÑO|A\u00D1O|FISCAL)\s*[:.\-]?\s*(20[1-3][0-9])',
      caseSensitive: false,
    );
    final match = yearRegex.firstMatch(fullText);
    if (match != null) {
      final y = match.group(1);
      if (y != null && y.isNotEmpty) {
        setState(() => _yearController.text = y);
        return;
      }
    }

    // Búsqueda en bloques de texto
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final upper = line.text.toUpperCase();
        if (upper.contains('EJERCICIO') ||
            upper.contains('TENENCIA') ||
            upper.contains('REFRENDO') ||
            upper.contains('PERIODO')) {
          final m4 = RegExp(r'\b(20[1-3][0-9])\b').firstMatch(line.text);
          if (m4 != null) {
            setState(() => _yearController.text = m4.group(1)!);
            return;
          }
        }
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

  void _extractAmountsFromOcr(String fullText, RecognizedText recognizedText) {
    final currencyRegex =
        RegExp(r'\$?\s*([0-9]{1,4}(?:[,\.][0-9]{2,3})*(?:\.[0-9]{2}))');

    double? foundTenancy;
    double? foundRenewal;

    for (final block in recognizedText.blocks) {
      for (int i = 0; i < block.lines.length; i++) {
        final lineText = block.lines[i].text.toUpperCase();

        if (foundTenancy == null &&
            (lineText.contains('TENENCIA') || lineText.contains('USO DE VEHICULOS')) &&
            !lineText.contains('SUBSIDIO') &&
            !lineText.contains('TOTAL')) {
          final m = currencyRegex.firstMatch(block.lines[i].text);
          if (m != null) {
            final val = double.tryParse(m.group(1)!.replaceAll(',', ''));
            if (val != null && val >= 0) foundTenancy = val;
          } else if (i + 1 < block.lines.length) {
            final mNext = currencyRegex.firstMatch(block.lines[i + 1].text);
            if (mNext != null) {
              final val = double.tryParse(mNext.group(1)!.replaceAll(',', ''));
              if (val != null && val >= 0) foundTenancy = val;
            }
          }
        }

        if (foundRenewal == null &&
            (lineText.contains('REFRENDO') ||
                lineText.contains('DERECHO') ||
                lineText.contains('CONTROL VEHICULAR')) &&
            !lineText.contains('TOTAL')) {
          final m = currencyRegex.firstMatch(block.lines[i].text);
          if (m != null) {
            final val = double.tryParse(m.group(1)!.replaceAll(',', ''));
            if (val != null && val >= 0) foundRenewal = val;
          } else if (i + 1 < block.lines.length) {
            final mNext = currencyRegex.firstMatch(block.lines[i + 1].text);
            if (mNext != null) {
              final val = double.tryParse(mNext.group(1)!.replaceAll(',', ''));
              if (val != null && val >= 0) foundRenewal = val;
            }
          }
        }
      }
    }

    setState(() {
      if (foundTenancy != null) {
        _tenancyController.text = foundTenancy.toStringAsFixed(2);
      }
      if (foundRenewal != null) {
        _renewalController.text = foundRenewal.toStringAsFixed(2);
      }
    });
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

  void _startEditing(TaxModel impuesto) {
    setState(() {
      _isEditing = true;
      _editingTaxId = impuesto.id;
      _yearController.text = impuesto.year;
      _selectedPaymentDate = _parseDateSafe(impuesto.fechaPago);
      _paymentDateController.text = _selectedPaymentDate != null
          ? DateFormat('dd / MM / yyyy').format(_selectedPaymentDate!)
          : (impuesto.fechaPago.isNotEmpty ? impuesto.fechaPago : '');
      _selectedExpiryDate = _parseDateSafe(impuesto.fechaExpiracion);
      _expiryDateController.text = _selectedExpiryDate != null
          ? DateFormat('dd / MM / yyyy').format(_selectedExpiryDate!)
          : (impuesto.fechaExpiracion.isNotEmpty ? impuesto.fechaExpiracion : '');
      _tenancyController.text = impuesto.montoTenencia;
      _renewalController.text = impuesto.montoRefrendo;
      _frontImage = null;
      _backImage = null;
    });
  }

  void _startCreating() {
    setState(() {
      _isEditing = true;
      _editingTaxId = null;
      _yearController.text = DateTime.now().year.toString();
      _selectedPaymentDate = DateTime.now();
      _paymentDateController.text =
          DateFormat('dd / MM / yyyy').format(DateTime.now());
      _selectedExpiryDate = DateTime(DateTime.now().year, 12, 31);
      _expiryDateController.text =
          DateFormat('dd / MM / yyyy').format(_selectedExpiryDate!);
      _tenancyController.text = '0.00';
      _renewalController.text = '0.00';
      _frontImage = null;
      _backImage = null;
    });
  }

  // =========================================================================
  // SUBMIT FORMULARIO (CREAR O ACTUALIZAR)
  // =========================================================================
  Future<void> _submitForm({required bool isEditing}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedPaymentDate == null) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona la fecha de pago.',
      );
      return;
    }

    if (_selectedExpiryDate == null) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona la fecha de expiración.',
      );
      return;
    }

    if (_selectedPaymentDate!.isAfter(_selectedExpiryDate!)) {
      SnackbarTop.showInfo(
        context,
        'La fecha de pago no puede ser posterior a la fecha de expiración.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final int year =
        int.tryParse(_yearController.text.trim()) ?? DateTime.now().year;
    final String formattedPaymentDate =
        DateFormat('yyyy-MM-dd').format(_selectedPaymentDate!);
    final String formattedExpiryDate =
        DateFormat('yyyy-MM-dd').format(_selectedExpiryDate!);
    final double tenancyAmount =
        double.tryParse(_tenancyController.text.trim()) ?? 0.0;
    final double renewalAmount =
        double.tryParse(_renewalController.text.trim()) ?? 0.0;

    final vehicleId = widget.vehicle['id'].toString();
    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        '';

    try {
      // 1. Subir fotografías a la API si se capturaron
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
        // --- ACTUALIZACIÓN DE IMPUESTO ---
        await VehiclesconService().actualizarImpuesto(
          vehicleId,
          widget.idMainAccount,
          year,
          formattedPaymentDate,
          formattedExpiryDate,
          tenancyAmount,
          renewalAmount,
          fotos: photoUuids,
        );

        // Notificación de actualización
        try {
          const nameNotice = 'vehicle_tax_payment_updated';
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
                .replaceAll('{tax_period}', year.toString())
                .replaceAll('{vehicle_plate}', plates)
                .replaceAll('{payment_date}', _paymentDateController.text)
                .replaceAll('{due_date}', _expiryDateController.text);

            final title = (noticeTemplate['title']?.toString() ?? '')
                .replaceAll('{vehicle_plate}', plates);

            final finalMessage =
                '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

            final currentTaxes = ref.read(taxProvider).taxes;
            final int idImpuesto =
                currentTaxes.isNotEmpty ? currentTaxes.first.id : (_editingTaxId ?? 0);

            await NotificationService().insertNotification({
              'typeSource': _typeSource,
              'idOrigin': idImpuesto,
              'typEvent': 2,
              'date': DateTime.now().toIso8601String(),
              'message': finalMessage,
              'colNotice': 'tax_Edit',
              'idMainAcoount': widget.idMainAccount,
              'codUsGenerator': widget.userId,
              'idDev': widget.userId,
            });
          }
        } catch (notifErr) {
          debugPrint('Error en notificación de actualización de impuesto: $notifErr');
        }

        // Actualizar control de gestión
        await VehiclesconService().updateManagementControlTax(
          widget.idMainAccount,
          vehicleId,
          formattedExpiryDate,
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
            'Impuesto actualizado exitosamente.',
          );
          _refreshData();
        }
      } else {
        // --- CREACIÓN DE IMPUESTO ---
        final int idImpuesto = await VehiclesconService().crearImpuesto(
          vehicleId,
          widget.idMainAccount,
          year,
          formattedPaymentDate,
          formattedExpiryDate,
          tenancyAmount,
          renewalAmount,
          fotos: photoUuids,
        );

        // Notificación de nuevo impuesto
        try {
          const nameNotice = 'vehicle_tax_payment_added';
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
                .replaceAll('{tax_period}', year.toString())
                .replaceAll('{vehicle_plate}', plates)
                .replaceAll('{payment_date}', _paymentDateController.text)
                .replaceAll('{due_date}', _expiryDateController.text);

            final title = (noticeTemplate['title']?.toString() ?? '')
                .replaceAll('{vehicle_plate}', plates);

            final finalMessage =
                '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

            await NotificationService().insertNotification({
              'typeSource': _typeSource,
              'idOrigin': idImpuesto,
              'typEvent': 1,
              'date': DateTime.now().toIso8601String(),
              'message': finalMessage,
              'colNotice': 'tax_New',
              'idMainAcoount': widget.idMainAccount,
              'codUsGenerator': widget.userId,
              'idDev': widget.userId,
            });
          }
        } catch (notifErr) {
          debugPrint('Error en notificación de creación de impuesto: $notifErr');
        }

        // Insertar control de gestión
        await VehiclesconService().insertManagementControlTax(
          widget.idMainAccount,
          vehicleId,
          _selectedExpiryDate!,
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
            'Impuesto registrado exitosamente.',
          );
          _refreshData();
        }
      }
    } catch (e) {
      debugPrint('Error al guardar impuesto: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        SnackbarTop.showError(
          context,
          isEditing
              ? 'Error al actualizar el impuesto. Intente nuevamente.'
              : 'Error al registrar el impuesto. Intente nuevamente.',
        );
      }
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

    final taxState = ref.watch(taxProvider);

    if (taxState.isConnectionError) {
      return ConnectionErrorPage(onRetry: _refreshData);
    }
    if (taxState.isServerError) {
      return ServerErrorPage(onRetry: _refreshData);
    }
    if (taxState.isUnexpectedError) {
      return Unexpectederrorpage(onRetry: _refreshData);
    }

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
                  _buildHeader(context, taxState),
                  const SizedBox(height: 12),
                  if (_isEditing)
                    _buildFormSection(isSmallScreen)
                  else
                    Builder(
                      builder: (context) {
                        if (taxState.isLoading) {
                          return _buildSkeleton(isSmallScreen);
                        } else if (taxState.taxes.isEmpty) {
                          return _buildEmptyState();
                        } else {
                          final impuesto = taxState.taxes.first;
                          return _buildTaxDetails(impuesto);
                        }
                      },
                    ),
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
  Widget _buildHeader(BuildContext context, TaxState taxState) {
    final make = widget.vehicle['make']?.toString() ?? '';
    final model = widget.vehicle['model']?.toString() ?? '';
    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        'Sin Placas';

    final subtitle = (make.isNotEmpty || model.isNotEmpty)
        ? '$make $model · Placas: $plates'
        : 'Placas: $plates';

    final headerTitle = _isEditing
        ? (_editingTaxId != null ? 'Editar Impuesto' : 'Registrar Impuesto')
        : 'Impuestos Vehiculares';

    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (_isEditing) {
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
                headerTitle,
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
        const SizedBox(width: 8),
        if (!_isEditing) _buildHeaderActionMenu(context, taxState),
      ],
    );
  }

  Widget _buildHeaderActionMenu(BuildContext context, TaxState taxState) {
    final List<PopupMenuEntry<String>> menuItems = [];
    final bool hasTaxes = taxState.taxes.isNotEmpty;

    if (hasTaxes && _canEdit) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'edit',
          title: 'Editar Impuesto',
          icon: Icons.edit_rounded,
          iconColor: const Color(0xFF0284C7),
        ),
      );
    }

    if (hasTaxes && _canDelete) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'delete',
          title: 'Eliminar Impuesto',
          icon: Icons.delete_outline_rounded,
          iconColor: const Color(0xFFEF4444),
          textColor: const Color(0xFFEF4444),
        ),
      );
    }

    if (!hasTaxes && _canCreate) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'create',
          title: 'Registrar Impuesto',
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
        tooltip: 'Opciones de impuesto',
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
            _startEditing(taxState.taxes.first);
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

  // =========================================================================
  // SKELETON APPLE DE CARGA
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
          child: AppShimmerBox.text(width: 150, height: 12),
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
            children: [
              Row(
                children: const [
                  AppShimmerBox(width: 36, height: 36, borderRadius: 10),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppShimmerBox.text(width: 140, height: 14),
                        SizedBox(height: 6),
                        AppShimmerBox.text(width: 210, height: 11),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const AppShimmerBox(
                width: double.infinity,
                height: 48,
                borderRadius: 12,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: AppShimmerBox.text(width: 170, height: 12),
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
            children: const [
              AppShimmerBox.text(width: double.infinity, height: 14),
              SizedBox(height: 12),
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
  // ESTADO VACÍO (SIN IMPUESTOS REGISTRADOS)
  // =========================================================================
  Widget _buildEmptyState() {
    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        'este vehículo';

    return AppleEmptyState(
      icon: Icons.receipt_long_rounded,
      title: 'Sin Impuestos Registrados',
      description:
          'No se encontraron pagos fiscales (tenencia o refrendo) registrados para $plates.',
      action: _canCreate
          ? LoadingActionButton(
              text: 'Registrar Impuesto',
              icon: Icons.add_circle_outline_rounded,
              isLoading: false,
              height: 46,
              borderRadius: 14,
              onPressed: _startCreating,
            )
          : null,
    );
  }

  // =========================================================================
  // DETALLES DEL IMPUESTO (APPLE WALLET HERO CARD + SECCIONES)
  // =========================================================================
  Widget _buildTaxDetails(TaxModel impuesto) {
    final year = impuesto.year.isNotEmpty ? impuesto.year : '----';
    final fechaPagoStr = _formatDisplayDate(impuesto.fechaPago);
    final fechaExpiracionStr = _formatDisplayDate(impuesto.fechaExpiracion);

    final montoTenencia = double.tryParse(impuesto.montoTenencia) ?? 0.0;
    final montoRefrendo = double.tryParse(impuesto.montoRefrendo) ?? 0.0;
    final montoTotal = impuesto.totalMonto;

    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        'OFICIAL';

    final parsedExpiry = _parseDateSafe(impuesto.fechaExpiracion);

    int daysRemaining = 0;
    bool isExpired = false;
    bool isToday = false;
    bool isClose = false;

    Color badgeBg;
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (parsedExpiry == null) {
      badgeBg = const Color(0xFF0284C7).withOpacity(0.2);
      badgeColor = const Color(0xFF38BDF8);
      badgeText = 'REGISTRADO';
      badgeIcon = Icons.verified_rounded;
    } else {
      daysRemaining = _calculateDaysDifference(parsedExpiry);
      if (daysRemaining < 0) {
        isExpired = true;
        badgeBg = const Color(0xFFEF4444).withOpacity(0.25);
        badgeColor = const Color(0xFFFCA5A5);
        badgeText = 'VENCIDO';
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
        badgeIcon = Icons.verified_rounded;
      }
    }

    final List<int> fotoIds = [];
    for (final f in impuesto.fotos) {
      int? p;
      if (f is int) {
        p = f;
      } else if (f is Map && f['id'] != null) {
        p = int.tryParse(f['id'].toString());
      } else {
        p = int.tryParse(f.toString());
      }
      if (p != null && !fotoIds.contains(p)) {
        fotoIds.add(p);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. HERO CARD ESTILO APPLE WALLET
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0F172A),
                Color(0xFF1E293B),
                Color(0xFF0369A1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // Patrón sutil de fondo
                Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04),
                    ),
                  ),
                ),
                Positioned(
                  left: -40,
                  bottom: -40,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF38BDF8).withOpacity(0.08),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fila Superior: Marca y Placas
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
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'TENENCIA Y REFRENDO',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white.withOpacity(0.95),
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                      Text(
                                        'CONTROL FISCAL · MARK FLEET',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withOpacity(0.65),
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
                                  color: Color(0xFF38BDF8),
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

                      // Fila Central: Ejercicio Fiscal + Monto Total
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
                                        Icons.calendar_month_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'AÑO $year',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tenencia y Refrendo Vehicular',
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
                          if (_canSeeCostos) ...[
                            const SizedBox(width: 12),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'MONTO TOTAL',
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
                                      _currencyFormat.format(montoTotal),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Fila Inferior: Fechas y Badge de Estatus
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'VENCE',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.65),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  fechaExpiracionStr,
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

        // 2. SECCIÓN: ESTATUS FISCAL Y VIGENCIA
        _buildSectionTitle('ESTATUS FISCAL Y VIGENCIA'),
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
                              : Icons.verified_rounded),
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
                            ? 'Impuesto Fiscal Vencido'
                            : (isToday
                                ? 'Vence el Día de Hoy'
                                : (isClose
                                    ? 'Próximo a Vencer'
                                    : 'Al Corriente y Vigente')),
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
                            ? 'Venció hace ${-daysRemaining} días. Se requiere regularización.'
                            : (isToday
                                ? 'La vigencia fiscal termina hoy a las 23:59 hrs.'
                                : (isClose
                                    ? 'Quedan $daysRemaining días antes del vencimiento del periodo.'
                                    : 'Quedan $daysRemaining días de vigencia en el periodo actual.')),
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
                              ? 'CONDICIÓN: REGISTRO CON REZAGO FISCAL'
                              : (isClose || isToday
                                  ? 'CONDICIÓN: REQUERIRÁ RENOVACIÓN PRONTA'
                                  : 'CONDICIÓN: SIN ADEUDOS FISCALES'),
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
                              ? 'Realiza el pago correspondiente para evitar multas de tránsito o recargos.'
                              : 'Comprobante válido para circulación y trámites vehiculares.',
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
        const SizedBox(height: 8),

        // 3. SECCIÓN: DESGLOSE ECONÓMICO Y PERIODOS
        _buildSectionTitle('DESGLOSE ECONÓMICO'),
        _buildAppleGroupContainer(
          children: [
            _buildDetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Ejercicio / Año Fiscal',
              value: year,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.event_available_rounded,
              label: 'Fecha de Pago',
              value: fechaPagoStr,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.event_busy_rounded,
              label: 'Fecha de Expiración',
              value: fechaExpiracionStr,
            ),
            if (_canSeeCostos) ...[
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _buildDetailRow(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Monto de Tenencia',
                value: _currencyFormat.format(montoTenencia),
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _buildDetailRow(
                icon: Icons.receipt_long_outlined,
                label: 'Monto de Refrendo',
                value: _currencyFormat.format(montoRefrendo),
              ),
              const Divider(height: 20, color: Color(0xFFE2E8F0)),
              _buildDetailRow(
                icon: Icons.monetization_on_outlined,
                label: 'Total Pagado',
                value: _currencyFormat.format(montoTotal),
                isHighlight: true,
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),

        // 4. FOTOGRAFÍAS REGISTRADAS DEL COMPROBANTE FISCAL
        if (fotoIds.isNotEmpty) ...[
          _buildSectionTitle('FOTOGRAFÍAS DEL COMPROBANTE'),
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

  // =========================================================================
  // VISTA DE FORMULARIO DE PÁGINA COMPLETA ESTILO APPLE
  // =========================================================================
  Widget _buildFormSection(bool isSmallScreen) {
    final isEditing = _editingTaxId != null;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. CARDS DE CAPTURA DE FOTOS ESTILO APPLE (FRENTE Y REVERSO)
          _buildSectionTitle('COMPROBANTE FISCAL'),
          _buildAppleGroupContainer(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildPhotoBox(
                      title: 'Comprobante Frente',
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
                      title: 'Comprobante Reverso',
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
                        'El escaneo con IA extraerá automáticamente el ejercicio, fechas e importes de tenencia y refrendo. Podrás revisar o editar cualquier dato antes de guardar.',
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

          // 2. DATOS DEL IMPUESTO
          _buildSectionTitle('DATOS DEL IMPUESTO FISCAL'),
          _buildAppleGroupContainer(
            children: [
              // Ejercicio Fiscal
              _buildFieldLabel('Año / Ejercicio Fiscal *'),
              TextFormField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
                decoration: _buildInputDecoration(
                  hint: 'ej. ${DateTime.now().year}',
                  prefixIcon: Icons.calendar_month_rounded,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Ingresa el año del ejercicio.';
                  }
                  if (v.trim().length != 4) {
                    return 'Debe ser un año de 4 dígitos.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Fechas (Pago y Expiración)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Fecha de Pago *'),
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            _selectDate(
                              context,
                              title: 'Fecha de Pago',
                              initialDate: _selectedPaymentDate,
                              onDateSelected: (date) {
                                setState(() {
                                  _selectedPaymentDate = date;
                                  _paymentDateController.text =
                                      DateFormat('dd / MM / yyyy')
                                          .format(date);

                                  if (_selectedExpiryDate == null) {
                                    final nextYear =
                                        DateTime(date.year + 1, 3, 31);
                                    _selectedExpiryDate = nextYear;
                                    _expiryDateController.text =
                                        DateFormat('dd / MM / yyyy')
                                            .format(nextYear);
                                  }
                                });
                              },
                            );
                          },
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: _paymentDateController,
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
                        _buildFieldLabel('Fecha de Expiración *'),
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            _selectDate(
                              context,
                              title: 'Fecha de Expiración',
                              initialDate: _selectedExpiryDate,
                              onDateSelected: (date) {
                                setState(() {
                                  _selectedExpiryDate = date;
                                  _expiryDateController.text =
                                      DateFormat('dd / MM / yyyy')
                                          .format(date);
                                });
                              },
                            );
                          },
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: _expiryDateController,
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

              // Montos (Tenencia y Refrendo)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Monto Tenencia (MXN)'),
                        TextFormField(
                          controller: _tenancyController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'),
                            ),
                          ],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          decoration: _buildInputDecoration(
                            hint: '0.00',
                            prefixIcon: Icons.attach_money_rounded,
                          ),
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty) {
                              final p = double.tryParse(v);
                              if (p == null || p < 0) {
                                return 'Monto inválido.';
                              }
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
                        _buildFieldLabel('Monto Refrendo (MXN)'),
                        TextFormField(
                          controller: _renewalController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'),
                            ),
                          ],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          decoration: _buildInputDecoration(
                            hint: '0.00',
                            prefixIcon: Icons.attach_money_rounded,
                          ),
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty) {
                              final p = double.tryParse(v);
                              if (p == null || p < 0) {
                                return 'Monto inválido.';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
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
                  text: isEditing ? 'Guardar Cambios' : 'Registrar Impuesto',
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
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isOcrFront
                                    ? const Color(0xFFE0F2FE)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isOcrFront
                                    ? Icons.document_scanner_rounded
                                    : Icons.add_a_photo_rounded,
                                color: isOcrFront
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF64748B),
                                size: 19,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isOcrFront ? 'Toca para escanear' : 'Toca para agregar',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF64748B),
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

  // --- FILA DE DETALLE ESTILO CUPERTINO/APPLE ---
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

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
          letterSpacing: 0.2,
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
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      prefixIcon: Icon(
        prefixIcon,
        color: const Color(0xFF0284C7),
        size: 18,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

  // --- TÍTULO DE SECCIÓN INSET GROUPED ---
  Widget _buildSectionTitle(String title) {
    return AppleSectionTitle(title);
  }

  Widget _buildAppleGroupContainer({required List<Widget> children}) {
    return AppleGroupCard(children: children);
  }

  // =========================================================================
  // DIÁLOGO DE CONFIRMACIÓN DE ELIMINACIÓN ESTILO APPLE
  // =========================================================================
  void _showDeleteConfirmationDialog() {
    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        'este vehículo';

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isDeleting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.delete_forever_rounded,
                        color: Color(0xFFEF4444),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '¿Eliminar Registro Fiscal?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Se borrarán los impuestos registrados para las placas $plates. Esta acción no se puede deshacer.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: isDeleting
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LoadingActionButton(
                            text: 'Eliminar',
                            isLoading: isDeleting,
                            height: 44,
                            borderRadius: 14,
                            backgroundColor: const Color(0xFFEF4444),
                            onPressed: () async {
                              setDialogState(() {
                                isDeleting = true;
                              });
                              await _performDeleteTax(dialogContext);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _performDeleteTax(BuildContext dialogContext) async {
    try {
      final impuestos = ref.read(taxProvider).taxes;

      if (impuestos.isEmpty) {
        if (mounted) {
          Navigator.of(dialogContext).pop();
          SnackbarTop.showInfo(
            context,
            'No se encontraron impuestos para eliminar.',
          );
        }
        return;
      }

      final int idImpuesto = impuestos.first.id;
      final String year =
          impuestos.first.year.isNotEmpty ? impuestos.first.year : '';
      final String paymentD =
          impuestos.first.fechaPago.isNotEmpty ? impuestos.first.fechaPago : '';
      final String expiryD = impuestos.first.fechaExpiracion.isNotEmpty
          ? impuestos.first.fechaExpiracion
          : '';

      // 1. Eliminar impuesto en backend
      await VehiclesconService().eliminarImpuestosPorVehiculo(
        widget.vehicle['id'].toString(),
        widget.idMainAccount.toString(),
      );

      // 2. Notificación en segundo plano
      try {
        const nameNotice = 'vehicle_tax_payment_deleted';
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
              .replaceAll('{tax_period}', year)
              .replaceAll('{vehicle_plate}', vehiclePlates)
              .replaceAll('{payment_date}', paymentD)
              .replaceAll('{due_date}', expiryD);

          final title = (noticeTemplate['title']?.toString() ?? '')
              .replaceAll('{vehicle_plate}', vehiclePlates);

          final finalMessage =
              '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

          await NotificationService().insertNotification({
            'typeSource': _typeSource,
            'idOrigin': idImpuesto,
            'typEvent': 3,
            'date': DateTime.now().toIso8601String(),
            'message': finalMessage,
            'colNotice': 'tax_Delete',
            'idMainAcoount': widget.idMainAccount.toString(),
            'codUsGenerator': widget.userId.toString(),
            'idDev': widget.userId.toString(),
          });
        }
      } catch (notifErr) {
        debugPrint('Error al enviar notificación de eliminación: $notifErr');
      }

      // 3. Borrar control de gestión
      await VehiclesconService().deleteManagementControlTax(
        widget.idMainAccount.toString(),
        widget.vehicle['id'].toString(),
      );

      if (mounted) {
        Navigator.of(dialogContext).pop();
        _refreshData();
        SnackbarTop.showSuccess(
          context,
          'Impuesto eliminado exitosamente.',
        );
      }
    } catch (e) {
      debugPrint('Error al eliminar impuestos: $e');
      if (mounted) {
        Navigator.of(dialogContext).pop();
        SnackbarTop.showError(
          context,
          'Error al eliminar el impuesto. Intente nuevamente.',
        );
      }
    }
  }
}
