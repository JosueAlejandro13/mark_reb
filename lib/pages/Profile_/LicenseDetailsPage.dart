import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/services/ConnectionProfile_/ProfileCon_service.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/doc_foto_widget.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

// Autor: Josue Hernandez
class LicenseDetailsPage extends StatefulWidget {
  final String idCollaborator;

  const LicenseDetailsPage({super.key, required this.idCollaborator});

  @override
  State<LicenseDetailsPage> createState() => _LicenseDetailsPageState();
}

class _LicenseDetailsPageState extends State<LicenseDetailsPage> {
  late Future<Map<String, dynamic>?> licenseDataFuture;
  final _formKey = GlobalKey<FormState>();
  final _licNumController = TextEditingController();
  final _licClassController = TextEditingController();

  DateTime? dueDate;
  bool isPermanent = false;
  bool isLoading = false;
  bool _isEditing = false;
  Map<String, dynamic>? _lastFetchedData;

  // Fotos de la credencial y estado de OCR
  File? _frontImage;
  File? _backImage;
  bool _isScanningOcr = false;

  @override
  void initState() {
    super.initState();
    licenseDataFuture = fetchLicenseDataById(widget.idCollaborator);
  }

  @override
  void dispose() {
    _licNumController.dispose();
    _licClassController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (mounted) {
      setState(() {
        licenseDataFuture = fetchLicenseDataById(widget.idCollaborator);
      });
    }
  }

