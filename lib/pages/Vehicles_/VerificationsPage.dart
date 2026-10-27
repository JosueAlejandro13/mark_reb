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

import 'package:mark_v3/models/Vehicles_/verification_model.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/Error_/unexpectedErrorPage.dart';
import 'package:mark_v3/providers/Vehicles_/verification_provider.dart';
import 'package:mark_v3/services/ConnectionNotification_/NotificationCon_service.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/doc_foto_widget.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

// Autor: Josue Hernandez
class VerificationsPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> vehicle;
  final String verificationsPermission;
  final String idMainAccount;
  final String userId;

  const VerificationsPage({
    super.key,
    required this.vehicle,
    required this.verificationsPermission,
    required this.idMainAccount,
    required this.userId,
  });

  @override
  ConsumerState<VerificationsPage> createState() => _VerificationsPageState();
}

class _VerificationsPageState extends ConsumerState<VerificationsPage> {
  String _typeSource = '';
  bool _isDisposed = false;
  bool _isEditing = false;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  final _fechaVerificacionController = TextEditingController();
  final _proximaVerificController = TextEditingController();

  String? _selectedHologramId;
  DateTime? _selectedFechaVerificacion;
  DateTime? _selectedProximaVerific;

  // Fotografías del certificado y estado de OCR
  File? _frontImage;
  File? _backImage;
  bool _isScanningOcr = false;

