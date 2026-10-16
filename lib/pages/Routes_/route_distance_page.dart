import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

/// Utilidades visuales y widgets compartidos del módulo de Operación / Rutas:
/// 1. Alertas y avisos del servidor (verde info, amarillo aviso, rojo error + sonido/vibración)
/// 2. Escáner QR / Código de barras en ráfaga o individual (MobileScanner)
/// 3. Panel de Firma en pantalla (Canvas nativo → PNG blanco y negro)

void showServerNoticesFeedback(
  BuildContext context,
  List<ServerNotice> notices, {
  String? fallbackSuccessMessage,
}) {
  if (!context.mounted) return;

  if (notices.isEmpty && fallbackSuccessMessage != null) {
    SnackbarTop.showSuccess(
      context,
      fallbackSuccessMessage,
      style: SnackbarTopStyle.appleCard,
    );
    return;
  }

  final criticalErrors = notices.where((n) => n.isCriticalRedAlert).toList();
  final warningsAndInfo = notices.where((n) => !n.isCriticalRedAlert).toList();

  if (warningsAndInfo.isNotEmpty) {
    final hasWarning = warningsAndInfo.any((n) => n.nivel == 'aviso');
    final text = warningsAndInfo.map((n) => n.displayTexto).join('\n');
    
    if (hasWarning) {
      SnackbarTop.showWarning(
        context,
        text,
        style: SnackbarTopStyle.appleCard,
      );
    } else {
      SnackbarTop.showSuccess(
        context,
        text,
        style: SnackbarTopStyle.appleCard,
      );
    }
  }

  if (criticalErrors.isNotEmpty) {
    HapticFeedback.lightImpact();
    final text = criticalErrors.map((n) => n.displayTexto).join('\n');
    SnackbarTop.showError(
      context,
      text,
      style: SnackbarTopStyle.appleCard,
    );
  }
}

// =============================================================================
// ESCÁNER DE ETIQUETAS QR / CÓDIGO DE BARRAS (RÁFAGA O INDIVIDUAL)
// Soporta links https://cgps.mx/?e=K7Q2M9XDR4 y validación local contra guías
// =============================================================================

class LabelScannerSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool burstMode;
  final List<String> initialCodes;
  /// Si se provee, valida que el código escaneado pertenezca a este conjunto (ej. entrega de una guía o carga de una ruta)
  final Set<String>? validNormalizedCodes;
  /// Mapa opcional de códigos prohibidos normalizados -> Folio o descripción de la otra guía a la que pertenecen
  final Map<String, String>? forbiddenNormalizedCodes;
  final String invalidCodeAlertTitle;
  final String invalidCodeAlertMessage;

  const LabelScannerSheet({
    super.key,
    required this.title,
    this.subtitle = 'Apunte al QR o código de barras del bulto (ej. cgps.mx/?e=...)',
    this.burstMode = true,
    this.initialCodes = const [],
    this.validNormalizedCodes,
    this.forbiddenNormalizedCodes,
    this.invalidCodeAlertTitle = '¡ETIQUETA INCORRECTA!',
    this.invalidCodeAlertMessage =
        'Este bulto no corresponde a esta operación. ¡NO lo subas / NO lo entregues aquí!',
  });

  @override
  State<LabelScannerSheet> createState() => _LabelScannerSheetState();
}

