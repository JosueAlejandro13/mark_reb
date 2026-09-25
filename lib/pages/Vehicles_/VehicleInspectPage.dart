import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/services/ConnectionInspeccion_/InspeccionCon_service.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/InspError.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

//Autor: Josue Hernandez
class VehicleInspectPage extends StatefulWidget {
  final Map<String, dynamic> vehicle;

  final String userId;
  final String plantillaId;
  final String idCollaborator;
  final int enableStorePhoto;
  final String idMainAccount;

  const VehicleInspectPage(
      {super.key,
      required this.userId,
      required this.vehicle,
      required this.idCollaborator,
      required this.plantillaId,
      required this.enableStorePhoto,
      required this.idMainAccount});

  @override
  _VehicleInspectPageState createState() => _VehicleInspectPageState();
}

class _VehicleInspectPageState extends State<VehicleInspectPage> {
  late InspeccionconService dbService;

  final ImagePicker _picker = ImagePicker();
  String? _startDateTime;
  String? _endDateTime;
  String? _selectedStatus;
  List<Map<String, dynamic>> _statuses = [];
  Map<int, bool> requirePhotoFails = {};
  bool _isLoading = false;
  bool _isLoadingCancelled = false;

  List<Map<String, dynamic>> _inspections = [];
  final TextEditingController _observationsController = TextEditingController();
  final List<TextEditingController> coments = [];

  @override
  void dispose() {
    for (var controller in coments) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchStatuses();
    _fetchInspections();
    dbService = InspeccionconService();
    for (int i = 0; i < _inspections.length; i++) {
      coments.add(TextEditingController());
    }
  }

  Future<void> _fetchStatuses() async {
    setState(() {
      _isLoading = true;
    });
    try {
      List<Map<String, dynamic>> statuses =
          await VehiclesconService().obtenerStatus();
      if (!_isLoadingCancelled && mounted) {
        setState(() {
          _statuses = statuses;
        });
      }
    } catch (e) {
      debugPrint('Error al obtener los estados: $e');
    }
  }

  Future<void> _fetchInspections() async {
    try {
      String vehicleId = widget.vehicle['id'].toString();
      String plantillaId = widget.plantillaId;

      List<Map<String, dynamic>> inspections = await InspeccionconService()
          .obtenerInspeccionesPorVehiculo(
        idVehic: vehicleId,
        idItemTemplate: plantillaId,
      )
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException("El tiempo de espera se agotó.");
      });

      if (inspections.isEmpty) {
        throw Exception("No se pudieron cargar las inspecciones.");
      }

      for (var inspection in inspections) {
        coments.add(TextEditingController());
      }

      for (var inspection in inspections.asMap().entries) {
        requirePhotoFails[inspection.key] =
            inspection.value['requirePhotoFail'];
      }