  late Future<List<Map<String, dynamic>>> _hologramasFuture;
  List<Map<String, dynamic>> _hologramas = [];

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _hologramasFuture = VehiclesconService().obtenerHolograma();
    _hologramasFuture.then((list) {
      if (!_isDisposed && mounted) {
        setState(() {
          _hologramas = list;
          final vers = ref.read(verificationProvider).verifications;
          if (vers.isNotEmpty && _isEditing && _selectedHologramId != null) {
            final resolved = _resolveHologramId(list, _selectedHologramId!);
            if (resolved != null) _selectedHologramId = resolved;
          }
        });
      }
    });
    _fetchTypeSource();
    Future.microtask(() => _refreshData());
  }

  Future<void> _fetchTypeSource() async {
    if (_isDisposed || !mounted) return;
    try {
      final Map<String, dynamic> data =
          await NotificationService().gettypSource('vehic_verification');
      if (!_isDisposed && mounted && data.containsKey('id')) {
        setState(() {
          _typeSource = data['id'].toString();
        });
      }
    } catch (e) {
      debugPrint('Error al obtener typeSource de verificación: $e');
    }
  }

  Future<void> _refreshData() async {
    if (_isDisposed || !mounted) return;
    await ref.read(verificationProvider.notifier).loadVerifications(
          vehicleId: widget.vehicle['id'].toString(),
          userId: widget.idMainAccount.toString(),
        );
  }

  // --- PERMISOS BITWISE Y FLOTA ---
  bool get _canEdit =>
      MarkApiClient.instance.flota.can('verificacion', 'editar') ||
      ((int.tryParse(widget.verificationsPermission) ?? 0) & 8 == 8);

  bool get _canDelete => false;

  bool get _canCreate =>
      MarkApiClient.instance.flota.can('verificacion', 'crear') ||
      ((int.tryParse(widget.verificationsPermission) ?? 0) & 4 == 4);

  // --- FORMATEO Y PARSEO DE FECHAS SEGURO ---
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

  @override
  void dispose() {
    _isDisposed = true;
    _montoController.dispose();
    _fechaVerificacionController.dispose();
    _proximaVerificController.dispose();
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
        'Certificado escaneado. Revisa y confirma los campos detectados.',
      );
    } catch (e) {
      debugPrint('Error en OCR de verificación vehicular: $e');
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
                    ? 'Capturar Certificado de Verificación'
                    : 'Capturar Holograma / Respaldo',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isFront
                    ? 'El frente se escaneará con IA para autocompletar holograma y fechas.'
                    : 'Adjunta una fotografía de respaldo opcional.',
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

  // --- MOTOR HEURÍSTICO OCR PARA VERIFICACIÓN VEHICULAR ---
  void _applyOcrResults(RecognizedText recognizedText) {
    final fullText = recognizedText.text;

    // 1. Extraer Holograma (00, 0, 1, 2, Exento)
    _extractHologramFromOcr(fullText);

    // 2. Extraer Fecha de Verificación
    final detectedFecha = _extractDateByKeywords(
      fullText,
      recognizedText,
      [
        'FECHA DE VERIFICACION',
        'FECHA DE EMISION',
        'FECHA DE PRUEBA',
        'FECHA VERIF',
        'EMISION',
        'FECHA'
      ],
    );
    if (detectedFecha != null) {
      setState(() {
        _selectedFechaVerificacion = detectedFecha;
        _fechaVerificacionController.text =
            DateFormat('dd / MM / yyyy').format(detectedFecha);

        // Si no se tiene próxima verificación, calcular automáticamente 6 meses después
        if (_selectedProximaVerific == null) {
          final nextDate = DateTime(
            detectedFecha.year,
            detectedFecha.month + 6,
            detectedFecha.day,
          );
          _selectedProximaVerific = nextDate;
          _proximaVerificController.text =
              DateFormat('dd / MM / yyyy').format(nextDate);
        }
      });
    }

    // 3. Extraer Próxima Verificación / Vigencia
    final detectedProx = _extractDateByKeywords(
      fullText,
      recognizedText,
      [
        'PROXIMA VERIFICACION',
        'PROXIMA',
        'VIGENCIA',
        'VENCE',
        'HASTA',
        'VENCIMIENTO'
      ],
    );
    if (detectedProx != null) {
      setState(() {
        _selectedProximaVerific = detectedProx;
        _proximaVerificController.text =
            DateFormat('dd / MM / yyyy').format(detectedProx);
      });
    }

    // 4. Extraer Monto / Derechos
    final detectedMonto = _extractMonto(fullText);
    if (detectedMonto != null && _montoController.text.trim().isEmpty) {
      _montoController.text = detectedMonto.toStringAsFixed(2);
    }
  }

  void _extractHologramFromOcr(String fullText) {
    final upper = fullText.toUpperCase();
    if (_hologramas.isEmpty) return;

    for (final h in _hologramas) {
      final name = (h['nombre'] ?? h['name'] ?? h['hologram'] ?? '').toString().toUpperCase();
      final id = (h['id'] ?? '').toString();

      if (name.contains('00') || name.contains('DOBLE CERO')) {
        if (upper.contains('DOBLE CERO') ||
            upper.contains('00') ||
            upper.contains('HOLOGRAMA 00') ||
            upper.contains('TIPO 00')) {
          setState(() => _selectedHologramId = id);
          return;
        }
      } else if (name.contains('EXENTO')) {
        if (upper.contains('EXENTO')) {
          setState(() => _selectedHologramId = id);
          return;
        }
      } else if (name.contains('CERO') || name == '0') {
        if (upper.contains('HOLOGRAMA 0') ||
            upper.contains('TIPO 0') ||
            upper.contains('CERO') ||
            RegExp(r'\b0\b').hasMatch(upper)) {
          setState(() => _selectedHologramId = id);
          return;
        }
      } else if (name.contains('1') || name.contains('UNO')) {
        if (upper.contains('HOLOGRAMA 1') ||
            upper.contains('TIPO 1') ||
            upper.contains('UNO') ||
            RegExp(r'\b1\b').hasMatch(upper)) {
          setState(() => _selectedHologramId = id);
          return;
        }
      } else if (name.contains('2') || name.contains('DOS')) {
        if (upper.contains('HOLOGRAMA 2') ||
            upper.contains('TIPO 2') ||
            upper.contains('DOS') ||
            RegExp(r'\b2\b').hasMatch(upper)) {
          setState(() => _selectedHologramId = id);
          return;
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

  double? _extractMonto(String fullText) {
    final regex = RegExp(
      r'(?:TOTAL|IMPORTE|MONTO|COSTO|DERECHOS|\$)\s*[:.\-]?\s*\$?\s*([0-9]{1,4}(?:[,\.][0-9]{2,3})*(?:\.[0-9]{2})?)',
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

    if (_selectedHologramId == null || _selectedHologramId!.isEmpty) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona un holograma.',
      );
      return;
    }

    if (_selectedFechaVerificacion == null) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona la fecha de realización de la verificación.',
      );
      return;
    }

    if (_selectedProximaVerific == null) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona la fecha de próxima verificación.',
      );
      return;
    }

    if (_selectedFechaVerificacion!.isAfter(_selectedProximaVerific!)) {
      SnackbarTop.showInfo(
        context,
        'La fecha de verificación no puede ser posterior a la próxima verificación.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String formattedFechaVerificacion =
        DateFormat('yyyy-MM-dd').format(_selectedFechaVerificacion!);
    final String formattedProximaVerific =
        DateFormat('yyyy-MM-dd').format(_selectedProximaVerific!);
    final double monto = double.tryParse(_montoController.text.trim()) ?? 0.0;

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
        // --- ACTUALIZACIÓN DE VERIFICACIÓN ---
        await VehiclesconService().actualizarVerificacionPorVehiculo(
          vehicleId,
          widget.idMainAccount,
          _selectedHologramId!,
          formattedFechaVerificacion,
          formattedProximaVerific,
          monto,
          status: 'Activo',
          fotos: photoUuids,
        );

        // Notificación de actualización
        try {
          const nameNotice = 'vehicle_verification_updated';
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
                .replaceAll('{verification_date}', formattedFechaVerificacion)
                .replaceAll('{due_date}', formattedProximaVerific);

            final title = (noticeTemplate['title']?.toString() ?? '')
                .replaceAll('{vehicle_plate}', plates);

            final finalMessage =
                '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

            final currentVerifs =
                ref.read(verificationProvider).verifications;
            final int idverificacion =
                currentVerifs.isNotEmpty ? currentVerifs.first.id : 0;

            await NotificationService().insertNotification({
              'typeSource': _typeSource,
              'idOrigin': idverificacion,
              'typEvent': 2,
              'date': DateTime.now().toIso8601String(),
              'message': finalMessage,
              'colNotice': 'verific_Edit',
              'idMainAcoount': widget.idMainAccount,
              'codUsGenerator': widget.userId,
              'idDev': widget.userId,
            });
          }
        } catch (notifErr) {
          debugPrint(
              'Error en notificación de actualización de verificación: $notifErr');
        }

        // Actualizar control de gestión
        await VehiclesconService().updateManagementControlVf(
          widget.idMainAccount,
          vehicleId,
          formattedProximaVerific,
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
            'Verificación actualizada exitosamente.',
          );
          _refreshData();
        }
      } else {
        // --- CREACIÓN DE VERIFICACIÓN ---
        final int idverificacion = await VehiclesconService().crearVerificacion(
          vehicleId,
          _selectedHologramId!,
          widget.idMainAccount,
          formattedFechaVerificacion,
          formattedProximaVerific,
          monto,
          '1',
          fotos: photoUuids,
        );

        // Notificación de nueva verificación
        try {
          const nameNotice = 'vehicle_verification_added';
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
                .replaceAll('{verification_date}', formattedFechaVerificacion)
                .replaceAll('{due_date}', formattedProximaVerific);

            final title = (noticeTemplate['title']?.toString() ?? '')
                .replaceAll('{vehicle_plate}', plates);

            final finalMessage =
                '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

            await NotificationService().insertNotification({
              'typeSource': _typeSource,
              'idOrigin': idverificacion,
              'typEvent': 1,
              'date': DateTime.now().toIso8601String(),
              'message': finalMessage,
              'colNotice': 'verific_New',
              'idMainAcoount': widget.idMainAccount,
              'codUsGenerator': widget.userId,
              'idDev': widget.userId,
            });
          }
        } catch (notifErr) {
          debugPrint(
              'Error en notificación de creación de verificación: $notifErr');
        }

        // Insertar control de gestión
        await VehiclesconService().insertManagementControlVf(
          widget.idMainAccount,
          vehicleId,
          _selectedProximaVerific!,
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
            'Verificación registrada correctamente.',
          );
          _refreshData();
        }
      }
    } catch (e) {
      debugPrint('Error al guardar verificación: $e');
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
    final verifState = ref.watch(verificationProvider);

    if (verifState.isConnectionError) {
      return ConnectionErrorPage(onRetry: _refreshData);
    }
    if (verifState.isServerError) {
      return ServerErrorPage(onRetry: _refreshData);
    }
    if (verifState.isUnexpectedError) {
      return Unexpectederrorpage(onRetry: _refreshData);
    }

    final hasVerification = verifState.verifications.isNotEmpty;

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
                  _buildHeader(context, hasVerification: hasVerification),
                  const SizedBox(height: 12),
                  if (verifState.isLoading)
                    _buildSkeleton(isSmallScreen)
                  else if (_isEditing)
                    _buildFormSection(isEditing: hasVerification)
                  else if (!hasVerification)
                    _buildEmptyState()
                  else
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _hologramasFuture,
                      builder: (context, snapshot) {
                        final hologramas = snapshot.data ?? _hologramas;
                        return _buildVerificationDetails(
                            verifState.verifications.first, hologramas);
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
  Widget _buildHeader(BuildContext context,
      {required bool hasVerification}) {
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
              if (_isEditing && hasVerification) {
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
                    ? (hasVerification
                        ? 'Editar Verificación'
                        : 'Registrar Verificación')
                    : 'Verificación Vehicular',
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
    final hasVerification =
        ref.watch(verificationProvider).verifications.isNotEmpty;

    if (hasVerification && _canEdit) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'edit',
          title: 'Editar Verificación',
          icon: Icons.edit_rounded,
          iconColor: const Color(0xFF0284C7),
        ),
      );
    }

    if (hasVerification && _canDelete) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'delete',
          title: 'Eliminar Verificación',
          icon: Icons.delete_outline_rounded,
          iconColor: const Color(0xFFEF4444),
          textColor: const Color(0xFFEF4444),
        ),
      );
    }

    if (!hasVerification && _canCreate) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'create',
          title: 'Registrar Verificación',
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
        tooltip: 'Opciones de verificación',
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
            final verifs = ref.read(verificationProvider).verifications;
            if (verifs.isNotEmpty) {
              _startEditing(verifs.first);
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

  String? _resolveHologramId(List<Map<String, dynamic>> list, String val) {
    if (val.trim().isEmpty || list.isEmpty) return null;
    final cleanVal = val.trim().toLowerCase();
    for (final item in list) {
      final id = item['id']?.toString().trim().toLowerCase();
      final name = (item['nombre'] ?? item['name'] ?? item['hologram'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (id == cleanVal || name == cleanVal) {
        return item['id']?.toString();
      }
    }
    return null;
  }

  void _startEditing(VerificationModel verificacion) {
    setState(() {
      _isEditing = true;
      _selectedHologramId = _resolveHologramId(_hologramas, verificacion.idHolograma) ??
          verificacion.idHolograma;
      _selectedFechaVerificacion =
          _parseDateSafe(verificacion.fecVerificacion);
      _fechaVerificacionController.text = _selectedFechaVerificacion != null
          ? DateFormat('dd / MM / yyyy').format(_selectedFechaVerificacion!)
          : '';
      _selectedProximaVerific = _parseDateSafe(verificacion.proximaVerific);
      _proximaVerificController.text = _selectedProximaVerific != null
          ? DateFormat('dd / MM / yyyy').format(_selectedProximaVerific!)
          : '';
      _montoController.text = verificacion.monto;
      _frontImage = null;
      _backImage = null;
    });
  }

  void _startCreating() {
    setState(() {
      _isEditing = true;
      _selectedHologramId = null;
      _selectedFechaVerificacion = null;
      _selectedProximaVerific = null;
      _fechaVerificacionController.clear();
      _proximaVerificController.clear();
      _montoController.text = '0.00';
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
          // 1. FOTOGRAFÍAS DE LA VERIFICACIÓN
          _buildSectionTitle(
              'FOTOGRAFÍAS DEL CERTIFICADO DE VERIFICACIÓN'),
          _buildAppleGroupContainer(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildPhotoBox(
                      title: 'Certificado / Holograma',
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
                        'El escaneo con IA detectará automáticamente el tipo de holograma y fechas del certificado. Podrás revisar o editar la información antes de guardar.',
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

          // 2. DATOS DE LA VERIFICACIÓN
          _buildSectionTitle('DATOS DE LA VERIFICACIÓN'),
          _buildAppleGroupContainer(
            children: [
              // Holograma Ambiental Dropdown
              _buildFieldLabel('Holograma Ambiental *'),
              _buildHologramDropdown(),
              const SizedBox(height: 14),

              // Fechas (Realización y Próxima Verificación)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Fecha de Realización *'),
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            _selectDate(
                              context,
                              title: 'Fecha de Realización',
                              initialDate: _selectedFechaVerificacion,
                              onDateSelected: (date) {
                                setState(() {
                                  _selectedFechaVerificacion = date;
                                  _fechaVerificacionController.text =
                                      DateFormat('dd / MM / yyyy')
                                          .format(date);

                                  if (_selectedProximaVerific == null) {
                                    final nextDate = DateTime(
                                      date.year,
                                      date.month + 6,
                                      date.day,
                                    );
                                    _selectedProximaVerific = nextDate;
                                    _proximaVerificController.text =
                                        DateFormat('dd / MM / yyyy')
                                            .format(nextDate);
                                  }
                                });
                              },
                            );
                          },
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: _fechaVerificacionController,
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
                        _buildFieldLabel('Próxima Verificación *'),
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            _selectDate(
                              context,
                              title: 'Próxima Verificación',
                              initialDate: _selectedProximaVerific,
                              onDateSelected: (date) {
                                setState(() {
                                  _selectedProximaVerific = date;
                                  _proximaVerificController.text =
                                      DateFormat('dd / MM / yyyy')
                                          .format(date);
                                });
                              },
                            );
                          },
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: _proximaVerificController,
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

              // Monto Pagado / Costo
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
                    return 'Ingresa el monto pagado.';
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
                  text: isEditing
                      ? 'Guardar Cambios'
                      : 'Registrar Verificación',
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

  Widget _buildHologramDropdown() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _hologramasFuture,
      builder: (context, snapshot) {
        final list = snapshot.data ?? _hologramas;

        if (list.isEmpty) {
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
                  'Cargando hologramas disponibles...',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          );
        }

        final bool hasValidHologram = _selectedHologramId != null &&
            list.any((h) => h['id']?.toString() == _selectedHologramId);
        final String? effectiveHologram =
            hasValidHologram ? _selectedHologramId : null;

        return DropdownButtonFormField2<String>(
          value: effectiveHologram,
          isExpanded: true,
          decoration: _buildInputDecoration(
            hint: 'Selecciona el holograma',
            prefixIcon: Icons.local_activity_rounded,
          ),
          items: list.map((holograma) {
            final rawName = (holograma['nombre'] ??
                    holograma['name'] ??
                    holograma['hologram'] ??
                    '')
                .toString()
                .trim();
            final name = rawName.isNotEmpty ? rawName : 'Holograma';
            return DropdownMenuItem<String>(
              value: holograma['id']?.toString(),
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
              _selectedHologramId = value;
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
      },
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
                                  ? 'Escanear Certificado'
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
  // DETALLES DE LA VERIFICACIÓN (HERO CARD COLOR EMERALD / ECO APPLE WALLET)
  // =========================================================================
  Widget _buildVerificationDetails(
      VerificationModel verificacion, List<Map<String, dynamic>> hologramas) {
    String hologramName = verificacion.idHolograma.toString();
    if (hologramas.isNotEmpty) {
      final cleanH = verificacion.idHolograma.toString().trim().toLowerCase();
      for (final h in hologramas) {
        final id = h['id']?.toString().trim().toLowerCase();
        final name = (h['nombre'] ?? h['name'] ?? h['hologram'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (id == cleanH || name == cleanH) {
          final n =
              (h['nombre'] ?? h['name'] ?? h['hologram'])?.toString().trim();
          if (n != null && n.isNotEmpty) hologramName = n;
          break;
        }
      }
    }
    final hologram =
        hologramName.trim().isNotEmpty ? hologramName : 'Sin Holograma';
    final fechaVerificacionStr =
        _formatDisplayDate(verificacion.fecVerificacion);
    final proximaVerificStr =
        _formatDisplayDate(verificacion.proximaVerific);
    final monto = double.tryParse(verificacion.monto) ?? 0.0;

    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        'OFICIAL';

    final parsedExpiry = _parseDateSafe(verificacion.proximaVerific);

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
      badgeColor = const Color(0xFF34D399);
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
    for (final f in verificacion.fotos) {
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
        // 1. TARJETA DIGITAL APPLE WALLET HERO (DEEP JADE & EMERALD)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF022C22),
                Color(0xFF064E3B),
                Color(0xFF059669),
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
                color: const Color(0xFF022C22).withOpacity(0.35),
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
                                    Icons.eco_rounded,
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
                                        'VERIFICACIÓN VEHICULAR',
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
                                        'CONTROL DE EMISIONES Y MEDIO AMBIENTE',
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
                                  color: Color(0xFF6EE7B7),
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
                                  'TIPO DE HOLOGRAMA',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withOpacity(0.65),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hologram,
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
                                    'REALIZACIÓN',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withOpacity(0.55),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    fechaVerificacionStr,
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
                                      'PRÓXIMA',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withOpacity(0.55),
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      proximaVerificStr,
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
                                      'COSTO',
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

        // 2. SECCIÓN: ESTATUS & VIGENCIA AMBIENTAL
        _buildSectionTitle('ESTATUS & VIGENCIA AMBIENTAL'),
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
                          parsedExpiry == null
                              ? 'Verificación Registrada'
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
                          'Próxima fecha límite: $proximaVerificStr',
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
                              ? 'TRÁMITE DE VERIFICACIÓN URGENTE'
                              : (isClose || isToday
                                  ? 'PERIODO DE VERIFICACIÓN PRÓXIMO'
                                  : 'VEHÍCULO AL CORRIENTE EN EMISIONES'),
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
                              ? 'Presenta el vehículo a verificación ambiental para evitar multas de tránsito y restricciones de circulación.'
                              : 'Holograma oficial vigente que autoriza la libre circulación de la unidad.',
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

        // 3. SECCIÓN: DATOS DE LA VERIFICACIÓN
        _buildSectionTitle('DATOS DE LA VERIFICACIÓN'),
        _buildAppleGroupContainer(
          children: [
            _buildDetailRow(
              icon: Icons.local_activity_rounded,
              label: 'Holograma Asignado',
              value: hologram,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.event_available_rounded,
              label: 'Fecha Realizada',
              value: fechaVerificacionStr,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.event_busy_rounded,
              label: 'Próxima Verificación',
              value: proximaVerificStr,
            ),
            const Divider(height: 20, color: Color(0xFFE2E8F0)),
            _buildDetailRow(
              icon: Icons.attach_money_rounded,
              label: 'Costo / Derechos',
              value: _currencyFormat.format(monto),
              isHighlight: true,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 4. FOTOGRAFÍAS REGISTRADAS DE LA VERIFICACIÓN (SI EXISTEN)
        if (fotoIds.isNotEmpty) ...[
          _buildSectionTitle('FOTOGRAFÍAS DE LA VERIFICACIÓN'),
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
  // ESTADO VACÍO (SIN VERIFICACIONES REGISTRADAS)
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
                Icons.eco_rounded,
                color: Color(0xFF0284C7),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin Verificaciones Registradas',
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
              'No se encontró ningún registro oficial de verificación vehicular para $plates.',
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
                text: 'Registrar Verificación',
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
                'Eliminar Verificación',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: const Text(
            '¿Estás seguro de que deseas eliminar este registro de verificación vehicular?',
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
                _deleteVerification();
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

  Future<void> _deleteVerification() async {
    try {
      final verificaciones =
          ref.read(verificationProvider).verifications;
      if (verificaciones.isEmpty) {
        SnackbarTop.showWarning(
          context,
          'No se encontraron verificaciones para eliminar.',
        );
        return;
      }

      final int idverificacion = verificaciones.first.id;
      final String fecVerificacion = verificaciones.first.fecVerificacion;
      final String proximaVerific = verificaciones.first.proximaVerific;

      await VehiclesconService().eliminarVerificacionesPorVehiculo(
        widget.vehicle['id'].toString(),
        widget.idMainAccount,
      );

      // Notificación de eliminación
      try {
        const nameNotice = 'vehicle_verification_deleted';
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
              .replaceAll('{verification_date}', fecVerificacion)
              .replaceAll('{due_date}', proximaVerific);

          final title = (noticeTemplate['title']?.toString() ?? '')
              .replaceAll('{vehicle_plate}', vehiclePlates);

          final finalMessage =
              '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

          await NotificationService().insertNotification({
            'typeSource': _typeSource,
            'idOrigin': idverificacion,
            'typEvent': 3,
            'date': DateTime.now().toIso8601String(),
            'message': finalMessage,
            'colNotice': 'verific_Delete',
            'idMainAcoount': widget.idMainAccount,
            'codUsGenerator': widget.userId,
            'idDev': widget.userId,
          });
        }
      } catch (notifErr) {
        debugPrint(
            'Error al enviar notificación de eliminación de verificación: $notifErr');
      }

      if (mounted) {
        SnackbarTop.showSuccess(
          context,
          'Verificación vehicular eliminada correctamente.',
        );
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        SnackbarTop.showError(
          context,
          'Error al eliminar la verificación vehicular. Inténtalo de nuevo.',
        );
      }
    }
  }
}