  Future<Map<String, dynamic>?> fetchLicenseDataById(
      String idCollaborator) async {
    try {
      final licenseData = await ProfileconService()
          .obtenerLicenciaPorColaborador(idCollaborator);

      if (licenseData.isEmpty) {
        return null;
      } else {
        return licenseData;
      }
    } on SocketException catch (_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ConnectionErrorPage(
              onRetry: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => widget),
                );
              },
            ),
          ),
        );
      }
      throw Exception('Error de conexión');
    } on TimeoutException catch (_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ServerErrorPage(
              onRetry: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => widget),
                );
              },
            ),
          ),
        );
      }
      throw Exception('Error de servidor (Timeout)');
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('no encontrada') || errStr.contains('not found')) {
        return null;
      }
      debugPrint('Error fetching license: $e');
      throw Exception('Error del servidor: $e');
    }
  }

  // --- OCR & FOTOS: SELECCIÓN Y PROCESAMIENTO ---
  Future<void> _pickAndScanFrontImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final imageFile = File(pickedFile.path);
      setState(() {
        _frontImage = imageFile;
        _isScanningOcr = true;
      });

      final inputImage = InputImage.fromFile(imageFile);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      _applyOcrResults(recognizedText);

      if (mounted) {
        setState(() {
          _isScanningOcr = false;
        });
        SnackbarTop.showSuccess(
          context,
          '¡Lectura completada! Confirma los datos extraídos.',
        );
      }
    } catch (e) {
      debugPrint('Error en OCR de licencia: $e');
      if (mounted) {
        setState(() {
          _isScanningOcr = false;
        });
        SnackbarTop.showInfo(
          context,
          'Foto capturada. Puedes completar o editar los campos manualmente.',
        );
      }
    }
  }

  Future<void> _pickBackImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFront ? 'Fotografía Frente (con OCR)' : 'Fotografía Reverso',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isFront
                    ? 'Captura el frente para autocompletar número, tipo y vigencia con IA.'
                    : 'Adjunta una fotografía clara del reverso de tu credencial.',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Color(0xFF0284C7)),
                ),
                title: const Text('Tomar Fotografía con la Cámara',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (isFront) {
                    _pickAndScanFrontImage(ImageSource.camera);
                  } else {
                    _pickBackImage(ImageSource.camera);
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded,
                      color: Color(0xFF475569)),
                ),
                title: const Text('Seleccionar de la Galería',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                onTap: () {
                  Navigator.pop(ctx);
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

  // --- MOTOR HEURÍSTICO MEJORADO DE EXTRACCIÓN OCR ---
  void _applyOcrResults(RecognizedText recognizedText) {
    final fullText = recognizedText.text;
    final upperFull = fullText.toUpperCase();

    // Advertir si el usuario escaneó el reverso en vez del frente
    if ((upperFull.contains('FOLIO DE PAGO') ||
            upperFull.contains('FIRMA') ||
            upperFull.contains('HUELLA')) &&
        !upperFull.contains('CURP') &&
        !upperFull.contains('NACIONALIDAD')) {
      SnackbarTop.showWarning(
        context,
        'Detectamos el reverso. Por favor coloca la foto del frente en la primera casilla para capturar tus datos y folio.',
      );
    }

    // 1. Extraer Número de Licencia (descartando nombres propios y folios de pago)
    final detectedNum = _extractLicenseNumber(fullText, recognizedText);
    if (detectedNum != null && detectedNum.isNotEmpty) {
      _licNumController.text = detectedNum.replaceAll(' ', '');
    }

    // 2. Extraer Clase / Tipo de Licencia (ej. A, B, C, A1)
    final detectedClass = _extractLicenseClass(fullText, recognizedText);
    if (detectedClass != null && detectedClass.isNotEmpty) {
      _licClassController.text = detectedClass;
    }

    // 3. Extraer Vigencia / Permanente
    _extractLicenseVigencia(fullText, recognizedText);
  }

  String? _extractLicenseNumber(
      String fullText, RecognizedText recognizedText) {
    final upperFull = fullText.toUpperCase();

    // Heurística A: Formato estándar mexicano: 1 letra seguida de 7 a 9 dígitos (ej. N19032591, A12345678)
    final standardRegex = RegExp(r'\b([A-Z]\s*\d{7,9})\b');
    for (final m in standardRegex.allMatches(upperFull)) {
      final cand = m.group(1)!.replaceAll(' ', '');
      if (_isValidLicenseNumber(cand)) {
        return cand;
      }
    }

    // Heurística B: Palabras clave (FOLIO (sin pago), NO DE LICENCIA, NO., NUM, LICENCIA)
    final keywordRegex = RegExp(
      r'(?:LICENCIA|FOLIO(?!\s*DE\s*PAGO)|NO\.?|N[UÚ]MERO|NUM|CVE|CLAVE)\s*[:.\-]?\s*([A-Z0-9\-]{6,14})',
      caseSensitive: false,
    );
    for (final m in keywordRegex.allMatches(fullText)) {
      final cand =
          m.group(1)!.replaceAll(' ', '').replaceAll('-', '').toUpperCase();
      if (_isValidLicenseNumber(cand)) {
        return cand;
      }
    }

    // Heurística C: Examinar líneas individuales y bloques
    for (final block in recognizedText.blocks) {
      for (int i = 0; i < block.lines.length; i++) {
        final lineClean = block.lines[i].text
            .toUpperCase()
            .replaceAll(' ', '')
            .replaceAll('-', '');
        if (_isValidLicenseNumber(lineClean)) {
          return lineClean;
        }

        // Si la línea contiene FOLIO (no pago) / LICENCIA / NO., inspeccionar la siguiente
        final lineRaw = block.lines[i].text.toUpperCase();
        if ((lineRaw.contains('FOLIO') && !lineRaw.contains('PAGO')) ||
            lineRaw.contains('LICENCIA') ||
            lineRaw.contains('NO.') ||
            lineRaw.contains('N°')) {
          if (i + 1 < block.lines.length) {
            final nextClean = block.lines[i + 1].text
                .toUpperCase()
                .replaceAll(' ', '')
                .replaceAll('-', '');
            if (_isValidLicenseNumber(nextClean)) {
              return nextClean;
            }
          }
        }
      }
    }

    // Heurística D: Números de 8 a 10 dígitos puros (ej. 19032591)
    final pureDigitsRegex = RegExp(r'\b(\d{8,10})\b');
    for (final m in pureDigitsRegex.allMatches(upperFull)) {
      final cand = m.group(1)!;
      if (_isValidLicenseNumber(cand)) {
        return cand;
      }
    }

    // Heurística E: Token alfanumérico genérico que contenga al menos 5 dígitos
    final tokenRegex = RegExp(r'\b[A-Z0-9]{7,12}\b');
    for (final m in tokenRegex.allMatches(upperFull)) {
      final cand = m.group(0)!;
      if (_isValidLicenseNumber(cand)) {
        return cand;
      }
    }

    return null;
  }

  bool _isValidLicenseNumber(String cand) {
    if (cand.length < 6 || cand.length > 14) return false;

    // Descartar si es CURP o RFC
    if (_isCurpOrRfc(cand)) return false;

    // REGLA CRUCIAL: Un número de licencia DEBE contener dígitos obligatoriamente.
    // Nombres como "ALEJANDRO", "HERNANDEZ", "CASTELLANOS" tienen 0 dígitos y quedan descartados.
    final digitsOnly = cand.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 4) return false;

    // Descartar cadenas que inicien con 3 o más letras seguidas (ej. DEPAGO03AE00, RECIBO123)
    if (RegExp(r'^[A-Z]{3,}').hasMatch(cand) && !cand.startsWith('CDMX')) {
      return false;
    }

    // Descartar si parece una fecha YYYYMMDD o DDMMYYYY
    if (cand.length == 8 && RegExp(r'^\d{8}$').hasMatch(cand)) {
      final startYear = int.tryParse(cand.substring(0, 4)) ?? 0;
      final endYear = int.tryParse(cand.substring(4, 8)) ?? 0;
      if ((startYear >= 1950 && startYear <= 2035) &&
          (endYear >= 101 && endYear <= 1231)) {
        return false;
      }
      if ((endYear >= 1950 && endYear <= 2035) &&
          (startYear >= 101 && startYear <= 1231)) {
        return false;
      }
    }

    // Descartar palabras reservadas del documento (incluyendo conceptos de pago)
    const forbidden = [
      'PAGO',
      'DEPAGO',
      'RECIBO',
      'TESORERIA',
      'MODULO',
      'OPERADOR',
      'AUTORIZO',
      'PERMANENTE',
      'MEXICANA',
      'NACIONALIDAD',
      'EXPEDICION',
      'ANTIGUEDAD',
      'AUTOMOVILISTA',
      'CONDUCTOR',
      'PARTICULAR',
      'SECRETARIA',
      'MOVILIDAD',
      'TRANSPORTE',
      'GOBIERNO',
      'ESTADO',
      'MEXICO',
      'VIGENCIA',
      'LICENCIA',
      'FEDERAL',
    ];
    for (final word in forbidden) {
      if (cand.contains(word)) return false;
    }

    return true;
  }

  String? _extractLicenseClass(String fullText, RecognizedText recognizedText) {
    // 1. TIPO A, CLASE B, etc.
    final directRegex = RegExp(
      r'(?:TIPO|CLASE|CATEGOR[IÍ]A)\s*[:.\-]?\s*([A-E][0-9]?)',
      caseSensitive: false,
    );
    final directMatch = directRegex.firstMatch(fullText);
    if (directMatch != null) {
      return directMatch.group(1)?.toUpperCase();
    }

    // 2. A TIPO, B TIPO (letra antes del texto TIPO)
    final reverseRegex = RegExp(
      r'\b([A-E][0-9]?)\s*[:.\-]?\s*(?:TIPO|CLASE|CATEGOR[IÍ]A)\b',
      caseSensitive: false,
    );
    final reverseMatch = reverseRegex.firstMatch(fullText);
    if (reverseMatch != null) {
      return reverseMatch.group(1)?.toUpperCase();
    }

    // 3. Buscar en bloques adyacentes arriba o abajo de "TIPO"
    for (final block in recognizedText.blocks) {
      for (int i = 0; i < block.lines.length; i++) {
        final line = block.lines[i].text.toUpperCase().trim();
        if (line == 'TIPO' || line == 'CLASE' || line == 'CATEGORIA') {
          if (i > 0) {
            final prevLine = block.lines[i - 1].text.trim().toUpperCase();
            if (RegExp(r'^[A-E][0-9]?$').hasMatch(prevLine)) {
              return prevLine;
            }
          }
          if (i + 1 < block.lines.length) {
            final nextLine = block.lines[i + 1].text.trim().toUpperCase();
            if (RegExp(r'^[A-E][0-9]?$').hasMatch(nextLine)) {
              return nextLine;
            }
          }
        }
      }
    }

    return null;
  }

  void _extractLicenseVigencia(String fullText, RecognizedText recognizedText) {
    final upperFull = fullText.toUpperCase();

    // 1. Detectar licencia permanente
    if (upperFull.contains('PERMANENTE') ||
        upperFull.contains('INDETERMINAD') ||
        upperFull.contains('INDEFINID')) {
      setState(() {
        isPermanent = true;
        dueDate = DateTime(2099, 12, 31);
      });
      return;
    }

    // 2. Si no es permanente, buscar fecha de vencimiento
    final dateRegex =
        RegExp(r'\b(\d{1,2})[\/\.\-](\d{1,2})[\/\.\-](\d{2,4})\b');
    final dateIsoRegex =
        RegExp(r'\b(\d{4})[\/\.\-](\d{1,2})[\/\.\-](\d{1,2})\b');
    DateTime? foundDue;

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final t = line.text.toUpperCase();
        if (t.contains('VENCE') ||
            t.contains('VIGENCIA') ||
            t.contains('EXPIRA') ||
            t.contains('HASTA') ||
            t.contains('VENCIMIENTO')) {
          final m = dateRegex.firstMatch(line.text);
          if (m != null) {
            final d = int.tryParse(m.group(1)!);
            final mo = int.tryParse(m.group(2)!);
            var y = int.tryParse(m.group(3)!);
            if (y != null && y < 100) {
              y = (y > 50) ? 1900 + y : 2000 + y;
            }
            if (d != null &&
                mo != null &&
                y != null &&
                y > 1990 &&
                y < 2100 &&
                mo >= 1 &&
                mo <= 12 &&
                d >= 1 &&
                d <= 31) {
              foundDue = DateTime(y, mo, d);
              break;
            }
          }
          final mIso = dateIsoRegex.firstMatch(line.text);
          if (mIso != null) {
            final y = int.tryParse(mIso.group(1)!);
            final mo = int.tryParse(mIso.group(2)!);
            final d = int.tryParse(mIso.group(3)!);
            if (d != null &&
                mo != null &&
                y != null &&
                y > 1990 &&
                y < 2100 &&
                mo >= 1 &&
                mo <= 12 &&
                d >= 1 &&
                d <= 31) {
              foundDue = DateTime(y, mo, d);
              break;
            }
          }
        }
      }
      if (foundDue != null) break;
    }

    // Fallback: Tomar la fecha más lejana encontrada
    if (foundDue == null) {
      final List<DateTime> allDates = [];
      for (final match in dateRegex.allMatches(fullText)) {
        final d = int.tryParse(match.group(1)!);
        final mo = int.tryParse(match.group(2)!);
        var y = int.tryParse(match.group(3)!);
        if (y != null && y < 100) {
          y = (y > 50) ? 1900 + y : 2000 + y;
        }
        if (d != null &&
            mo != null &&
            y != null &&
            y > 2000 &&
            y < 2100 &&
            mo >= 1 &&
            mo <= 12 &&
            d >= 1 &&
            d <= 31) {
          allDates.add(DateTime(y, mo, d));
        }
      }
      if (allDates.isNotEmpty) {
        allDates.sort((a, b) => a.compareTo(b));
        foundDue = allDates.last;
      }
    }

    if (foundDue != null) {
      setState(() {
        dueDate = foundDue;
        isPermanent = false;
      });
    }
  }

  bool _isCurpOrRfc(String text) {
    if (text.length == 18) {
      return RegExp(r'^[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z0-9]\d$').hasMatch(text);
    }
    if (text.length == 12 || text.length == 13) {
      return RegExp(r'^[A-Z]{3,4}\d{6}[A-Z0-9]{3}$').hasMatch(text);
    }
    return false;
  }

  Future<void> _saveLicense({
    required String num,
    required String category,
    required DateTime? date,
    required bool permanent,
  }) async {
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (!permanent && (date == null || date.isBefore(today))) {
      SnackbarTop.showError(
        context,
        'Por favor selecciona una fecha de vigencia que no esté vencida.',
      );
      return;
    }

    if (!_canEdit(null)) {
      SnackbarTop.showWarning(
        context,
        'Tu perfil no cuenta con permisos para registrar o modificar la licencia.',
        title: 'Acceso Restringido',
      );
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      // 1. Subir fotografías a la API (POST api.php?a=foto) si están presentes
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

      // Evitar subir la misma foto duplicada si seleccionaron el mismo archivo en ambos campos
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

      // 2. Enviar acción tipo licencia a la API (POST api.php?a=acciones)
      final cleanNum = num.trim().replaceAll(' ', '').toUpperCase();
      await ProfileconService().agregarNuevaLicencia({
        'idCollaborator': widget.idCollaborator,
        'licNum': cleanNum,
        'licClass': category.trim().toUpperCase(),
        'dueDate': permanent
            ? DateTime(2099, 12, 31).toIso8601String()
            : date!.toIso8601String(),
        'fotos': photoUuids,
      });

      if (mounted) {
        setState(() {
          licenseDataFuture = fetchLicenseDataById(widget.idCollaborator);
          _licNumController.clear();
          _licClassController.clear();
          dueDate = null;
          isPermanent = false;
          _frontImage = null;
          _backImage = null;
          _isEditing = false;
          isLoading = false;
        });

        SnackbarTop.showSuccess(
          context,
          'Licencia guardada exitosamente.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });

        SnackbarTop.showError(
          context,
          'Error al procesar la licencia: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  Future<void> _selectDate(
    BuildContext context, {
    DateTime? initial,
    required ValueChanged<DateTime> onDateSelected,
  }) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
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

  int _calculateDaysRemaining(DateTime targetDate) {
    if (targetDate.year >= 2090 || targetDate.year <= 1900) return 99999;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return due.difference(today).inDays;
  }

  String _formatDueDate(dynamic dateVal) {
    if (dateVal == null) return 'N/A';
    if (dateVal is String) {
      try {
        final parsed = DateTime.parse(dateVal);
        if (parsed.year >= 2090 || parsed.year <= 1900) return 'PERMANENTE';
        return DateFormat('dd / MM / yyyy').format(parsed);
      } catch (_) {
        return 'N/A';
      }
    } else if (dateVal is DateTime) {
      if (dateVal.year >= 2090 || dateVal.year <= 1900) return 'PERMANENTE';
      return DateFormat('dd / MM / yyyy').format(dateVal);
    }
    return 'N/A';
  }

  String _getCategoryDescription(String? cat) {
    if (cat == null || cat.isEmpty) return 'Licencia de Conducir';
    switch (cat.trim().toUpperCase()) {
      case 'A':
        return 'Automovilista Particular';
      case 'B':
        return 'Servicio Público y Mercantil';
      case 'C':
        return 'Transporte de Carga';
      case 'D':
        return 'Transporte de Emergencia';
      case 'E':
        return 'Transporte Especializado';
      default:
        return 'Categoría $cat';
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
                  _buildHeader(context),
                  const SizedBox(height: 12),

                  // Contenido dinámico (Skeleton, Error, Vista Activa o Formulario)
                  FutureBuilder<Map<String, dynamic>?>(
                    future: licenseDataFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildSkeleton(isSmallScreen);
                      } else if (snapshot.hasError) {
                        return _buildErrorState();
                      }

                      final data = snapshot.data;
                      _lastFetchedData = data;
                      final hasLicense = data != null &&
                          data.isNotEmpty &&
                          (data['licNum'] != null &&
                              data['licNum'].toString().trim().isNotEmpty);
                      final canEdit = _canEdit(data);

                      if (hasLicense) {
                        if (_isEditing && canEdit) {
                          return _buildAddLicenseSection(isEditing: true);
                        }
                        return _buildLicenseDetailsContent(data, canEditLicense: canEdit);
                      } else {
                        if (!canEdit) {
                          return _buildNoPermissionEmptyState();
                        }
                        return _buildAddLicenseSection(isEditing: false);
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

  // --- HEADER SUPERIOR ESTILO APPLE ---
  Widget _buildHeader(BuildContext context) {
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
                _isEditing ? 'Actualizar Licencia' : 'Licencia de Conducir',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                _isEditing
                    ? 'Escanea o edita los datos de tu credencial'
                    : 'Consulta el estatus, vigencia y fotos de tu credencial',
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
      ],
    );
  }

  // --- SKELETON APPLE DE CARGA ---
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
          child: AppShimmerBox.text(width: 140, height: 12),
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
                        AppShimmerBox.text(width: 130, height: 14),
                        SizedBox(height: 6),
                        AppShimmerBox.text(width: 200, height: 11),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const AppShimmerBox(
                  width: double.infinity, height: 46, borderRadius: 12),
            ],
          ),
        ),
      ],
    );
  }

  // --- ESTADO DE ERROR ESTILO APPLE ---
  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Error al cargar información de licencia',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Comprueba tu conexión o intenta nuevamente.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reintentar',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  bool _canEdit(Map<String, dynamic>? data) {
    if (data == null) {
      if (_lastFetchedData != null) {
        return _lastFetchedData!['puedeEditar'] == true;
      }
      return false;
    }
    return data['puedeEditar'] == true;
  }

  Widget _buildNoPermissionEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.badge_outlined, size: 56, color: Color(0xFF94A3B8)),
          SizedBox(height: 16),
          Text(
            'Sin Licencia Registrada',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tu perfil no cuenta con una licencia asociada ni con permisos para dar de alta credenciales de conducir.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // VISTA: CUANDO TIENE LICENCIA ACTIVA (APPLE WALLET STYLE + FOTOS + RENOVAR)
  // =========================================================================
  Widget _buildLicenseDetailsContent(
    Map<String, dynamic> licenseData, {
    bool canEditLicense = true,
  }) {
    dynamic dueRaw = licenseData['dueDate'];
    DateTime? parsedDue;
    bool isPerm = false;

    if (dueRaw is String) {
      try {
        parsedDue = DateTime.parse(dueRaw);
      } catch (_) {
        isPerm = true;
      }
    } else if (dueRaw is DateTime) {
      parsedDue = dueRaw;
    }

    if (parsedDue == null ||
        parsedDue.year <= 1900 ||
        parsedDue.year <= 0 ||
        parsedDue.year >= 2090) {
      isPerm = true;
    }

    final category = licenseData['licClass']?.toString().toUpperCase() ?? 'A';
    final licNumStr = licenseData['licNum']?.toString() ?? '----';

    int daysRemaining = 999;
    bool isExpired = false;
    bool isClose = false;
    bool isToday = false;

    Color badgeBg;
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (isPerm || parsedDue == null) {
      badgeBg = const Color(0xFF0284C7).withOpacity(0.2);
      badgeColor = const Color(0xFF38BDF8);
      badgeText = 'PERMANENTE';
      badgeIcon = Icons.all_inclusive_rounded;
    } else {
      daysRemaining = _calculateDaysRemaining(parsedDue);
      if (daysRemaining < 0) {
        isExpired = true;
        badgeBg = const Color(0xFFEF4444).withOpacity(0.25);
        badgeColor = const Color(0xFFFCA5A5);
        badgeText = 'EXPIRADA';
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

    final rawFotos = licenseData['fotos'];
    final List<int> fotoIds = [];
    if (rawFotos is List) {
      for (final f in rawFotos) {
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
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. HERO DIGITAL DRIVER'S LICENSE CARD (APPLE WALLET STYLE)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0F172A),
                Color(0xFF0F2B48),
                Color(0xFF0284C7),
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
                color: const Color(0xFF0F172A).withOpacity(0.18),
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
                      // Fila Superior: Título Oficial + Sello de Seguridad
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.directions_car_rounded,
                                  color: Colors.white,
                                  size: 17,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'LICENCIA DE CONDUCIR',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white.withOpacity(0.95),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Text(
                                    'CREDENCIAL DIGITAL · MARK FLEET',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.65),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded,
                                    size: 12, color: Color(0xFF38BDF8)),
                                SizedBox(width: 4),
                                Text(
                                  'OFICIAL',
                                  style: TextStyle(
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

                      // Fila Central: Tipo de Licencia + Número Grande
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
                                        Icons.badge_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'TIPO $category',
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
                                  _getCategoryDescription(category),
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
                                  'NÚMERO DE LICENCIA',
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
                                    licNumStr.trim(),
                                    maxLines: 1,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 2.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Fila Inferior: Vigencia + Badge de Estatus Integrado
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'VIGENCIA',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.65),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isPerm
                                      ? 'PERMANENTE'
                                      : _formatDueDate(dueRaw),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
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

        // 2. SECCIÓN: ESTATUS DEL DOCUMENTO (INSET GROUPED)
        _buildSectionTitle('ESTATUS DEL DOCUMENTO'),
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
                            : (isPerm
                                ? const Color(0xFFE0F2FE)
                                : const Color(0xFFDCFCE7))),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      isExpired
                          ? Icons.error_outline_rounded
                          : (isClose || isToday
                              ? Icons.warning_amber_rounded
                              : (isPerm
                                  ? Icons.all_inclusive_rounded
                                  : Icons.verified_rounded)),
                      color: isExpired
                          ? const Color(0xFFEF4444)
                          : (isClose || isToday
                              ? const Color(0xFFEA580C)
                              : (isPerm
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFF10B981))),
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
                        isPerm
                            ? 'Licencia Permanente'
                            : (isExpired
                                ? 'Licencia Expirada'
                                : (isToday
                                    ? 'Vence el Día de Hoy'
                                    : (isClose
                                        ? 'Próxima a Vencer'
                                        : 'Licencia Vigente'))),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPerm
                            ? 'No requiere renovación periódica de vigencia'
                            : (isExpired
                                ? 'Venció hace ${-daysRemaining} días. Se requiere renovación.'
                                : (isToday
                                    ? 'Su validez expira hoy a las 23:59 hrs.'
                                    : 'Quedan $daysRemaining días de validez legal')),
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
                          isPerm
                              ? 'ESTATUS: VIGENCIA INDEFINIDA'
                              : (isExpired
                                  ? 'DOCUMENTO FUERA DE VIGENCIA'
                                  : 'CONDICIÓN: EN REGLA Y ACTIVA'),
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
                          isPerm
                              ? 'Documento registrado apto para circulación permanente.'
                              : (isExpired
                                  ? 'Renueva tu licencia ante la autoridad correspondiente.'
                                  : 'Documento apto para circulación y operaciones de campo.'),
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

        // 3. SECCIÓN: FOTOGRAFÍAS DE LA CREDENCIAL (SI EXISTEN EN EL SERVIDOR)
        if (fotoIds.isNotEmpty) ...[
          _buildSectionTitle('FOTOGRAFÍAS DE LA CREDENCIAL'),
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
        ],

        // 4. BOTÓN: RENOVAR / ACTUALIZAR LICENCIA (Visible solo si tiene permisos de modificación)
        if (canEditLicense) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF0284C7), width: 1.2),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  setState(() {
                    _isEditing = true;
                    _licNumController.text =
                        licenseData['licNum']?.toString() ?? '';
                    _licClassController.text =
                        licenseData['licClass']?.toString() ?? '';
                    dueDate = isPerm ? DateTime(2099, 12, 31) : parsedDue;
                    isPermanent = isPerm;
                    _frontImage = null;
                    _backImage = null;
                  });
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_document, size: 17, color: Color(0xFF0284C7)),
                    SizedBox(width: 8),
                    Text(
                      'Actualizar o Renovar Licencia',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  // =========================================================================
  // VISTA: REGISTRO / ACTUALIZACIÓN DE LICENCIA (CON OCR INTEGRADO EN EL FRENTE)
  // =========================================================================
  Widget _buildAddLicenseSection({bool isEditing = false}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FOTOGRAFÍAS DE LA CREDENCIAL (FRENTE CON OCR Y REVERSO)
          _buildSectionTitle('FOTOGRAFÍAS DE LA CREDENCIAL'),
          _buildAppleGroupContainer(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildPhotoBox(
                      title: 'Frente de la Licencia',
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
                      title: 'Reverso de la Licencia',
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
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0284C7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Al escanear el frente completaremos tus datos con IA. Recuerda verificar que el folio y vigencia coincidan.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF0369A1),
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // SECCIÓN: DATOS DE LA LICENCIA
          _buildSectionTitle('DATOS DE LA CREDENCIAL'),
          _buildAppleGroupContainer(
            children: [
              // Campo Número de Licencia
              _buildFormField(
                controller: _licNumController,
                label: 'Número de Licencia',
                icon: Icons.credit_card_rounded,
                maxLength: 14,
                hintText: 'Ej. N19037891',
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Ingresa el número de licencia'
                    : null,
              ),
              const SizedBox(height: 12),

              // Campo Tipo / Categoría
              _buildFormField(
                controller: _licClassController,
                label: 'Tipo / Categoría (ej. A, B, C)',
                icon: Icons.category_outlined,
                maxLength: 2,
                hintText: 'Ej. A, B, C',
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Ingresa la categoría'
                    : null,
              ),
              const SizedBox(height: 12),

              // Switch Apple: Licencia Permanente
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.all_inclusive_rounded,
                        size: 18, color: Color(0xFF0284C7)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Licencia Permanente',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Activar si no tiene fecha de caducidad',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: isPermanent,
                      activeColor: const Color(0xFF0284C7),
                      onChanged: (val) {
                        setState(() {
                          isPermanent = val;
                          if (isPermanent) {
                            dueDate = DateTime(2099, 12, 31);
                          } else {
                            dueDate = null;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Fecha de Vencimiento (si no es permanente)
              if (!isPermanent) ...[
                const SizedBox(height: 12),
                _buildDateField(context),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // BOTÓN DE ACCIÓN REUTILIZABLE CON LOADING INTEGRADO
          LoadingActionButton(
            text: isEditing ? 'Guardar Cambios' : 'Guardar Licencia',
            isLoading: isLoading,
            icon: Icons.check_circle_rounded,
            height: 50,
            borderRadius: 16,
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                _saveLicense(
                  num: _licNumController.text,
                  category: _licClassController.text,
                  date: dueDate,
                  permanent: isPermanent,
                );
              }
            },
          ),
          if (isEditing) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                  });
                },
                child: const Text(
                  'Cancelar Edición',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  // --- CAJA DE FOTO PREVIEW ESTILO APPLE (FRENTE Y REVERSO) ---
  Widget _buildPhotoBox({
    required String title,
    required String tag,
    required File? image,
    required bool isScanning,
    required VoidCallback onTap,
    required VoidCallback onRemove,
    required bool isRequired,
  }) {
    final isFront = isRequired;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: isScanning ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 132,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isScanning
                  ? const Color(0xFFF0F9FF)
                  : (image != null ? Colors.black : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isScanning
                    ? const Color(0xFF0284C7)
                    : (image != null
                        ? const Color(0xFF0284C7)
                        : const Color(0xFFE2E8F0)),
                width: isScanning || image != null ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isScanning
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF0284C7)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Escaneando con IA...',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  )
                : (image != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              image,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 38,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(14)),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.65),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      size: 13, color: Color(0xFF4ADE80)),
                                  const SizedBox(width: 4),
                                  Text(
                                    isFront ? 'Frente listo' : 'Reverso listo',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Text(
                                    'Cambiar',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onRemove,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white24, width: 0.8),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        children: [
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: isFront
                                    ? const Color(0xFFE0F2FE)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isFront) ...[
                                    const Icon(Icons.auto_awesome_rounded,
                                        size: 9.5, color: Color(0xFF0284C7)),
                                    const SizedBox(width: 3),
                                  ],
                                  Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      color: isFront
                                          ? const Color(0xFF0284C7)
                                          : const Color(0xFF64748B),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isFront
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
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isFront
                                                ? const Color(0xFF0284C7)
                                                : const Color(0xFF64748B))
                                            .withOpacity(0.08),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isFront
                                        ? Icons.document_scanner_rounded
                                        : Icons.flip_to_back_rounded,
                                    color: isFront
                                        ? const Color(0xFF0284C7)
                                        : const Color(0xFF475569),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isFront ? 'Escanear Frente' : 'Foto Reverso',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isFront
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                const Text(
                                  'Cámara o Galería',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )),
          ),
        ),
      ],
    );
  }

  // --- SELECTOR DE FECHA ESTILO APPLE ---
  Widget _buildDateField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 5),
          child: Text(
            'Fecha de Vencimiento',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
              letterSpacing: -0.1,
            ),
          ),
        ),
        TextFormField(
          readOnly: true,
          onTap: () => _selectDate(
            context,
            initial: dueDate,
            onDateSelected: (selected) {
              setState(() {
                dueDate = selected;
              });
            },
          ),
          cursorColor: const Color(0xFF0284C7),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Seleccionar fecha',
            hintStyle: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: const Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: Color(0xFF0284C7),
            ),
            suffixIcon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF64748B),
              size: 18,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
              borderSide:
                  const BorderSide(color: Color(0xFF0284C7), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
          ),
          controller: TextEditingController(
            text: dueDate != null
                ? DateFormat('dd / MM / yyyy').format(dueDate!)
                : '',
          ),
          validator: (val) {
            if (!isPermanent && dueDate == null) {
              return 'Por favor selecciona la fecha de vencimiento';
            }
            return null;
          },
        ),
      ],
    );
  }

  // --- CAMPO DE TEXTO ESTILIZADO APPLE ---
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.characters,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 5),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
              letterSpacing: -0.1,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          validator: validator,
          cursorColor: const Color(0xFF0284C7),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            isDense: true,
            counterText: '',
            hintText: hintText ?? label,
            hintStyle: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              icon,
              size: 17,
              color: const Color(0xFF0284C7),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
              borderSide:
                  const BorderSide(color: Color(0xFF0284C7), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // --- TÍTULO DE SECCIÓN INSET GROUPED ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // --- CONTENEDOR INSET GROUPED ESTILO APPLE ---
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
            color: const Color(0xFF0F172A).withOpacity(0.03),
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
}
