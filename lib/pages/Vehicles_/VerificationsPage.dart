import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bottom_picker/bottom_picker.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/pages/Error_/unexpectedErrorPage.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/services/ConnectionNotification_/NotificationCon_service.dart';
import 'package:mysql1/mysql1.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

//Autor: Josue Hernandez
class VerificationsPage extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  final String verificationsPermission;
  final String idMainAccount;
  final String userId;

  const VerificationsPage(
      {super.key,
      required this.vehicle,
      required this.verificationsPermission,
      required this.idMainAccount,
      required this.userId});

  @override
  _VerificationsPageState createState() => _VerificationsPageState();
}

class _VerificationsPageState extends State<VerificationsPage> {
  late Future<List<Map<String, dynamic>>> _verificaciones;
  late Future<List<Map<String, dynamic>>> _hologramas;
  late TextEditingController fechaVerificacionController;
  late TextEditingController proximaVerificController;
  late TextEditingController montoController;
  String? selectedHologramId;
  bool _hasVerifications = false;
  late String Type;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    fechaVerificacionController = TextEditingController();
    proximaVerificController = TextEditingController();
    montoController = TextEditingController();
    _hologramas = VehiclesconService().obtenerHolograma();

    _checkVerifications().catchError((error) {
      if (!_isDisposed && mounted) {
        _handleError(error);
      }
    });

    _TypeSource().catchError((error) {
      if (!_isDisposed && mounted) {
        _handleError(error);
      }
    });

