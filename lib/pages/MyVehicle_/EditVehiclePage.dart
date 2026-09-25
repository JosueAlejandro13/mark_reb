import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/pages/MyVehicle_/MyVehiclePage.dart';
import 'package:mark_v3/services/ConnectionMyVehicle_/MyVehicleCon_service.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/services/ConnectionProfile_/ProfileCon_service.dart';
import 'package:mark_v3/services/ConnectionNotification_/NotificationCon_service.dart';
import 'package:mysql1/mysql1.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../Error_/unexpectedErrorPage.dart';

//Autor: Josue Hernandez
class EditVehiclePage extends StatefulWidget {
  final Vehicle vehicle;
  final String userId;
  final String idMainAccount;
  final String idCollaborator;

  // ignore: prefer_const_constructors_in_immutables
  EditVehiclePage({
    super.key,
    required this.vehicle,
    required this.userId,
    required this.idMainAccount,
    required this.idCollaborator,
  });

  @override
  _EditVehiclePageState createState() => _EditVehiclePageState();
}

class _EditVehiclePageState extends State<EditVehiclePage> {
  late MyvehicleconService dbService;

  late TextEditingController placasController;
  late TextEditingController vinController;
  late TextEditingController makeController;
  late TextEditingController modelController;
  late TextEditingController yearController;
  late TextEditingController cilindradaController;
  late TextEditingController nCilindrosController;
  late TextEditingController promConsumoController;
  late TextEditingController capacidadTanqueController;
  late TextEditingController colorController;
  late String Type;
  TextEditingController obsController = TextEditingController();
  late String Types;

  String? selectedTiposVehiculo;
  String? selectedobtenerEngomados;
  String? selectedTipoCombustible;
  String? selectedStatus;
  String? selectedMarca;
  String? selectedModelo;

  // ignore: non_constant_identifier_names
  List<Map<String, dynamic>> TiposVehiculo = [];

  List<Map<String, dynamic>> obtenerEngomados = [];
  // ignore: non_constant_identifier_names
  List<Map<String, dynamic>> TipoCombustible = [];
  // ignore: non_constant_identifier_names
  List<Map<String, dynamic>> EstadosVehiculo = [];

  List<Map<String, dynamic>> obtenerModel = [];

  List<Map<String, dynamic>> obtenerMake = [];

  Map<String, dynamic> profile = {};
  bool isLoading = true;
  bool isLoadingCancelled = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    dbService = MyvehicleconService();
    placasController = TextEditingController(text: widget.vehicle.placas);
    vinController = TextEditingController(text: widget.vehicle.vin);
    makeController = TextEditingController(text: widget.vehicle.make);
    modelController = TextEditingController(text: widget.vehicle.model);
    yearController =
        TextEditingController(text: widget.vehicle.year.toString());
    cilindradaController =
        TextEditingController(text: widget.vehicle.cilindrada.toString());
    nCilindrosController =
        TextEditingController(text: widget.vehicle.nCilindros.toString());
    colorController = TextEditingController(text: widget.vehicle.color);
    promConsumoController =
        TextEditingController(text: widget.vehicle.promConsumo.toString());
    capacidadTanqueController =
        TextEditingController(text: widget.vehicle.capacidadTanque.toString());