class _LabelScannerSheetState extends State<LabelScannerSheet> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  final TextEditingController _manualCtrl = TextEditingController();
  late List<String> _scannedRawCodes;
  final Set<String> _scannedNormalized = {};
  String? _redFlashError;
  DateTime? _lastScanTime;

  @override
  void initState() {
    super.initState();
    _scannedRawCodes = List<String>.from(widget.initialCodes);
    for (final c in _scannedRawCodes) {
      _scannedNormalized.add(LabelCode.normalizeScannedCode(c));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  void _handleCodeDetected(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now();
    if (_lastScanTime != null &&
        now.difference(_lastScanTime!).inMilliseconds < 900) {
      return;
    }
    _lastScanTime = now;

    final normalized = LabelCode.normalizeScannedCode(trimmed);
    if (normalized.isEmpty) return;

    // 1. Validar si el código está explícitamente prohibido (pertenece a OTRA guía de la ruta)
    if (widget.forbiddenNormalizedCodes != null &&
        widget.forbiddenNormalizedCodes!.containsKey(normalized)) {
      final otherFolio = widget.forbiddenNormalizedCodes![normalized] ?? 'otra guía';
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      setState(() {
        _redFlashError =
            '¡ETQ_OTRA — PAQUETE EQUIVOCADO!\nCódigo: $normalized\nEste bulto pertenece a la guía $otherFolio\n\n¡NO corresponde a este envío!';
      });
      return;
    }

    // 2. Validar localmente si hay lista blanca de etiquetas de la guía o ruta
    if (widget.validNormalizedCodes != null &&
        widget.validNormalizedCodes!.isNotEmpty &&
        !widget.validNormalizedCodes!.contains(normalized)) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      setState(() {
        _redFlashError =
            '${widget.invalidCodeAlertTitle}\nCódigo: $normalized\n${widget.invalidCodeAlertMessage}';
      });
      return;
    }

    if (_scannedNormalized.contains(normalized)) {
      HapticFeedback.selectionClick();
      return;
    }

    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    setState(() {
      _redFlashError = null;
      _scannedNormalized.add(normalized);
      _scannedRawCodes.add(trimmed);
    });

    if (!widget.burstMode && mounted) {
      Navigator.of(context).pop(_scannedRawCodes);
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
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 0;

    final double sheetHeight = isKeyboardOpen
        ? (mediaQuery.size.height - keyboardHeight - mediaQuery.padding.top - 8)
            .clamp(320.0, mediaQuery.size.height * 0.88)
        : (mediaQuery.size.height * 0.74);

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: AnimatedPadding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutQuad,
          child: Container(
            height: sheetHeight,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 3.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      isKeyboardOpen ? 4 : 8,
                      16,
                      isKeyboardOpen ? 4 : 6,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFF0F172A),
                                  fontSize: isKeyboardOpen ? 14 : 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              if (!isKeyboardOpen) ...[
                                const SizedBox(height: 1.5),
                                Text(
                                  widget.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Visor de cámara (adaptativo cuando se abre el teclado)
                  Flexible(
                    flex: isKeyboardOpen ? 2 : 4,
                    fit: FlexFit.tight,
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: isKeyboardOpen ? 2 : 5,
                      ),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(isKeyboardOpen ? 12 : 16),
                        border: Border.all(
                          color: _redFlashError != null
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF0284C7),
                          width: _redFlashError != null ? 3 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_redFlashError != null
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF0284C7))
                                .withOpacity(0.14),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          MobileScanner(
                            controller: _controller,
                            onDetect: (capture) {
                              for (final barcode in capture.barcodes) {
                                final raw = barcode.rawValue;
                                if (raw != null && raw.isNotEmpty) {
                                  _handleCodeDetected(raw);
                                  break;
                                }
                              }
                            },
                          ),
                          // Marco guía adaptable
                          Center(
                            child: Container(
                              width: isKeyboardOpen ? 70 : 165,
                              height: isKeyboardOpen ? 70 : 165,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.85),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(isKeyboardOpen ? 8 : 14),
                              ),
                            ),
                          ),
                          if (_redFlashError != null)
                            Container(
                              color: const Color(0xFFDC2626).withOpacity(0.95),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              alignment: Alignment.center,
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.dangerous_rounded,
                                      color: Colors.white,
                                      size: isKeyboardOpen ? 24 : 36,
                                    ),
                                    SizedBox(height: isKeyboardOpen ? 4 : 8),
                                    Text(
                                      _redFlashError!,
                                      textAlign: TextAlign.center,
                                      softWrap: true,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isKeyboardOpen ? 11.5 : 13,
                                        fontWeight: FontWeight.w800,
                                        height: 1.35,
                                      ),
                                    ),
                                    SizedBox(height: isKeyboardOpen ? 6 : 10),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFFDC2626),
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () =>
                                          setState(() => _redFlashError = null),
                                      child: const Text(
                                        'Continuar escaneando',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Captura manual de respaldo
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: isKeyboardOpen ? 2 : 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _manualCtrl,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                hintText: 'Escribir código manual (ej. K7Q2...)',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11.5,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 9),
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
                                  borderSide: const BorderSide(color: Color(0xFF0284C7)),
                                ),
                              ),
                              onSubmitted: (val) {
                                if (val.trim().isNotEmpty) {
                                  _handleCodeDetected(val);
                                  _manualCtrl.clear();
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              if (_manualCtrl.text.trim().isNotEmpty) {
                                _handleCodeDetected(_manualCtrl.text);
                                _manualCtrl.clear();
                              }
                            },
                            child: const Text(
                              'Agregar',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Lista de códigos escaneados en ráfaga
                  Flexible(
                    flex: isKeyboardOpen ? 3 : 3,
                    fit: FlexFit.tight,
                    child: Container(
                      width: double.infinity,
                      margin: EdgeInsets.fromLTRB(
                        16,
                        isKeyboardOpen ? 2 : 4,
                        16,
                        isKeyboardOpen ? 4 : 8,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Bultos / etiquetas escaneadas (${_scannedRawCodes.length})',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (_scannedRawCodes.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _scannedRawCodes.clear();
                                      _scannedNormalized.clear();
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text(
                                    'Limpiar',
                                    style: TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Expanded(
                            child: _scannedRawCodes.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Aún no se han escaneado etiquetas',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  )
                                : SingleChildScrollView(
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: _scannedRawCodes.asMap().entries.map((entry) {
                                        final idx = entry.key;
                                        final raw = entry.value;
                                        final norm = LabelCode.normalizeScannedCode(raw);
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF8FC),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFBAE6FD)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                norm,
                                                style: const TextStyle(
                                                  color: Color(0xFF0284C7),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _scannedRawCodes.removeAt(idx);
                                                    _scannedNormalized.remove(norm);
                                                  });
                                                },
                                                child: const Icon(
                                                  Icons.close_rounded,
                                                  size: 13,
                                                  color: Color(0xFF0284C7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      isKeyboardOpen ? 6 : 10,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: isKeyboardOpen ? 38 : 42,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(_scannedRawCodes),
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: Text(
                          'Confirmar (${_scannedRawCodes.length}) etiquetas',
                          style: TextStyle(
                            fontSize: isKeyboardOpen ? 12.5 : 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
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
}

// =============================================================================
// PANEL DE FIRMA EN PANTALLA (CANVAS NATIVO → PNG EN BLANCO Y NEGRO)
// =============================================================================

class SignaturePadSheet extends StatefulWidget {
  final String recipientName;

  const SignaturePadSheet({super.key, this.recipientName = ''});

  @override
  State<SignaturePadSheet> createState() => _SignaturePadSheetState();
}

class _SignaturePadSheetState extends State<SignaturePadSheet> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  bool _isExporting = false;

  bool get _hasSignature => _strokes.any((s) => s.length > 1);

  Future<Uint8List?> _exportSignaturePng(Size canvasSize) async {
    if (!_hasSignature) return null;
    setState(() => _isExporting = true);
    try {
      final recorder = ui.PictureRecorder();
      final width = canvasSize.width.clamp(300.0, 800.0);
      final height = canvasSize.height.clamp(180.0, 400.0);
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

      // Fondo blanco puro para PNG B/N (Regla: "La firma, PNG en blanco y negro")
      final bgPaint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

      final strokePaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (final stroke in _strokes) {
        if (stroke.length < 2) continue;
        final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
        canvas.drawPath(path, strokePaint);
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      if (mounted) setState(() => _isExporting = false);
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
      child: Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.draw_rounded, color: Color(0xFF0284C7)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.recipientName.isNotEmpty
                        ? 'Firma de: ${widget.recipientName}'
                        : 'Firma de quien recibe',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _strokes.clear();
                    _currentStroke = [];
                  }),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Limpiar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Solicite al destinatario que firme dentro del recuadro con su dedo:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize = Size(constraints.maxWidth, 220);
                return Column(
                  children: [
                    Container(
                      width: canvasSize.width,
                      height: canvasSize.height,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFCBD5E1),
                          width: 2,
                        ),
                      ),
                      child: GestureDetector(
                        onPanStart: (details) {
                          setState(() {
                            _currentStroke = [details.localPosition];
                            _strokes.add(_currentStroke);
                          });
                        },
                        onPanUpdate: (details) {
                          final pos = details.localPosition;
                          if (pos.dx >= 0 &&
                              pos.dx <= canvasSize.width &&
                              pos.dy >= 0 &&
                              pos.dy <= canvasSize.height) {
                            setState(() {
                              _currentStroke.add(pos);
                            });
                          }
                        },
                        child: CustomPaint(
                          size: canvasSize,
                          painter: _SignaturePainter(_strokes),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: !_hasSignature || _isExporting
                            ? null
                            : () async {
                                final png = await _exportSignaturePng(canvasSize);
                                if (context.mounted && png != null) {
                                  Navigator.of(context).pop(png);
                                }
                              },
                        icon: const Icon(Icons.check_rounded),
                        label: Text(
                          _isExporting ? 'Guardando firma...' : 'Guardar Firma',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

class DistanceRoutePage extends StatelessWidget {
  final int idRoute;
  const DistanceRoutePage({super.key, required this.idRoute});

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
        appBar: AppBar(title: Text('Ruta #$idRoute')),
        body: const Center(child: Text('Detalle de recorrido integrado en el mapa de ruta.')),
      ),
    );
  }
}
