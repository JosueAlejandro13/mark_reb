import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/services/database_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class ProductosPage extends StatefulWidget {
  const ProductosPage({super.key});

  @override
  State<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends State<ProductosPage>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  late BarcodeScanner _barcodeScanner;
  bool _isDetecting = false;
  bool _cameraInitialized = false;
  late AnimationController _laserAnimationController;
  late Animation<double> _laserAnimation;
  final authService = DatabaseService();

  double _currentZoom = 1.0;
  double _maxZoom = 1.0;
  int _scanAttempts = 0;
  final int _maxAttemptsBeforeZoom = 10;

  @override
  void initState() {
    super.initState();
    _barcodeScanner = BarcodeScanner();

    _laserAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _laserAnimationController, curve: Curves.easeInOut),
    );

    _startBarcodeScanner();
  }

  Future<void> _startBarcodeScanner() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;

    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
    );

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController!.initialize();
    } catch (e) {
      print('Error al inicializar cámara: $e');
      return;
    }

    if (!_cameraController!.value.isInitialized) {
      print('La cámara no se inicializó correctamente');
      return;
    }

    setState(() {
      _cameraInitialized = true;
    });

    _maxZoom = await _cameraController!.getMaxZoomLevel();

    await _cameraController!.startImageStream((image) async {
      if (_isDetecting) return;
      _isDetecting = true;

      try {
        final allBytes = WriteBuffer();
        for (final plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        final bytes = allBytes.done().buffer.asUint8List();

        final rotation = InputImageRotation.rotation90deg;
        final inputImageFormat = InputImageFormat.nv21;

        final inputImage = InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: inputImageFormat,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );

        final barcodes = await _barcodeScanner.processImage(inputImage);

        if (barcodes.isNotEmpty) {
          final code = barcodes.first.rawValue ?? 'Sin valor';
          print('✅ Código detectado: $code');

          await _cameraController?.stopImageStream();

          _mostrarCodigo(code);
        } else {
          _scanAttempts++;
          if (_scanAttempts >= _maxAttemptsBeforeZoom &&
              _currentZoom < _maxZoom) {
            _currentZoom += 0.5;
            if (_currentZoom > _maxZoom) _currentZoom = _maxZoom;
            await _cameraController!.setZoomLevel(_currentZoom);
            print('🔍 Zoom aumentado a $_currentZoom');
            _scanAttempts = 0; // reiniciar conteo
          }
        }
      } catch (e) {
        print('Error escaneando: $e');
      }

      _isDetecting = false;
    });
  }

  void _mostrarCodigo(String codigo) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => FutureBuilder<Map<String, dynamic>>(
        future: authService.getUserData(int.tryParse(codigo) ?? 0, '1'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return AlertDialog(
              title: Text('Buscando producto...'),
              content: SizedBox(
                  height: 80,
                  child: Center(
                      child: Lottie.asset(
                    'assets/loading.json',
                    width: MediaQuery.of(context).size.width * 0.2,
                    height: MediaQuery.of(context).size.height * 0.2,
                    repeat: true,
                  ))),
            );
          } else if (snapshot.hasError) {
            return AlertDialog(
              title: const Text('Error'),
              content:
                  Text('No se pudo obtener el producto: ${snapshot.error}'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _startBarcodeScanner(); // Reanudar escaneo
                  },
                  child: const Text('Intentar de nuevo'),
                ),
              ],
            );
          } else if (snapshot.hasData) {
            final data = snapshot.data!;
            debugPrint('Datos del producto: $data');
            return AlertDialog(
              title: Text(data['name'] ?? 'Producto'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Unidad: ${data['unidad']}'),
                  Text('Costo: \$${data['costo']}'),
                  if (data['img'] != null)
                    Image.network(data['img'], height: 100),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _startBarcodeScanner(); // Reanudar escaneo
                  },
                  child: const Text('Escanear otro'),
                ),
              ],
            );
          } else {
            return const AlertDialog(
              title: Text('Sin datos'),
              content: Text('No se encontró información del producto'),
            );
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _barcodeScanner.close();
    _laserAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(45.0),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0886B5),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                offset: Offset(0, 7),
                blurRadius: 4,
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios,
                  color: Colors.white, size: 19),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Center(
        child: _cameraInitialized && _cameraController != null
            ? SizedBox(
                width: 300,
                height: 200,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _cameraController!.value.previewSize!.height,
                          height: _cameraController!.value.previewSize!.width,
                          child: CameraPreview(_cameraController!),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _laserAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: 200 * _laserAnimation.value,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 2,
                            color: const Color.fromARGB(255, 255, 0, 0),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              )
            : Center(
                child: Lottie.asset(
                  'assets/loading.json',
                  width: MediaQuery.of(context).size.width * 0.2,
                  height: MediaQuery.of(context).size.height * 0.2,
                  repeat: true,
                ),
              ),
      ),
    );
  }
}