    _verificaciones = VehiclesconService()
        .obtenerVerificacionesPorVehiculo(
            widget.vehicle['id'].toString(), widget.idMainAccount.toString())
        .then((data) async {
      if (!mounted || !mounted) return data;
      if (data.isNotEmpty) {
        var verificaciones = data[0];
        fechaVerificacionController.text =
            _formatDate(verificaciones['fecVerificacion']);
        proximaVerificController.text =
            _formatDate(verificaciones['proximaVerific']);
        montoController.text = verificaciones['monto'].toString();

        String hologramName = verificaciones['idHolograma']?.toString() ?? '';
        debugPrint('Nombre del holograma encontrado: $hologramName');

        List<Map<String, dynamic>> hologramas = await _hologramas;

        var holograma = hologramas.firstWhere(
          (h) => h['name'] == hologramName,
          orElse: () => {'id': '1'},
        );

        String hologramId = holograma['id'].toString();
        debugPrint('ID del holograma mapeado: $hologramId');

        if (!_isDisposed && mounted) {
          setState(() {
            selectedHologramId = hologramId;
            debugPrint('selectedHologramId establecido a: $selectedHologramId');
          });
        }
      }
      return data;
    }).catchError((error) {
      if (!_isDisposed && mounted) {
        _handleError(error);
      }
      return [];
    });
  }

  void _handleError(dynamic error) {
    if (_isDisposed || !mounted) return;

    if (error is SocketException) {
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
    } else if (error is TimeoutException) {
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
    } else {
      debugPrint('Error al obtener las verificaciones: $error');
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => Unexpectederrorpage(onRetry: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => widget),
                );
              })));
    }
  }

  Future<void> _TypeSource() async {
    try {
      Map<String, dynamic> data =
          await NotificationService().gettypSource("vehic_verification");

      if (!_isDisposed && mounted) {
        setState(() {
          Type = data['id'].toString();
        });
      }
    } catch (e) {
      debugPrint("Error al obtener el tipo de fuente: $e");
      if (!_isDisposed && mounted) {
        _handleError(e);
      }
    }
  }

  Future<void> _checkVerifications() async {
    List<Map<String, dynamic>> data = await VehiclesconService()
        .obtenerVerificacionesPorVehiculo(
            widget.vehicle['id'].toString(), widget.idMainAccount.toString());
    if (!_isDisposed && mounted) {
      setState(() {
        _hasVerifications = data.isNotEmpty;
      });
    }
  }

  Future<void> _refreshData() async {
    if (_isDisposed || !mounted) return;
    setState(() {
      _verificaciones = VehiclesconService().obtenerVerificacionesPorVehiculo(
          widget.vehicle['id'].toString(), widget.idMainAccount.toString());
    });
    await _checkVerifications();
  }

  @override
  void dispose() {
    _isDisposed = true;
    fechaVerificacionController.dispose();
    proximaVerificController.dispose();
    montoController.dispose();
    super.dispose();
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
            IconButton(
              icon: const Icon(Icons.drag_handle_outlined,
                  color: Color.fromARGB(255, 0, 0, 0)),
              onPressed: () {
                final List<PopupMenuEntry<String>> menuItems = [];

                if (_hasVerifications &&
                    hasEditPermission(widget.verificationsPermission)) {
                  menuItems.add(_buildPopupMenuItem(
                      context, 'edit', 'Editar', Icons.edit));
                }
                if (_hasVerifications &&
                    hasDeletePermission(widget.verificationsPermission)) {
                  menuItems.add(_buildPopupMenuItem(
                      context, 'delete', 'Eliminar', Icons.delete));
                }
                if (hasCreatePermissio(widget.verificationsPermission)) {
                  menuItems.add(_buildPopupMenuItem(
                      context, 'create', 'Crear', Icons.add));
                }

                if (menuItems.isNotEmpty) {
                  showMenu<String>(
                    context: context,
                    position: const RelativeRect.fromLTRB(1000, 80, 0, 0),
                    color: Colors.white,
                    items: menuItems,
                    elevation: 8.0,
                  ).then((value) {
                    if (value == 'edit') {
                      _updateVerification();
                    } else if (value == 'delete') {
                      _deleteVerification();
                    } else if (value == 'create') {
                      _crearVerificacion();
                    }
                  });
                }
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: Colors.black,
        onRefresh: _refreshData,
        child: Stack(
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verificaciones - ${widget.vehicle['make']} ${widget.vehicle['model']}',
                    style: TextStyle(
                      fontSize: screenWidth * 0.050,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _verificaciones,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                              child: Lottie.asset(
                            'assets/loading.json',
                            width: screenWidth * 0.2,
                            height: screenHeight * 0.2,
                            repeat: true,
                          ));
                        } else if (snapshot.hasError) {
                          return const Center(
                              child:
                                  Text('Error al cargar las verificaciones'));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return ListView(
                            children: [
                              SizedBox(
                                child: Center(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.warning_rounded,
                                        size: 64,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No se encontraron verificaciones.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.040,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Verifica que la información esté registrada',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.030,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        } else {
                          List<Map<String, dynamic>> verificaciones =
                              snapshot.data!;
                          return ListView.builder(
                              itemCount: verificaciones.length,
                              itemBuilder: (context, index) {
                                var verificacion = verificaciones[index];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _buildVerificationInfoCard(
                                      context,
                                      verificacion['idHolograma'] ??
                                          'Sin Holograma',
                                      verificacion['fecVerificacion'],
                                      verificacion['proximaVerific'],
                                      verificacion['monto'],
                                    ),
                                    const SizedBox(height: 20),
                                    _buildVigenciaCardWithIcon(verificacion),
                                  ],
                                );
                              });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteVerification() {
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
                  'Confirmar Eliminación',
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
                      onPressed: () =>
                          Navigator.of(context).pop(), // Cierra el diálogo
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 45),
            ],
          ),
          content: Text(
              '¿Estás seguro de que deseas eliminar esta verificación?',
              style: TextStyle(fontSize: screenWidth * 0.033)),
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
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Cancelar',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0886B5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              ),
              child: Text('Eliminar',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
              onPressed: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    content: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: screenWidth * 0.5,
                        ),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                "Eliminando Verificación        ",
                                style: TextStyle(fontSize: screenWidth * 0.033),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Lottie.asset(
                              "assets/loading.json",
                              height: screenHeight * 0.08,
                              width: screenHeight * 0.08,
                              repeat: true,
                            ),
                          ],
                        )),
                  ),
                );

                try {
                  List<Map<String, dynamic>> verificacion =
                      await VehiclesconService()
                          .obtenerVerificacionesPorVehiculo(
                    widget.vehicle['id'].toString(),
                    widget.idMainAccount.toString(),
                  );

                  if (verificacion.isEmpty) {
                    debugPrint("⚠ No hay idverificacion para actualizado.");
                    return;
                  }

                  int idverificacion = verificacion.first['id'];

                  String nameNotice = "vehicle_verification_deleted";
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

                  String fecVerificacion = fechaVerificacionController.text;
                  String proximaVerific = proximaVerificController.text;

                  String formattedMessage = message
                      .replaceAll("{vehicle_plate}", widget.vehicle['placas'])
                      .replaceAll("{verification_date}", fecVerificacion)
                      .replaceAll("{due_date}", proximaVerific);

                  String title = noticeTemplate['title']
                      .replaceAll("{vehicle_plate}", widget.vehicle['placas']);

                  String finalMessage =
                      "$title|$formattedMessage|${noticeTemplate['icon']}";

                  debugPrint(
                      "📢 Generando notificación por eliminar de Verificación...");

                  final notificationData = {
                    'typeSource': Type,
                    'idOrigin': idverificacion,
                    'typEvent': 3,
                    'date': DateTime.now().toIso8601String(),
                    'message': finalMessage,
                    'colNotice': 'verific_Delete',
                    'idMainAcoount': widget.idMainAccount.toString(),
                    'codUsGenerator': widget.userId.toString(),
                    'idDev': widget.userId.toString(),
                  };

                  await NotificationService()
                      .insertNotification(notificationData);

                  debugPrint("✅ Notificación enviada con éxito.");

                  await VehiclesconService().eliminarVerificacionesPorVehiculo(
                      widget.vehicle['id'].toString(),
                      widget.idMainAccount.toString());
                  setState(() {
                    _verificaciones = VehiclesconService()
                        .obtenerVerificacionesPorVehiculo(
                            widget.vehicle['id'].toString(),
                            widget.idMainAccount.toString());
                  });

                  await VehiclesconService().deleteManagementControlVf(
                    widget.idMainAccount.toString(),
                    widget.vehicle['id'].toString(),
                  );

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
                            const Icon(Icons.check,
                                color: Colors.white, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Verificación eliminada correctamente.",
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

                  Future.delayed(const Duration(milliseconds: 1), () {
                    if (mounted) {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    }
                  });
                } catch (e) {
                  debugPrint('Error al eliminar la verificación: $e');
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                  showErrorDialodel(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _crearVerificacion() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final TextEditingController montoController = TextEditingController();
    final TextEditingController fechaVerificacionController =
        TextEditingController();
    final TextEditingController proximaVerificController =
        TextEditingController();

    String? selectedHologramId;
    DateTime? fechaVerificacion;
    DateTime? proximaVerific;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.17,
          ),
          titlePadding: EdgeInsets.zero,
          title: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(top: 23, left: 24),
                child: Text(
                  'Crear Verificación',
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
                      onPressed: () =>
                          Navigator.of(context).pop(), // Cierra el diálogo
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 45),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.6,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Selecciona Holograma",
                    style: TextStyle(
                      fontSize: screenWidth * 0.031,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _hologramas,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      } else if (snapshot.hasError) {
                        return const Text('Error al cargar hologramas');
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Text('No hay hologramas disponibles');
                      } else {
                        List<Map<String, dynamic>> hologramas = snapshot.data!;
                        return SizedBox(
                          width: MediaQuery.of(context).size.width * 0.50,
                          child: DropdownButtonFormField2<String>(
                            value: selectedHologramId,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 13, horizontal: 12),
                              prefixIcon: const Icon(
                                Icons.local_activity,
                                size: 15,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide:
                                    const BorderSide(color: Colors.black),
                              ),
                            ),
                            isExpanded: true,
                            items: hologramas.map((holograma) {
                              return DropdownMenuItem<String>(
                                value: holograma['id'].toString(),
                                child: Text(
                                  holograma['name'],
                                  style:
                                      TextStyle(fontSize: screenWidth * 0.031),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedHologramId = value;
                              });
                            },
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
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Fecha de Verificación",
                    style: TextStyle(
                      fontSize: screenWidth * 0.031,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.50,
                    child: GestureDetector(
                      onTap: () async {
                        fechaVerificacion = await _selectDate(
                            context, fechaVerificacionController);
                        if (fechaVerificacion != null) {
                          fechaVerificacionController.text =
                              DateFormat('yyyy-MM-dd')
                                  .format(fechaVerificacion!);
                        }
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          controller: fechaVerificacionController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.calendar_today,
                              size: 15,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                          ),
                          readOnly: true,
                          style: TextStyle(fontSize: screenWidth * 0.031),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Próxima Verificación",
                    style: TextStyle(
                      fontSize: screenWidth * 0.031,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.50,
                    child: GestureDetector(
                      onTap: () async {
                        proximaVerific = await _selectDate(
                            context, proximaVerificController);
                        if (proximaVerific != null) {
                          proximaVerificController.text =
                              DateFormat('yyyy-MM-dd').format(proximaVerific!);
                        }
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          controller: proximaVerificController,
                          decoration: InputDecoration(
                            prefixIcon:
                                const Icon(Icons.calendar_today, size: 15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                          ),
                          readOnly: true,
                          style: TextStyle(fontSize: screenWidth * 0.031),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Monto",
                    style: TextStyle(
                      fontSize: screenWidth * 0.031,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.50,
                    child: TextField(
                      controller: montoController,
                      decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.attach_money, size: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(color: Colors.black),
                          ),
                          isDense: true,
                          counterText: ''),
                      keyboardType: TextInputType.number,
                      maxLength: 12,
                      style: TextStyle(fontSize: screenWidth * 0.031),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                elevation: 6,
                shadowColor: Colors.grey.withOpacity(0.3),
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancelar',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (fechaVerificacionController.text.isEmpty ||
                    proximaVerificController.text.isEmpty) {
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
                                "Por favor ingrese todas las fechas.",
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

                final fechaVerificacion =
                    DateTime.tryParse(fechaVerificacionController.text);
                final proximaVerificacion =
                    DateTime.tryParse(proximaVerificController.text);

                if (fechaVerificacion == null || proximaVerificacion == null) {
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
                                "Por favor ingrese fechas válidas.",
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

                if (fechaVerificacion.isAfter(proximaVerificacion)) {
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
                                "La fecha de verificación no puede ser mayor que la próxima verificacións.",
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
                                "Creando Verificación      ",
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
                  await VehiclesconService().crearVerificacion(
                    widget.vehicle['id'].toString(),
                    selectedHologramId ?? '',
                    widget.vehicle['idMainAccount'].toString(),
                    fechaVerificacionController.text,
                    proximaVerificController.text,
                    double.tryParse(montoController.text) ?? 0.0,
                    '1',
                  );

                  setState(() {
                    _verificaciones =
                        VehiclesconService().obtenerVerificacionesPorVehiculo(
                      widget.vehicle['id'].toString(),
                      widget.idMainAccount.toString(),
                    );
                  });

                  List<Map<String, dynamic>> verificacion =
                      await VehiclesconService()
                          .obtenerVerificacionesPorVehiculo(
                    widget.vehicle['id'].toString(),
                    widget.idMainAccount.toString(),
                  );

                  if (verificacion.isEmpty) {
                    debugPrint("⚠ No hay idverificacion para actualizado.");
                    return;
                  }

                  int idverificacion = verificacion.first['id'];

                  String nameNotice = "vehicle_verification_added";
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

                  String fecVerificacion = fechaVerificacionController.text;
                  String proximaVerific = proximaVerificController.text;

                  String formattedMessage = message
                      .replaceAll("{vehicle_plate}", widget.vehicle['placas'])
                      .replaceAll("{verification_date}", fecVerificacion)
                      .replaceAll("{due_date}", proximaVerific);

                  String title = noticeTemplate['title']
                      .replaceAll("{vehicle_plate}", widget.vehicle['placas']);

                  String finalMessage =
                      "$title|$formattedMessage|${noticeTemplate['icon']}";

                  debugPrint(
                      "📢 Generando notificación por actualizado de Verificación...");

                  final notificationData = {
                    'typeSource': Type,
                    'idOrigin': idverificacion,
                    'typEvent': 1,
                    'date': DateTime.now().toIso8601String(),
                    'message': finalMessage,
                    'colNotice': 'verific_New',
                    'idMainAcoount': widget.idMainAccount.toString(),
                    'codUsGenerator': widget.userId.toString(),
                    'idDev': widget.userId.toString(),
                  };

                  await NotificationService()
                      .insertNotification(notificationData);

                  await VehiclesconService().insertManagementControlVf(
                      widget.idMainAccount.toString(),
                      widget.vehicle['id'].toString(),
                      DateFormat('yyyy-MM-dd')
                          .parse(proximaVerificController.text));

                  Navigator.of(context).pop();
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
                            const Icon(Icons.check,
                                color: Colors.white, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Verificación creada correctamente.",
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

                  Navigator.of(context).pop();
                } catch (e) {
                  debugPrint('Error al crear la verificación: $e');
                  Navigator.of(context).pop();
                  showErrorDialog(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0886B5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              ),
              child: Text('Crear Verificación',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
            ),
          ],
        );
      },
    );
  }

  void _updateVerification() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    String? dialogHologramId = selectedHologramId;
    debugPrint('Initial dialog hologramId: $dialogHologramId');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        DateTime? fechaVerificacion;
        DateTime? proximaVerific;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.17,
              ),
              titlePadding: EdgeInsets.zero,
              title: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 23, left: 24),
                    child: Text(
                      'Actualizar Verificación',
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
                          onPressed: () =>
                              Navigator.of(context).pop(), // Cierra el diálogo
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 45),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Holograma",
                        style: TextStyle(
                          fontSize: screenWidth * 0.031,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _hologramas,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          } else if (snapshot.hasError) {
                            return const Text('Error al cargar hologramas');
                          } else if (!snapshot.hasData ||
                              snapshot.data!.isEmpty) {
                            return const Text('No hay hologramas disponibles');
                          }

                          debugPrint(
                              'Hologramas disponibles: ${snapshot.data}');

                          bool exists = snapshot.data!.any(
                              (h) => h['id'].toString() == dialogHologramId);
                          if (!exists) {
                            dialogHologramId =
                                snapshot.data![0]['id'].toString();
                          }

                          return SizedBox(
                            width: MediaQuery.of(context).size.width *
                                0.50, // Ajusta el porcentaje como desees
                            child: DropdownButtonFormField2<String>(
                              value: dialogHologramId,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 13, horizontal: 12),
                                prefixIcon:
                                    const Icon(Icons.local_activity, size: 15),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  borderSide:
                                      const BorderSide(color: Colors.black),
                                ),
                              ),
                              items: snapshot.data!.map((holograma) {
                                debugPrint(
                                    'Creando item para holograma: ${holograma['id']} - ${holograma['name']}');
                                return DropdownMenuItem<String>(
                                  value: holograma['id'].toString(),
                                  child: Text(
                                    holograma['name'],
                                    style: TextStyle(
                                        fontSize: screenWidth * 0.031),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? value) {
                                setState(() {
                                  dialogHologramId = value;
                                  selectedHologramId = value;
                                  debugPrint('Selected new value: $value');
                                });
                              },
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
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Fecha de Verificación",
                        style: TextStyle(
                          fontSize: screenWidth * 0.031,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.50,
                        child: TextField(
                          controller: fechaVerificacionController,
                          style: TextStyle(fontSize: screenWidth * 0.031),
                          decoration: InputDecoration(
                            prefixIcon:
                                const Icon(Icons.calendar_today, size: 15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                          ),
                          readOnly: true,
                          onTap: () async {
                            fechaVerificacion = await _selectDate(
                                context, fechaVerificacionController);
                            if (fechaVerificacion != null) {
                              setState(() {
                                fechaVerificacionController.text =
                                    DateFormat('dd/MM/yyyy')
                                        .format(fechaVerificacion!);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Próxima Verificación",
                        style: TextStyle(
                          fontSize: screenWidth * 0.031,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.50,
                        child: TextField(
                          controller: proximaVerificController,
                          style: TextStyle(fontSize: screenWidth * 0.031),
                          decoration: InputDecoration(
                            prefixIcon:
                                const Icon(Icons.calendar_today, size: 15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                          ),
                          readOnly: true,
                          onTap: () async {
                            proximaVerific = await _selectDate(
                                context, proximaVerificController);
                            if (proximaVerific != null) {
                              setState(() {
                                proximaVerificController.text =
                                    DateFormat('dd/MM/yyyy')
                                        .format(proximaVerific!);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Monto",
                        style: TextStyle(
                          fontSize: screenWidth * 0.031,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.50,
                        child: TextField(
                          controller: montoController,
                          style: TextStyle(fontSize: screenWidth * 0.031),
                          decoration: InputDecoration(
                              prefixIcon:
                                  const Icon(Icons.attach_money, size: 15),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide:
                                    const BorderSide(color: Colors.black),
                              ),
                              isDense: true,
                              counterText: ''),
                          keyboardType: TextInputType.number,
                          maxLength: 12,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancelar',
                    style: TextStyle(fontSize: screenWidth * 0.030),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
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
                                  style:
                                      TextStyle(fontSize: screenWidth * 0.033),
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

                    try {
                      String? fechaVerificacionText =
                          fechaVerificacionController.text;
                      String? proximaVerificText =
                          proximaVerificController.text;

                      String fechaVerificacionFormatted = '';
                      if (fechaVerificacionText != null &&
                          fechaVerificacionText.isNotEmpty) {
                        try {
                          fechaVerificacionFormatted =
                              DateFormat('yyyy-MM-dd').format(
                            DateFormat('dd/MM/yyyy')
                                .parse(fechaVerificacionText),
                          );
                        } catch (e) {
                          fechaVerificacionFormatted = fechaVerificacionText;
                        }
                      }

                      String proximaVerificFormatted = '';
                      if (proximaVerificText != null &&
                          proximaVerificText.isNotEmpty) {
                        try {
                          proximaVerificFormatted =
                              DateFormat('yyyy-MM-dd').format(
                            DateFormat('dd/MM/yyyy').parse(proximaVerificText),
                          );
                        } catch (e) {
                          proximaVerificFormatted = proximaVerificText;
                        }
                      }
                      await VehiclesconService()
                          .actualizarVerificacionPorVehiculo(
                        widget.vehicle['id'].toString(),
                        widget.idMainAccount.toString(),
                        dialogHologramId ?? '',
                        fechaVerificacionFormatted,
                        proximaVerificFormatted,
                        double.parse(montoController.text),
                      );

                      if (mounted) {
                        setState(() {
                          selectedHologramId = dialogHologramId;
                        });

                        this.setState(() {
                          _verificaciones = VehiclesconService()
                              .obtenerVerificacionesPorVehiculo(
                                  widget.vehicle['id'].toString(),
                                  widget.idMainAccount.toString())
                              .then((data) async {
                            if (data.isNotEmpty) {
                              var verificaciones = data[0];
                              fechaVerificacionController.text = _formatDate(
                                  verificaciones['fecVerificacion']);
                              proximaVerificController.text =
                                  _formatDate(verificaciones['proximaVerific']);
                              montoController.text =
                                  verificaciones['monto'].toString();
                              selectedHologramId =
                                  verificaciones['idHolograma']?.toString();
                            }
                            return data;
                          });
                        });
                      }

                      List<Map<String, dynamic>> verificacion =
                          await VehiclesconService()
                              .obtenerVerificacionesPorVehiculo(
                        widget.vehicle['id'].toString(),
                        widget.idMainAccount.toString(),
                      );

                      if (verificacion.isEmpty) {
                        debugPrint("⚠ No hay idverificacion para actualizado.");
                        return;
                      }

                      int idverificacion = verificacion.first['id'];

                      String nameNotice = "vehicle_verification_updated";
                      Map<String, dynamic>? noticeTemplate =
                          await NotificationService()
                              .getNoticeByName(nameNotice);

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

                      String fecVerificacion = fechaVerificacionController.text;
                      String proximaVerific = proximaVerificController.text;

                      String formattedMessage = message
                          .replaceAll(
                              "{vehicle_plate}", widget.vehicle['placas'])
                          .replaceAll("{verification_date}", proximaVerific)
                          .replaceAll("{due_date}", fecVerificacion);

                      String title = noticeTemplate['title'].replaceAll(
                          "{vehicle_plate}", widget.vehicle['placas']);

                      String finalMessage =
                          "$title|$formattedMessage|${noticeTemplate['icon']}";

                      debugPrint(
                          "📢 Generando notificación por crear de Verificación...");

                      final notificationData = {
                        'typeSource': Type,
                        'idOrigin': idverificacion,
                        'typEvent': 2,
                        'date': DateTime.now().toIso8601String(),
                        'message': finalMessage,
                        'colNotice': 'verific_Edit',
                        'idMainAcoount': widget.idMainAccount.toString(),
                        'codUsGenerator': widget.userId.toString(),
                        'idDev': widget.userId.toString(),
                      };

                      await NotificationService()
                          .insertNotification(notificationData);

                      debugPrint("✅ Notificación enviada con éxito.");

                      await VehiclesconService().updateManagementControlVf(
                          widget.idMainAccount.toString(),
                          widget.vehicle['id'].toString(),
                          proximaVerificController.text);

                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
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
                                const Icon(Icons.check,
                                    color: Colors.white, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Verificación actualizada exitosamente.",
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
                      debugPrint('Error al actualizar la verificación: $e');
                      Navigator.of(context).pop();
                      showErrorDialogup(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0886B5),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  ),
                  child: Text(
                    'Actualizar ',
                    style: TextStyle(fontSize: screenWidth * 0.030),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<DateTime?> _selectDate(
      BuildContext context, TextEditingController controller) async {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final completer = Completer<DateTime?>();

    DateTime initialDate;
    try {
      initialDate = controller.text.isNotEmpty
          ? DateFormat('yyyy-MM-dd').parse(controller.text)
          : DateTime.now();
    } catch (_) {
      initialDate = DateTime.now();
    }

    BottomPicker.date(
      pickerTitle: Text(
        'Selecciona una fecha',
        style: TextStyle(fontSize: screenWidth * 0.037),
      ),
      pickerDescription: SizedBox(height: screenHeight * 0.03),
      initialDateTime: initialDate,
      minDateTime: DateTime(2000),
      maxDateTime: DateTime(2101),
      pickerTextStyle:
          TextStyle(fontSize: screenWidth * 0.050, color: Colors.black),
      onSubmit: (selectedDate) {
        completer.complete(selectedDate);
        controller.text = DateFormat('yyyy-MM-dd').format(selectedDate);
      },
      onCloseButtonPressed: () {
        completer.complete(null);
      },
      displayCloseIcon: true,
      buttonContent: const Icon(Icons.check, color: Colors.white),
      buttonStyle: BoxDecoration(
        color: Color(0xFF0886B5),
        borderRadius: BorderRadius.circular(12),
      ),
      buttonWidth: 50,
      buttonPadding: 10,
    ).show(context);

    return completer.future;
  }

  String _formatDate(dynamic date) {
    if (date is DateTime) {
      return DateFormat('yyyy-MM-dd').format(date);
    } else if (date is String) {
      try {
        DateTime parsedDate = DateFormat('dd/MM/yyyy').parse(date);
        return DateFormat('yyyy-MM-dd').format(parsedDate);
      } catch (e) {
        return date;
      }
    }
    return '';
  }

  Widget _buildVerificationInfoCard(BuildContext context, String hologram,
      dynamic fecVerificacion, dynamic proximaVerific, double monto) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_activity, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Holograma: ',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  hologram,
                  style: TextStyle(
                      fontSize: screenWidth * 0.032, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Divider(),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Fecha de Verificación: ',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_formatDate(fecVerificacion)} ',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032, color: Colors.grey[700]),
                )
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Próxima Verificación: ',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  // ignore: unnecessary_string_interpolations
                  '${_formatDate(proximaVerific)}',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032, color: Colors.grey[700]),
                )
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.attach_money, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Monto: ',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  currencyFormat.format(monto),
                  style: TextStyle(
                      fontSize: screenWidth * 0.032, color: Colors.grey[700]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  final NumberFormat currencyFormat = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 2,
  );

  PopupMenuEntry<String> _buildPopupMenuItem(
      BuildContext context, String value, String title, IconData icon) {
    final screenWidth = MediaQuery.of(context).size.width;

    return PopupMenuItem<String>(
      value: value,
      padding: EdgeInsets.zero, // Elimina el padding interno por defecto
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(icon, size: screenWidth * 0.04, color: Colors.black),
              const SizedBox(width: 15),
              Text(
                title,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: screenWidth * 0.030,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVigenciaCardWithIcon(Map<String, dynamic> data) {
    final screenWidth = MediaQuery.of(context).size.width;
    String? fechaVencimiento = data['proximaVerific']?.toString();
    String vigenciaTexto;
    Color vigenciaColor;
    IconData vigenciaIcon;

    if (fechaVencimiento == null || fechaVencimiento.isEmpty) {
      vigenciaTexto = 'Sin fecha de vencimiento';
      vigenciaColor = Colors.grey[600]!;
      vigenciaIcon = Icons.check_circle;
    } else {
      DateTime vencimiento = DateFormat('yyyy-MM-dd').parse(fechaVencimiento);
      Duration diferencia = vencimiento.difference(DateTime.now());

      if (diferencia.inDays > 0) {
        vigenciaTexto = 'Proxima Verificacion en ${diferencia.inDays} dias';
        vigenciaColor = Colors.green;
        vigenciaIcon = Icons.date_range;
      } else if (diferencia.inDays == 0) {
        vigenciaTexto = 'Hoy es el dia de verificacion';
        vigenciaColor = Colors.orange;
        vigenciaIcon = Icons.warning;
      } else {
        vigenciaTexto =
            'Verificacion vencida hace ${diferencia.inDays.abs()} dias';
        vigenciaColor = Colors.red;
        vigenciaIcon = Icons.error;
      }
    }
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      color: vigenciaColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              vigenciaIcon,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                vigenciaTexto,
                style: TextStyle(
                  fontSize: screenWidth * 0.033,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showErrorDialog(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          "Error al crear",
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
                "Vuelva a intentarlo más tarde.",
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
            },
            style: ElevatedButton.styleFrom(
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

  void showErrorDialogup(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          "Error al actualizar",
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
                "Vuelva a intentarlo más tarde.",
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
            },
            style: ElevatedButton.styleFrom(
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

  void showErrorDialodel(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          "Error al eliminar",
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
                "Vuelva a intentarlo más tarde.",
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
            },
            style: ElevatedButton.styleFrom(
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

  bool hasEditPermission(String permission) {
    return (int.parse(permission) & 8) == 8 || (int.parse(permission) & 1) == 1;
  }

  bool hasDeletePermission(String permission) {
    return (int.parse(permission) & 16) == 16 ||
        (int.parse(permission) & 1) == 1;
  }

  bool hasCreatePermissio(String permission) {
    return (int.parse(permission) & 4) == 4 || (int.parse(permission) & 1) == 1;
  }
}