      debugPrint('ID Main Account: ${widget.idMainAccount}');
      if (!_isLoadingCancelled && mounted) {
        setState(() {
          _inspections = inspections;
          _isLoading = false;
        });
      }
    } on TimeoutException {
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
    } on SocketException {
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
    } catch (e) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => InspError(
            onRetry: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => widget),
              );
            },
          ),
        ),
      );
    }
  }

  void submitInspections() {
    for (int index = 0; index < _inspections.length; index++) {
      String comment = coments[index].text;
      debugPrint('Comentario para la inspección $index: $comment');
    }
  }

  void _cancelLoading() {
    setState(() {
      _isLoadingCancelled = true;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(30.0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Color.fromARGB(255, 0, 0, 0),
              size: 19,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(seconds: 5),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, 250, 250, 250),
                  Color.fromARGB(255, 205, 240, 255)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          _isLoading
              ? Center(
                  child: Lottie.asset(
                  'assets/loading.json',
                  height: screenHeight * 0.2,
                  width: screenWidth * 0.2,
                  repeat: true,
                ))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      Text(
                        'Inspección Vehícular',
                        style: TextStyle(
                          fontSize: screenWidth * 0.050,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _startInspection,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF0886B5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          textStyle: TextStyle(fontSize: screenWidth * 0.030),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Iniciar Revisión',
                              style: TextStyle(
                                  fontSize: screenWidth * 0.032,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            if (_startDateTime != null)
                              Text(
                                _startDateTime!,
                                style: TextStyle(
                                    fontSize: screenWidth * 0.030,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimationLimiter(
                        child: Column(
                          children: _inspections.asMap().entries.map((entry) {
                            int index = entry.key;
                            Map<String, dynamic> inspection = entry.value;

                            return AnimationConfiguration.staggeredList(
                              position: index,
                              duration: const Duration(milliseconds: 400),
                              child: SlideAnimation(
                                verticalOffset: 100.0,
                                child: FadeInAnimation(
                                  child:
                                      _buildInspectionCard(index, inspection),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              _buildObservationsField(),
                              const SizedBox(height: 12),
                              _buildStatusDropdown(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _finishInspection,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF0886B5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          textStyle: TextStyle(fontSize: screenWidth * 0.030),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Terminar Revisión',
                              style: TextStyle(
                                  fontSize: screenWidth * 0.032,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            if (_endDateTime != null)
                              Text(
                                _endDateTime!,
                                style: TextStyle(
                                    fontSize: screenWidth * 0.030,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildInspectionCard(int index, Map<String, dynamic> inspection) {
    bool isActive = inspection['isActive'] ?? false;
    String? imagePath = inspection['imagePath'];
    bool requirePhotoFail = requirePhotoFails[index] ?? false;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return AnimationConfiguration.staggeredList(
        position: index,
        duration: const Duration(milliseconds: 400),
        child: SlideAnimation(
          verticalOffset: 50.0,
          child: FadeInAnimation(
            child: Card(
              color: Colors.white,
              elevation: 5,
              margin:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            inspection['defaultItemName'] ??
                                'Nombre no disponible',
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            softWrap: true,
                          ),
                        ),
                        Transform.scale(
                          scale: 0.9,
                          child: Switch(
                            value: isActive,
                            onChanged: (value) async {
                              setState(() {
                                inspection['isActive'] = value;
                              });

                              if (!value &&
                                  requirePhotoFail &&
                                  imagePath == null) {
                                final screenWidth =
                                    MediaQuery.of(context).size.width;
                                showTopSnackBar(
                                  Overlay.of(context),
                                  Material(
                                    color: Colors.transparent,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF0886B5),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error,
                                              color: Colors.white, size: 24),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              "Debes subir una foto para esta inspección.",
                                              style: TextStyle(
                                                fontSize: screenWidth * 0.034,
                                                color: Colors.white,
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                            activeColor: Colors.green,
                            inactiveThumbColor: Colors.red,
                            inactiveTrackColor: Colors.red.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _convertToString(inspection['description']) ??
                          'Descripción no disponible',
                      style: TextStyle(
                        fontSize: screenWidth * 0.032,
                        color: const Color.fromARGB(255, 0, 0, 0),
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _convertToString(inspection['instruction']) ?? '',
                      style: TextStyle(
                        fontSize: screenWidth * 0.030,
                        color: Colors.grey[600],
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 12),
                    if (imagePath != null)
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: Image.file(
                              File(imagePath),
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                inspection['imagePath'] = null;
                              });
                            },
                            icon: const Icon(Icons.delete,
                                color: Colors.red, size: 18),
                            label: Text(
                              'Eliminar imagen',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: screenWidth * 0.030,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (!isActive)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (widget.enableStorePhoto == 1)
                            IconButton(
                              icon: const Icon(Icons.image,
                                  color: Colors.blue, size: 24),
                              onPressed: () => _pickImageFromGallery(index),
                            ),
                          if (widget.enableStorePhoto == 0)
                            IconButton(
                              icon: const Icon(Icons.camera_alt,
                                  color: Colors.red, size: 24),
                              onPressed: () => _pickImageFromCamera(index),
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: coments[index],
                      decoration: InputDecoration(
                        labelText: 'Observaciones',
                        labelStyle: TextStyle(fontSize: screenWidth * 0.030),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10.0,
                          horizontal: 12.0,
                        ),
                      ),
                      style: TextStyle(fontSize: screenWidth * 0.030),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
  }

  Future<void> _pickImageFromGallery(int index) async {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          titlePadding: EdgeInsets.zero,
          title: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(top: 23, left: 24),
                child: Text('Selecciona una opción',
                    style: TextStyle(fontSize: screenWidth * 0.040)),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 246, 246, 246),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: screenHeight * 0.040,
                      height: screenHeight * 0.040,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        iconSize: screenHeight * 0.025,
                        icon: Icon(Icons.close_rounded, color: Colors.black),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    )),
              ),
              const SizedBox(height: 45),
            ],
          ),
          content: Text(
              '¿Quieres tomar una foto o seleccionar una imagen de la galería?',
              style: TextStyle(fontSize: screenWidth * 0.033)),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF0886B5),
                foregroundColor: Colors.white,
                elevation: 6,
                shadowColor: Colors.grey.withOpacity(0.3),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Galería',
                style: TextStyle(fontSize: screenWidth * 0.030),
              ),
              onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            TextButton(
              style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF0886B5),
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor: Colors.grey.withOpacity(0.3),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: Text(
                'Cámara',
                style: TextStyle(fontSize: screenWidth * 0.030),
              ),
              onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        );
      },
    );

    if (source != null) {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _inspections[index]['imagePath'] = pickedFile.path;
          debugPrint('Imagen seleccionada: ${pickedFile.path}');
        });
      }
    }
  }

  Future<void> _pickImageFromCamera(int index) async {
    // 1. Pedir permiso de cámara
    PermissionStatus status = await Permission.camera.request();

    if (status.isDenied) {
      // Usuario negó el permiso
      debugPrint("Permiso de cámara denegado");
      final screenWidth = MediaQuery.of(context).size.width;

      showTopSnackBar(
        Overlay.of(context),
        Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "No se concedió el permiso de cámara. Por favor, actívalo en configuración.",
                    style: TextStyle(
                      fontSize: screenWidth * 0.034,
                      color: Colors.white,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        openAppSettings();
      });
      return;
    }

    if (status.isPermanentlyDenied) {
      final screenWidth = MediaQuery.of(context).size.width;

      showTopSnackBar(
        Overlay.of(context),
        Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "El permiso de cámara está bloqueado. Por favor, actívalo en configuración.",
                    style: TextStyle(
                      fontSize: screenWidth * 0.034,
                      color: Colors.white,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        openAppSettings();
      });
      return;
    }

    if (status.isGranted) {
      // 2. Si el permiso fue concedido, abrir cámara
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        setState(() {
          _inspections[index]['imagePath'] = pickedFile.path;
          debugPrint('Imagen seleccionada: ${pickedFile.path}');
        });
      }
    }
  }

  Widget _buildObservationsField() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Observaciones:', style: TextStyle(fontSize: screenWidth * 0.031)),
        SizedBox(
          height: 40,
          width: 190,
          child: TextField(
            controller: _observationsController,
            maxLines: 1,
            maxLength: 100,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: const BorderSide(color: Colors.black),
              ),
              counterText: '',
              hintText: 'Obs',
              hintStyle: TextStyle(fontSize: screenWidth * 0.029),
            ),
            style: TextStyle(fontSize: screenWidth * 0.029),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    int totalInspections = _inspections.length;

    int activeCount = _inspections
        .where((inspection) => inspection['isActive'] == true)
        .length;

    bool showFirstState = activeCount == totalInspections;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Estado:', style: TextStyle(fontSize: screenWidth * 0.031)),
        const SizedBox(width: 65),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: DropdownButton<String>(
              dropdownColor: Colors.white,
              value: _selectedStatus,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedStatus = newValue;
                });
              },
              hint: Text('Selecciona el estado',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
              items: _statuses
                  .asMap()
                  .entries
                  .where((entry) =>
                      showFirstState && entry.key < 3 ||
                      entry.key > 0 && entry.key < 3)
                  .map((entry) {
                var status = entry.value;
                return DropdownMenuItem<String>(
                  value: status['name'].toString(),
                  child: Text(status['name'].toString(),
                      style: TextStyle(fontSize: screenWidth * 0.029)),
                );
              }).toList(),
              isExpanded: true,
              underline: Container(),
              iconSize: 24,
              elevation: 16,
            ),
          ),
        ),
      ],
    );
  }

  void _startInspection() {
    setState(() {
      _startDateTime = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    });
  }

  Future<void> _finishInspection() async {
    if (_startDateTime == null) {
      final screenWidth = MediaQuery.of(context).size.width;
      showTopSnackBar(
        Overlay.of(context),
        Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF0886B5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Primero debes iniciar la revisión.",
                    style: TextStyle(
                      fontSize: screenWidth * 0.034,
                      color: Colors.white,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    if (_selectedStatus == null) {
      final screenWidth = MediaQuery.of(context).size.width;
      showTopSnackBar(
        Overlay.of(context),
        Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF0886B5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Debes seleccionar un estado antes de terminar.",
                    style: TextStyle(
                      fontSize: screenWidth * 0.034,
                      color: Colors.white,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    for (int i = 0; i < _inspections.length; i++) {
      bool requirePhotoFail = requirePhotoFails[i] ?? false;
      String? imagePath = _inspections[i]['imagePath'];
      bool isActive = _inspections[i]['isActive'] ?? false;

      if (!isActive && requirePhotoFail && imagePath == null) {
        final screenWidth = MediaQuery.of(context).size.width;
        showTopSnackBar(
          Overlay.of(context),
          Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF0886B5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Debes subir una foto para la inspección ${i + 1} antes de terminar.",
                      style: TextStyle(
                        fontSize: screenWidth * 0.034,
                        color: Colors.white,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        return;
      }
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          titlePadding: EdgeInsets.zero,
          title: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(top: 23, left: 24),
                child: Text(
                  'Finalizar Inspección',
                  style: TextStyle(
                      fontSize: screenWidth * 0.040,
                      fontWeight: FontWeight.w500),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 246, 246, 246),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: screenHeight * 0.040,
                    height: screenHeight * 0.040,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: screenHeight * 0.025,
                      icon: Icon(Icons.close_rounded, color: Colors.black),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 45),
            ],
          ),
          content: Text(
            '¿Estás seguro de que deseas terminar la inspección?',
            style: TextStyle(
              fontSize: screenWidth * 0.030,
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                elevation: 6,
                shadowColor: Colors.grey.withOpacity(0.3),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Sí, terminar',
                style: TextStyle(fontSize: screenWidth * 0.030),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _endDateTime = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    });

    await _createInspection();
  }

  Future<void> _createInspection() async {
    bool isLoading = true;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenWidth * 5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  "Creando inspección        ",
                  style: TextStyle(fontSize: screenWidth * 0.033),
                ),
              ),
              const SizedBox(width: 20),
              Lottie.asset(
                'assets/loading.json',
                height: screenHeight * 0.08,
                width: screenHeight * 0.08,
                repeat: true,
              ),
            ],
          ),
        ),
      ),
    );
    List<Map<String, dynamic>> items = [];

    for (var inspection in _inspections.asMap().entries) {
      String? idItemString = inspection.value['idItemDefault']?.toString();
      if (idItemString == null) {
        debugPrint('idItem es null para la inspección: ${inspection.value}');
        continue;
      }

      int idItem;
      try {
        idItem = int.parse(idItemString);
      } catch (e) {
        debugPrint('Error al convertir idItem a int: $e');
        continue;
      }

      int isActiveStatus = (inspection.value['isActive'] ?? false) ? 1 : 0;
      String comment = coments[inspection.key].text;

      String? imagePath = inspection.value['imagePath'];
      if (imagePath == null) {
        debugPrint(
            'No se seleccionó imagen para la inspección: ${inspection.value}');
        imagePath = '';
      }

      items.add({
        'idItem': idItem,
        'status': isActiveStatus,
        'auxval': '',
        'comment': comment,
        'imgUrl': imagePath,
      });
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      String location = '${position.latitude}, ${position.longitude}';

      int status = _statuses.firstWhere(
          (status) => status['name'] == _selectedStatus,
          orElse: () => {'id': 0})['id'];

      String idUs = widget.idMainAccount;
      String idVehic = widget.vehicle['id'].toString();
      String idTemplateInspection = widget.plantillaId;
      DateTime startDate;
      if (_startDateTime != null) {
        startDate = DateFormat('dd/MM/yyyy HH:mm').parse(_startDateTime!);
      } else {
        debugPrint('startDate es null');
        return;
      }
      DateTime endDate = DateTime.now();
      String idResponsible = widget.idCollaborator;
      int typSource = 0;
      String odomKM = _observationsController.text;
      String idSource = '0';

      await dbService.crearInspeccionYItems(
        idUs,
        idVehic,
        idTemplateInspection,
        startDate,
        endDate,
        idResponsible,
        status,
        location,
        odomKM,
        typSource,
        idSource,
        items,
      );

      Navigator.of(context).pop();
      final screenHeight = MediaQuery.of(context).size.height;
      final screenWidth = MediaQuery.of(context).size.width;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(
            "Inspección creada",
            style: TextStyle(
                fontSize: screenWidth * 0.040, fontWeight: FontWeight.w500),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "La inspección ha sido creada.",
                  style: TextStyle(
                    fontSize: screenWidth * 0.030,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0886B5),
                foregroundColor: Colors.white,
              ),
              child: Text(
                "Aceptar",
                style: TextStyle(
                  fontSize: screenWidth * 0.030,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      debugPrint('Error al crear la inspección: $e');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(
            "Error al eliminar",
            style: TextStyle(
              fontSize: screenWidth * 0.040,
            ),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Vuelva a intentarlo más tarde.",
                  style: TextStyle(
                    fontSize: screenWidth * 0.030,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF0886B5),
                foregroundColor: Colors.white,
              ),
              child: Text(
                "Reintentar",
                style: TextStyle(
                  fontSize: screenWidth * 0.030,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}

String? _convertToString(dynamic value) {
  if (value == null) return null;
  return value.toString();
}