    _initializeData();
    _TypeSource();
    _TypeSources();
  }

  Future<void> _initializeData() async {
    try {
      await _loadDataAsync();
      _loadVehicleData();
    } catch (e) {
      if (!isLoadingCancelled) {}
    } finally {
      if (!isLoadingCancelled && mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _TypeSource() async {
    try {
      Map<String, dynamic> data =
          await NotificationService().gettypSource('vehic_data');
      debugPrint("🔹 Tipo de fuente: $data");

      if (!_isDisposed && mounted) {
        setState(() {
          Type = data['id'].toString();
        });
      }
    } catch (e) {
      debugPrint("Error en TypeSoruce: $e");
    }
  }

  Future<void> _TypeSources() async {
    try {
      Map<String, dynamic> data = await NotificationService()
          .gettypSource('vehic_historicalStatusVehicles');
      debugPrint("🔹 Tipo de fuente: $data");
      if (!_isDisposed && mounted) {
        setState(() {
          Types = data['id'].toString();
        });
      }
    } catch (e) {
      debugPrint("Error en typeSource History: $e");
    }
  }

  Future<void> _loadDataAsync() async {
    try {
      final catalogos = await dbService.obtenerCatalogosVehiculo();

      TiposVehiculo = catalogos['vehicType']!;
      obtenerEngomados = catalogos['engomados']!;
      TipoCombustible = catalogos['vehicFuel']!;
      EstadosVehiculo = catalogos['vehicStatus']!;
      obtenerMake = catalogos['make']!;

      profile = await ProfileconService()
          .getUserData(widget.idCollaborator, widget.idMainAccount);
      debugPrint("$profile}");
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
    } catch (e) {
      if (!isLoadingCancelled) {
        debugPrint("Error al cargar datos: $e");
        print("Tipo de error: ${e.runtimeType}");

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => Unexpectederrorpage(
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
    }
  }

  void _cancelLoading() {
    setState(() {
      isLoadingCancelled = true;
      isLoading = false;
    });
  }

  Future<void> _loadModelsForMake(int makeId) async {
    try {
      obtenerModel = await dbService.obtenerModel(makeId);
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        debugPrint("Error al cargar modelos para la marca $makeId: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar modelos')),
        );
      }
    }
  }

  void _loadVehicleData() {
    if (mounted) {
      placasController.text = widget.vehicle.placas;
      vinController.text = widget.vehicle.vin;
      makeController.text = widget.vehicle.make;
      modelController.text = widget.vehicle.model;
      yearController.text = widget.vehicle.year.toString();
      cilindradaController.text = widget.vehicle.cilindrada.toString();
      nCilindrosController.text = widget.vehicle.nCilindros.toString();
      promConsumoController.text = widget.vehicle.promConsumo.toString();
      capacidadTanqueController.text =
          widget.vehicle.capacidadTanque.toString().toString();
      colorController.text = widget.vehicle.color;

      setState(() {
        // Marca
        var makeItem = obtenerMake.firstWhere(
          (make) => make['name'] == (widget.vehicle.make),
          orElse: () => {'id': "0"},
        );
        selectedMarca = (makeItem['id']?.toString() ?? "0");

        debugPrint("🔧 Marca encontrada: $selectedMarca");

        if (selectedMarca != "0") {
          _loadModelsForMake(int.parse(selectedMarca!)).then((_) {
            if (mounted) {
              var modelItem = obtenerModel.firstWhere(
                (model) => model['name'] == (widget.vehicle.model),
                orElse: () => {'id': "0"},
              );
              selectedModelo = (modelItem['id']?.toString() ?? "0");
              debugPrint("🚗 Modelo encontrado: $selectedModelo");
            }
          });
        }

        var tipoVehiculoItem = TiposVehiculo.firstWhere(
          (tipo) => tipo['name'] == (widget.vehicle.tipoVehiculoNombre),
          orElse: () => {'id': "0"},
        );
        selectedTiposVehiculo = (tipoVehiculoItem['id']?.toString() ?? "0");
        debugPrint("🚙 Tipo de vehículo: $selectedTiposVehiculo");

        var combustibleItem = TipoCombustible.firstWhere(
          (tipo) => tipo['name'] == (widget.vehicle.tipoCombustibleNombre),
          orElse: () => {'id': "0"},
        );
        selectedTipoCombustible = (combustibleItem['id']?.toString() ?? "0");
        debugPrint("⛽ Tipo de combustible: $selectedTipoCombustible");

        var statusItem = EstadosVehiculo.firstWhere(
          (status) => status['name'] == (widget.vehicle.Status),
          orElse: () => {'id': "0"},
        );
        selectedStatus = (statusItem['id']?.toString() ?? "0");
        debugPrint("📄 Status: $selectedStatus");

        int currentStatusID = int.tryParse(selectedStatus!) ?? 0;
      });
    }
  }

  void _saveChanges() async {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    int currentStatusID = int.tryParse(selectedStatus ?? '0') ?? 0;

    if (selectedModelo == null || selectedModelo == "0") {
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
                    "Por favor, selecciona un modelo.",
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

    try {
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
                    "Guardando cambios        ",
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

      debugPrint('ID del vehículo a actualizar: ${widget.vehicle.id}');

      Map<String, dynamic> vehicleData = {
        'idvehic': widget.vehicle.id,
        'placas': placasController.text,
        'vin': vinController.text,
        'make': makeController.text,
        'model': modelController.text,
        'year': int.tryParse(yearController.text) ?? 0,
        'cilindrada': cilindradaController.text.isNotEmpty
            ? cilindradaController.text
            : '0',
        'nCilindros': nCilindrosController.text.isNotEmpty
            ? nCilindrosController.text
            : '0',
        'promConsumo': promConsumoController.text.isNotEmpty
            ? promConsumoController.text
            : '0',
        'capacidadTanque': capacidadTanqueController.text.isNotEmpty
            ? capacidadTanqueController.text
            : '0',
        'color': colorController.text.isNotEmpty ? colorController.text : '',
        'idTypVehic': selectedTiposVehiculo ?? '0',
        'idTypFuel': selectedTipoCombustible ?? '0',
        'idMake': selectedMarca ?? '0',
        'idModel': selectedModelo ?? '0',
      };

      await dbService.updateVehicleT(
        vehicleData,
        widget.idMainAccount,
      );

      String nameNotice = "vehicle_data_edited";
      Map<String, dynamic>? noticeTemplate =
          await NotificationService().getNoticeByName(nameNotice);

      if (noticeTemplate == null) {
        debugPrint(
            "⚠ No se encontró la plantilla de notificación con nameNotice: $nameNotice");
        return;
      }

      List<int> messageBytes;
      if (noticeTemplate['message'] is Blob) {
        messageBytes = await (noticeTemplate['message'] as Blob).toBytes();
      } else if (noticeTemplate['message'] is List<int>) {
        messageBytes = noticeTemplate['message'] as List<int>;
      } else {
        debugPrint("⚠ El campo 'message' no es un Blob ni una lista de bytes.");
        return;
      }

      String message;
      try {
        message = utf8.decode(messageBytes);
      } catch (e) {
        debugPrint("Error al decodificar el mensaje: $e");
        return;
      }

      String formattedMessage = message;

      String title = noticeTemplate['title']
          .replaceAll("{vehicle_plate}", placasController.text);

      String finalMessage =
          "$title|$formattedMessage|${noticeTemplate['icon']}";

      debugPrint("📢 Generando notificación por edit vehic...");

      final notificationData = {
        'typeSource': Type,
        'idOrigin': widget.vehicle.id.toString(),
        'typEvent': 2,
        'date': DateTime.now().toIso8601String(),
        'message': finalMessage,
        'colNotice': 'vehic_Update',
        'idMainAcoount': widget.idMainAccount.toString(),
        'codUsGenerator': widget.userId.toString(),
        'idDev': widget.userId.toString(),
      };

      await NotificationService().insertNotification(notificationData);

      debugPrint("✅ Notificación enviada con éxito.");
      Navigator.of(context).pop();
      Navigator.pop(context, true);
      debugPrint("Vehículo actualizado exitosamente.");
      showTopSnackBar(
        Overlay.of(context),
        Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 0, 155, 85),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Vehículo actualizado exitosamente.",
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
    } catch (e) {
      debugPrint('Error al actualizar el vehículo: $e');
      Navigator.of(context).pop();
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
                    "Error al guardar cambios. Intente nuevamente más tarde.",
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
  }

  @override
  void dispose() {
    _isDisposed = true;
    placasController.dispose();
    vinController.dispose();
    makeController.dispose();
    modelController.dispose();
    yearController.dispose();
    cilindradaController.dispose();
    nCilindrosController.dispose();
    promConsumoController.dispose();
    capacidadTanqueController.dispose();
    colorController.dispose();
    isLoadingCancelled = true;
    super.dispose();
  }

  void _showChangeStatusDialog() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          titlePadding: EdgeInsets.zero,
          title: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(top: 23, left: 24),
                child: Text(
                  'Cambiar Estado',
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
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDropdown(
                  selectedStatus,
                  'Estado',
                  EstadosVehiculo,
                  (newValue) {
                    setState(() {
                      selectedStatus = newValue;
                    });
                  },
                  icon: Icon(FontAwesomeIcons.circleCheck.data,
                      color: Colors.black),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  height: 100,
                  child: TextField(
                    controller: obsController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      labelText: 'Observaciones',
                      labelStyle: TextStyle(
                          color: Colors.black, fontSize: screenWidth * 0.032),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide:
                            const BorderSide(color: Colors.black, width: 1.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide:
                            const BorderSide(color: Colors.black, width: 1.5),
                      ),
                      isDense: true,
                      counterText: "",
                    ),
                    maxLength: 100,
                    style: TextStyle(
                        color: Colors.black, fontSize: screenWidth * 0.032),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor: Colors.grey.withOpacity(0.3),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancelar',
                style: TextStyle(fontSize: screenWidth * 0.030),
              ),
            ),
            TextButton(
              onPressed: () async {
                if (selectedStatus == null || selectedStatus!.isEmpty) {
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
                            const Icon(Icons.error,
                                color: Colors.white, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Por favor, selecciona un estado.",
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

                if (obsController.text.isEmpty) {
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
                            const Icon(Icons.error,
                                color: Colors.white, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Por favor, ingresa las observaciones.",
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

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return AlertDialog(
                      content: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: screenWidth * 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                "Cambiando Status      ",
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
                    );
                  },
                );

                int selectedStatusInt =
                    int.tryParse(selectedStatus.toString()) ?? -1;
                int vehicleStatusInt =
                    int.tryParse(widget.vehicle.idStatus.toString()) ?? -1;

                if (selectedStatusInt != vehicleStatusInt) {
                  debugPrint(
                      "🔄 Cambio de estado detectado, registrando en historial...");

                  await NotificationService().insertStatus(
                    widget.userId.toString(),
                    widget.vehicle.id.toString(),
                    obsController.text,
                    DateTime.now(),
                    selectedStatus.toString(),
                    "0",
                    "0",
                  );

                  debugPrint(
                      "✅ Estado del vehículo registrado en el historial.");
                } else {
                  debugPrint(
                      "⚠ No hubo cambio de estado, no se inserta en historial.");
                }

                await MyvehicleconService().updatevehicleStatus(
                  selectedStatus.toString(),
                  widget.vehicle.id.toString(),
                );

                String nameNotice = "vehicle_status_changed";
                Map<String, dynamic>? noticeTemplate =
                    await NotificationService().getNoticeByName(nameNotice);

                if (noticeTemplate == null) {
                  debugPrint(
                      "⚠ No se encontró la plantilla de notificación con nameNotice: $nameNotice");
                  return;
                }

                List<int> messageBytes;
                if (noticeTemplate['message'] is Blob) {
                  messageBytes =
                      await (noticeTemplate['message'] as Blob).toBytes();
                } else if (noticeTemplate['message'] is List<int>) {
                  messageBytes = noticeTemplate['message'] as List<int>;
                } else {
                  debugPrint(
                      "⚠ El campo 'message' no es un Blob ni una lista de bytes.");
                  return;
                }

                String message;
                try {
                  message = utf8.decode(messageBytes);
                } catch (e) {
                  debugPrint("Error al decodificar el mensaje: $e");
                  return;
                }

                String formattedMessage = message
                    .replaceAll("{new_status}", selectedStatus.toString())
                    .replaceAll("{user}", profile['email'])
                    .replaceAll("{observations}", obsController.text);

                String title = noticeTemplate['title']
                    .replaceAll("{vehicle_plate}", placasController.text);

                String finalMessage =
                    "$title|$formattedMessage|${noticeTemplate['icon']}";

                debugPrint("📢 Generando notificación por cambio de status...");

                final notificationData = {
                  'typeSource': Types,
                  'idOrigin': widget.vehicle.id.toString(),
                  'typEvent': 2,
                  'date': DateTime.now().toIso8601String(),
                  'message': finalMessage,
                  'colNotice': 'vehic_Status',
                  'idMainAcoount': widget.idMainAccount.toString(),
                  'codUsGenerator': widget.userId.toString(),
                  'idDev': widget.userId.toString(),
                };

                await NotificationService()
                    .insertNotification(notificationData);

                debugPrint("✅ Notificación enviada con éxito.");

                Navigator.of(context).pop();

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    title: Text(
                      "Estado Actualizado",
                      style: TextStyle(
                          fontSize: screenWidth * 0.040,
                          fontWeight: FontWeight.w500),
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
                            "El estado del vehículo ha sido actualizado exitosamente.",
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
                          Navigator.of(context).pop();
                          Navigator.of(context).pop(true);
                        },
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
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0886B5),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: Text(
                'Guardar Estado',
                style: TextStyle(fontSize: screenWidth * 0.030),
              ),
            ),
          ],
        );
      },
    );
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
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.build_circle_outlined,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
              color: Colors.white,
              position: PopupMenuPosition.under,
              onSelected: (value) {
                if (value == 'Cambiar Status') {
                  _showChangeStatusDialog();
                }
              },
              itemBuilder: (BuildContext context) {
                if (isLoading) {
                  return []; // Mientras se carga, no mostrar opciones
                }

                return <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'Cambiar Status',
                    child: AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20.0, vertical: 12.0),
                        child: Text(
                          'Cambiar Status',
                          style: TextStyle(fontSize: screenWidth * 0.030),
                        ),
                      ),
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
      body: isLoading
          ? Center(
              child: Lottie.asset(
                'assets/loading.json',
                width: screenWidth * 0.2,
                height: screenWidth * 0.2,
                repeat: true,
              ),
            )
          : Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(12.0, 12.0, 10.0, 0.1),
                    child: Text(
                      'Editar Vehículo',
                      style: TextStyle(
                        fontSize: screenWidth * 0.050,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Card(
                        elevation: 0,
                        color: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color.fromARGB(255, 250, 250, 250),
                                Color.fromARGB(255, 205, 240, 255)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: ListView(
                              children: [
                                _buildMarcaDropdown(),
                                SizedBox(height: 5),
                                _buildModeloDropdown(),
                                SizedBox(height: 5),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        yearController,
                                        'Año',
                                        Icons.calendar_today,
                                        maxLength: 4,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _buildTextField(
                                        placasController,
                                        'Placas',
                                        FontAwesomeIcons.rectangleAd.data,
                                        maxLength: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        vinController,
                                        'VIN',
                                        Icons.vpn_key,
                                        maxLength: 17,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _buildTextField(
                                        colorController,
                                        'Color',
                                        Icons.color_lens,
                                        maxLength: 20,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5),
                                _buildDropdown(
                                  selectedTiposVehiculo,
                                  'Tipo Vehículo',
                                  TiposVehiculo,
                                  (newValue) {
                                    setState(() {
                                      selectedTiposVehiculo = newValue ?? '';
                                    });
                                  },
                                  icon: const Icon(Icons.directions_car,
                                      color: Colors.black),
                                ),
                                SizedBox(height: 5),
                                _buildDropdown(
                                  selectedTipoCombustible,
                                  'Tipo de Combustible',
                                  TipoCombustible,
                                  (newValue) {
                                    setState(() {
                                      selectedTipoCombustible = newValue;
                                    });
                                  },
                                  icon: const Icon(Icons.local_gas_station,
                                      color: Colors.black),
                                ),
                                SizedBox(height: 5),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                          cilindradaController,
                                          'Cilindrada',
                                          FontAwesomeIcons.cogs.data,
                                          maxLength: 10),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildTextField(
                                          nCilindrosController,
                                          'Número de Cilindros',
                                          FontAwesomeIcons.cogs.data,
                                          maxLength: 10),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                          promConsumoController,
                                          'Promedio de Consumo',
                                          Icons.speed,
                                          maxLength: 10),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildTextField(
                                          capacidadTanqueController,
                                          'Capacidad del Tanque',
                                          Icons.local_shipping,
                                          maxLength: 10),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.center,
                                  child: SizedBox(
                                    width: 200,
                                    child: ElevatedButton(
                                      onPressed: _saveChanges,
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor:
                                            const Color(0xFF0886B5),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                      child: Text(
                                        'Guardar Cambios',
                                        style: TextStyle(
                                            fontSize: screenWidth * 0.030),
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
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {required int maxLength}) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.0),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        decoration: InputDecoration(
            labelText: label,
            labelStyle:
                TextStyle(color: Colors.black, fontSize: screenWidth * 0.031),
            prefixIcon: Icon(
              icon,
              color: const Color.fromARGB(255, 0, 0, 0),
              size: screenWidth * 0.05,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true, // Fondo lleno
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: const BorderSide(
                color: Color.fromARGB(255, 0, 0, 0),
                width: 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: const BorderSide(
                color: Colors.black,
                width: 1.5,
              ),
            ),
            isDense: true,
            counterText: ""),
        style: TextStyle(color: Colors.black, fontSize: screenWidth * 0.031),
      ),
    );
  }

  Widget _buildMarcaDropdown() {
    return _buildDropdown(
      selectedMarca,
      'Marca',
      obtenerMake,
      _onMarcaChanged,
      icon: const Icon(
        Icons.directions_car,
        color: Colors.black,
      ),
    );
  }

  void _onMarcaChanged(String? newValue) {
    setState(() {
      selectedMarca = newValue;
      selectedModelo = null;
      modelController.text = '';
    });

    if (selectedMarca != null) {
      Future.delayed(const Duration(milliseconds: 200), () async {
        if (selectedMarca == newValue) {
          makeController.text = obtenerMake
                  .firstWhere(
                    (make) => make['id'].toString() == selectedMarca,
                    orElse: () => {'name': ''},
                  )['name']
                  ?.toString() ??
              '';
          await _loadModelsForMake(int.parse(selectedMarca!));

          if (mounted && obtenerModel.isNotEmpty) {
            setState(() {
              selectedModelo = null;
            });
          }
        }
      });
    }
  }

  Widget _buildModeloDropdown() {
    return _buildDropdown(
      selectedModelo,
      'Modelo',
      obtenerModel,
      (newValue) {
        setState(() {
          selectedModelo = newValue;
          if (selectedModelo != null) {
            modelController.text = obtenerModel
                    .firstWhere(
                      (model) => model['id'].toString() == selectedModelo,
                      orElse: () => {'name': ''},
                    )['name']
                    ?.toString() ??
                '';
          }
        });
      },
      icon: const Icon(
        Icons.car_repair,
        color: Colors.black,
      ),
    );
  }

  Widget _buildDropdown(
    String? selectedItem,
    String hint,
    List<Map<String, dynamic>> items,
    ValueChanged<String?> onChanged, {
    required Icon icon,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: DropdownButtonFormField2<String>(
        isExpanded: true,
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
          fillColor: Colors.white,
          filled: true,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color.fromARGB(255, 0, 0, 0), width: 1),
          ),
          labelText: hint,
          labelStyle: TextStyle(
            fontSize: screenWidth * 0.031,
            color: Colors.black,
          ),
        ),
        value: selectedItem,
        onChanged: onChanged,
        items: [
          const DropdownMenuItem<String>(
            value: "0",
            child: Text('Seleccione una opción'),
          ),
          ...items.map((Map<String, dynamic> item) {
            return DropdownMenuItem<String>(
              value: item['id'].toString(),
              child: Row(
                children: [
                  if (selectedItem == item['id'].toString()) ...[
                    icon,
                    const SizedBox(width: 8),
                  ],
                  Text(item['name']?.toString() ?? ''),
                ],
              ),
            );
          }),
        ],
        isDense: true,
        style: TextStyle(
          color: Colors.black,
          fontSize: screenWidth * 0.031,
        ),
        buttonStyleData: const ButtonStyleData(
          padding: EdgeInsets.only(right: 8),
        ),
        iconStyleData: const IconStyleData(
          icon: Icon(
            Icons.arrow_drop_down,
            color: Colors.black45,
          ),
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.white,
          ),
        ),
        menuItemStyleData: const MenuItemStyleData(
          padding: EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}
