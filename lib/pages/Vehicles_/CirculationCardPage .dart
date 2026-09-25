import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bottom_picker/bottom_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/pages/Error_/unexpectedErrorPage.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';
import 'package:intl/intl.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/services/ConnectionNotification_/NotificationCon_service.dart';
import 'package:mysql1/mysql1.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

//Autor: Josue Hernandez
class CirculationCardPage extends StatefulWidget {
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
  _CirculationCardPageState createState() => _CirculationCardPageState();
}

class _CirculationCardPageState extends State<CirculationCardPage> {
  late Future<Map<String, dynamic>?> _tarjetaCirculacion;

  late TextEditingController _numTarjetaController;
  late TextEditingController _fecExpedicionController;
  late TextEditingController _fecVencimientoController;
  late TextEditingController _montoController;
  bool _hasCirculationCard = false;
  late String Type;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _numTarjetaController = TextEditingController();
    _fecExpedicionController = TextEditingController();
    _fecVencimientoController = TextEditingController();
    _montoController = TextEditingController();

    _checkCirculationCard().catchError((error) {
      if (!_isDisposed && mounted) {
        _handleError(error);
      }
    });

    _TypeSource().catchError((error) {
      if (!_isDisposed && mounted) {
        _handleError(error);
      }
    });
    debugPrint('ID del vehículo a buscar: ${widget.vehicle['id']}');

    _tarjetaCirculacion = VehiclesconService()
        .obtenerTarjetaCirculacion(
            widget.vehicle['id'].toString(), widget.idMainAccount.toString())
        .then((data) {
      debugPrint('Tarjeta de circulación obtenida: $data');
      return data;
    }).catchError((error) {
      if (error is SocketException) {
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
      } else if (error is TimeoutException) {
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
      } else {
        debugPrint('Error al obtener la tarjeta de circulación: $error');
        if (mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (context) => Unexpectederrorpage(
                    onRetry: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => widget),
                      );
                    },
                  )));
        }
      }
      return null;
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
      debugPrint('Error al obtener los impuestos: $error');
    }
  }

  Future<void> _TypeSource() async {
    if (_isDisposed || !mounted) return;
    try {
      Map<String, dynamic> data =
          await NotificationService().gettypSource("vehic_circulationCard");

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

  Future<void> _checkCirculationCard() async {
    final data = await VehiclesconService().obtenerTarjetaCirculacion(
        widget.vehicle['id'].toString(), widget.idMainAccount.toString());

    if (!_isDisposed && mounted) {
      setState(() {
        _hasCirculationCard = data != null && data.isNotEmpty;
      });
    }
  }

  Future<void> _refreshData() async {
    if (_isDisposed || !mounted) return;
    setState(() {
      _tarjetaCirculacion = VehiclesconService().obtenerTarjetaCirculacion(
          widget.vehicle['id'].toString(), widget.idMainAccount.toString());
    });
    await _checkCirculationCard();
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
                  color: Color.fromARGB(255, 0, 0, 0), size: 25),
              onPressed: () {
                final List<PopupMenuEntry<String>> menuItems = [];

                if (_hasCirculationCard &&
                    hasEditPermission(widget.circulationCardPermission)) {
                  menuItems.add(_buildPopupMenuItem(
                      context, 'edit', 'Editar', Icons.edit));
                }
                if (_hasCirculationCard &&
                    hasDeletePermission(widget.circulationCardPermission)) {
                  menuItems.add(_buildPopupMenuItem(
                      context, 'delete', 'Eliminar', Icons.delete));
                }
                if (hasCreatePermissio(widget.circulationCardPermission)) {
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
                      _updateCirculationCard();
                    } else if (value == 'delete') {
                      _deleteCirculationCard();
                    } else if (value == 'create') {
                      _mostrarDialogoCrearTarjetaCirculacion();
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
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tarjeta de Circulación - ${widget.vehicle['make']}',
                      style: TextStyle(
                        fontSize: screenWidth * 0.050,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _tarjetaCirculacion,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return SizedBox(
                            height: MediaQuery.of(context).size.height * 0.8,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Lottie.asset(
                                    'assets/loading.json',
                                    width: screenWidth * 0.2,
                                    height: screenWidth * 0.2,
                                    repeat: true,
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        } else if (snapshot.hasData && snapshot.data != null) {
                          _numTarjetaController.text =
                              snapshot.data!['numTarjeta']?.toString() ?? '';
                          _fecExpedicionController.text =
                              snapshot.data!['fecExpedicion']?.toString() ?? '';
                          _fecVencimientoController.text =
                              snapshot.data!['fecVencimiento']?.toString() ??
                                  '';
                          _montoController.text =
                              snapshot.data!['monto']?.toString() ?? '';

                          return Padding(
                            padding: const EdgeInsets.all(1.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 12),
                                Card(
                                  elevation: 4,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildCardDetail(
                                            'Número de Tarjeta:',
                                            snapshot.data!['numTarjeta']
                                                    ?.toString() ??
                                                'N/A',
                                            Icons.credit_card),
                                        const Divider(),
                                        _buildCardDetail(
                                            'Fecha de Expedición:',
                                            snapshot.data!['fecExpedicion']
                                                    ?.toString() ??
                                                'N/A',
                                            Icons.calendar_today),
                                        const SizedBox(width: 8),
                                        _buildCardDetail(
                                            'Fecha de Vencimiento:',
                                            snapshot.data!['fecVencimiento']
                                                    ?.toString() ??
                                                'N/A',
                                            Icons.calendar_today),
                                        const SizedBox(width: 8),
                                        _buildCardDetail(
                                          'Monto:',
                                          currencyFormat
                                              .format(snapshot.data!['monto']),
                                          Icons.attach_money,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _buildVigenciaCardWithIcon(snapshot.data!),
                              ],
                            ),
                          );
                        } else {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 15),
                                Icon(
                                  Icons.warning_rounded,
                                  size: 64,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No se encontró la tarjeta de circulación.',
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
                                const SizedBox(height: 20),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
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

  void _mostrarDialogoCrearTarjetaCirculacion() {
    final TextEditingController numTarjetaController = TextEditingController();
    final TextEditingController montoController = TextEditingController();
    final TextEditingController fechaExpedicionController =
        TextEditingController();
    final TextEditingController fechaVencimientoController =
        TextEditingController();

    DateTime? fechaExpedicion;
    DateTime? fechaVencimiento;

    var loadingDialog = showDialog(
      context: context,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;
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
                  'Crear Nueva Tarjeta',
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
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Número de Tarjeta",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: TextField(
                    controller: numTarjetaController,
                    decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.credit_card, size: 15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        isDense: true,
                        counterText: ''),
                    style: TextStyle(fontSize: screenWidth * 0.031),
                    keyboardType: TextInputType.number,
                    maxLength: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Fecha de Expedición",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: TextField(
                    controller: fechaExpedicionController,
                    readOnly: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.calendar_today, size: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    style: TextStyle(fontSize: screenWidth * 0.031),
                    onTap: () async {
                      final screenHeight = MediaQuery.of(context).size.height;
                      final screenWidth = MediaQuery.of(context).size.width;

                      BottomPicker.date(
                        pickerTitle: Text(
                          "Selecciona la fecha de Expedición",
                          style: TextStyle(fontSize: screenWidth * 0.037),
                        ),
                        dismissable: true,
                        pickerDescription:
                            SizedBox(height: screenHeight * 0.03),
                        initialDateTime: DateTime.now(),
                        minDateTime: DateTime(2000),
                        maxDateTime: DateTime(2101),
                        pickerTextStyle: TextStyle(
                            fontSize: screenWidth * 0.050, color: Colors.black),
                        onSubmit: (selectedDate) {
                          setState(() {
                            fechaExpedicion = selectedDate;
                            fechaExpedicionController.text =
                                "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}";
                          });
                        },
                        onCloseButtonPressed: () {
                          print("Picker cerrado");
                        },
                        displayCloseIcon: true,
                        buttonContent:
                            const Icon(Icons.check, color: Colors.white),
                        buttonStyle: BoxDecoration(
                          color: const Color(0xFF0886B5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        buttonWidth: 50,
                        buttonPadding: 10,
                      ).show(context);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Fecha de Vencimiento",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: TextField(
                      controller: fechaVencimientoController,
                      readOnly: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.calendar_today, size: 15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      style: TextStyle(fontSize: screenWidth * 0.031),
                      onTap: () async {
                        final screenHeight = MediaQuery.of(context).size.height;
                        final screenWidth = MediaQuery.of(context).size.width;

                        BottomPicker.date(
                          pickerTitle: Text(
                            "Selecciona la fecha de vencimiento",
                            style: TextStyle(fontSize: screenWidth * 0.037),
                          ),
                          dismissable: true,
                          pickerDescription:
                              SizedBox(height: screenHeight * 0.03),
                          initialDateTime: DateTime.now(),
                          minDateTime: DateTime(2000),
                          maxDateTime: DateTime(2101),
                          pickerTextStyle: TextStyle(
                              fontSize: screenWidth * 0.050,
                              color: Colors.black),
                          onSubmit: (selectedDate) {
                            setState(() {
                              fechaVencimiento = selectedDate;
                              fechaVencimientoController.text =
                                  "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}";
                            });
                          },
                          onCloseButtonPressed: () {
                            print("Picker cerrado");
                          },
                          displayCloseIcon: true,
                          buttonContent:
                              const Icon(Icons.check, color: Colors.white),
                          buttonStyle: BoxDecoration(
                            color: Color(0xFF0886B5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          buttonWidth: 50,
                          buttonPadding: 10,
                        ).show(context);
                      }),
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
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: TextField(
                    controller: montoController,
                    decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.attach_money, size: 15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        isDense: true,
                        counterText: ''),
                    style: TextStyle(fontSize: screenWidth * 0.031),
                    maxLength: 12,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                    ],
                  ),
                ),
              ],
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
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
            ),
            ElevatedButton(
              onPressed: () async {
                showLoadingDialog(context);

                if (numTarjetaController.text.isNotEmpty &&
                    montoController.text.isNotEmpty &&
                    fechaExpedicion != null &&
                    fechaVencimiento != null) {
                  try {
                    DateTime fechaExpedicionUTC = fechaExpedicion!.toUtc();
                    DateTime fechaVencimientoUTC = fechaVencimiento!.toUtc();

                    await VehiclesconService().crearTarjetaCirculacion(
                      widget.vehicle['id'].toString(),
                      widget.vehicle['idMainAccount'].toString(),
                      numTarjetaController.text,
                      fechaExpedicionUTC,
                      fechaVencimientoUTC,
                      double.parse(montoController.text),
                    );

                    setState(() {
                      _tarjetaCirculacion = VehiclesconService()
                          .obtenerTarjetaCirculacion(
                              widget.vehicle['id'].toString(),
                              widget.idMainAccount.toString());
                    });

                    Map<String, dynamic>? circu =
                        await VehiclesconService().obtenerTarjetaCirculacion(
                      widget.vehicle['id'].toString(),
                      widget.idMainAccount.toString(),
                    );

                    if (circu == null || circu.isEmpty) {
                      debugPrint("⚠ No hay impuestos para eliminar.");
                      return;
                    }

                    if (circu['id'] == null) {
                      debugPrint("⚠ El ID de la circulación es nulo.");
                      return;
                    }

                    int idcircu = circu['id'];

                    debugPrint("📌 circulación con ID: $idcircu");

                    String nameNotice = "vehicle_registration_card_added";
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
                        .replaceAll("{vehicle_plate}", widget.vehicle['placas'])
                        .replaceAll("{card_number}", numTarjetaController.text)
                        .replaceAll(
                            "{issue_date}", fechaExpedicionController.text)
                        .replaceAll(
                            "{expiry_date}", fechaVencimientoController.text);

                    String title = noticeTemplate['title'].replaceAll(
                        "{vehicle_plate}", widget.vehicle['placas']);

                    String finalMessage =
                        "$title|$formattedMessage|${noticeTemplate['icon']}";

                    final notificationData = {
                      'typeSource': Type,
                      'idOrigin': idcircu,
                      'typEvent': 1,
                      'date': DateTime.now().toIso8601String(),
                      'message': finalMessage,
                      'colNotice': 'tc_New',
                      'idMainAcoount': widget.idMainAccount.toString(),
                      'codUsGenerator': widget.userId.toString(),
                      'idDev': widget.userId.toString(),
                    };

                    await NotificationService()
                        .insertNotification(notificationData);

                    await VehiclesconService().insertManagementControlTJ(
                      widget.vehicle['idMainAccount'].toString(),
                      widget.vehicle['id'].toString(),
                      fechaVencimientoUTC,
                    );

                    if (mounted) {
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
                                    "Tarjeta de circulación creada exitosamente.",
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
                  } catch (e) {
                    if (mounted) Navigator.of(context).pop();
                    showErrorDialog(context);
                  }
                } else {
                  if (mounted) Navigator.of(context).pop();

                  if (mounted) {
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
                                  "Por favor, complete todos los campos.",
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
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0886B5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              ),
              child: Text('Crear Tarjeta',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
            ),
          ],
        );
      },
    );
  }

  void showLoadingDialog(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenWidth * 0.5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  "Creando tarjeta de circulación        ",
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
  }

  void _createCirculationCard() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          titlePadding: EdgeInsets.zero,
          title: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(top: 23, left: 24),
                child: Text(
                  'Crear Nueva Tarjeta',
                  style: TextStyle(fontSize: screenWidth * 0.037),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  iconSize: screenHeight * 0.025,
                  icon: Icon(Icons.close_rounded, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(height: 45),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _numTarjetaController,
                  decoration: InputDecoration(
                      labelText: 'Número de Tarjeta',
                      labelStyle: TextStyle(fontSize: screenWidth * 0.031),
                      isDense: true,
                      counterText: ''),
                  maxLength: 20,
                  style: TextStyle(fontSize: screenWidth * 0.031),
                ),
                TextFormField(
                  controller: _fecExpedicionController,
                  decoration: InputDecoration(
                    labelText: 'Fecha de Expedición',
                    labelStyle: TextStyle(fontSize: screenWidth * 0.031),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        DateTime? selectedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Transform.scale(
                                scale: 0.9,
                                child: child,
                              );
                            });
                        if (selectedDate != null) {
                          _fecExpedicionController.text =
                              selectedDate.toIso8601String().substring(0, 10);
                        }
                      },
                    ),
                  ),
                  style: TextStyle(fontSize: screenWidth * 0.031),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor seleccione la fecha de expedición';
                    }
                    final fechaExpedicion = DateTime.parse(value);
                    if (_fecVencimientoController.text.isNotEmpty) {
                      final fechaVencimiento =
                          DateTime.parse(_fecVencimientoController.text);
                      if (fechaExpedicion.isAfter(fechaVencimiento)) {
                        return 'La fecha de expedición no puede ser mayor que la fecha de vencimiento';
                      }
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _fecVencimientoController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Fecha de Vencimiento',
                    labelStyle: TextStyle(fontSize: screenWidth * 0.031),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final screenHeight = MediaQuery.of(context).size.height;
                        final screenWidth = MediaQuery.of(context).size.width;

                        BottomPicker.date(
                          pickerTitle: Text(
                            'Selecciona la fecha de vencimiento',
                            style: TextStyle(fontSize: screenWidth * 0.037),
                          ),
                          pickerDescription:
                              SizedBox(height: screenHeight * 0.03),
                          initialDateTime: DateTime.now(),
                          minDateTime: DateTime(2000),
                          maxDateTime: DateTime(2100),
                          pickerTextStyle: TextStyle(
                              fontSize: screenWidth * 0.050,
                              color: Colors.black),
                          onSubmit: (selectedDate) {
                            setState(() {
                              _fecVencimientoController.text = selectedDate
                                  .toIso8601String()
                                  .substring(0, 10);
                            });
                          },
                          onCloseButtonPressed: () {
                            print("picker closed");
                          },
                          displayCloseIcon: true,
                          buttonContent:
                              const Icon(Icons.check, color: Colors.white),
                          buttonStyle: BoxDecoration(
                            color: Color(0xFF0886B5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          buttonWidth: 50,
                          buttonPadding: 10,
                        ).show(context);
                      },
                    ),
                  ),
                  style: TextStyle(fontSize: screenWidth * 0.031),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor seleccione la fecha de vencimiento';
                    }
                    final fechaVencimiento = DateTime.parse(value);
                    if (_fecExpedicionController.text.isNotEmpty) {
                      final fechaExpedicion =
                          DateTime.parse(_fecExpedicionController.text);
                      if (fechaVencimiento.isBefore(fechaExpedicion)) {
                        return 'La fecha de vencimiento no puede ser menor que la fecha de expedición';
                      }
                    }
                    return null;
                  },
                ),
                TextField(
                  controller: _montoController,
                  decoration: InputDecoration(
                    labelText: 'Monto',
                    labelStyle: TextStyle(fontSize: screenWidth * 0.031),
                  ),
                  style: TextStyle(fontSize: screenWidth * 0.031),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
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
                              "Creando tarjeta de circulación        ",
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

                try {
                  int idMainAccount = widget.vehicle['idMainAccount'];
                  int vehicleId = widget.vehicle['id'];

                  await VehiclesconService().crearNuevaTarjetaCirculacion(
                    idMainAccount,
                    vehicleId,
                    _numTarjetaController.text,
                    DateTime.parse(_fecExpedicionController.text),
                    DateTime.parse(_fecVencimientoController.text),
                    double.tryParse(_montoController.text) ?? 0.0,
                  );

                  Navigator.of(context).pop();
                  Navigator.of(context).pop();

                  setState(() {
                    _tarjetaCirculacion = VehiclesconService()
                        .obtenerTarjetaCirculacion(
                            widget.vehicle['id'].toString(),
                            widget.idMainAccount.toString());
                  });
                } catch (error) {
                  Navigator.of(context).pop();
                  debugPrint('Error al crear la tarjeta: $error');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0886B5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              ),
              child: Text(
                'Crear',
                style: TextStyle(fontSize: screenWidth * 0.030),
              ),
            ),
          ],
        );
      },
    );
  }

  void _updateCirculationCard() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final tempNumTarjeta =
        TextEditingController(text: _numTarjetaController.text);
    final tempFecExpedicion =
        TextEditingController(text: _formatDate(_fecExpedicionController.text));

    final tempFecVencimiento = TextEditingController(
      text: _fecVencimientoController.text.isNotEmpty
          ? _formatDate(_fecVencimientoController.text)
          : '',
    );

    final tempMonto = TextEditingController(text: _montoController.text);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.17, // Más margen a los lados
          ),
          titlePadding: EdgeInsets.zero,
          title: Stack(children: [
            Padding(
              padding: EdgeInsets.only(top: 23, left: 24),
              child: Text(
                'Actualizar Tarjeta',
                style: TextStyle(
                    fontSize: screenWidth * 0.040, fontWeight: FontWeight.w500),
              ),
            ),
            Positioned(
              right: 8, // Agrega un pequeño margen
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
                ),
              ),
            ),
            const SizedBox(height: 45),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Número de Tarjeta
                Text(
                  "Número de Tarjeta",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: TextField(
                    controller: tempNumTarjeta,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.credit_card, size: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      isDense: true,
                      counterText: '',
                    ),
                    style: TextStyle(fontSize: screenWidth * 0.031),
                    keyboardType: TextInputType.number,
                    maxLength: 20,
                  ),
                ),
                const SizedBox(height: 8),

                // Fecha de Expedición
                Text(
                  "Fecha de Expedición",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: TextField(
                    controller: tempFecExpedicion,
                    readOnly: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.calendar_today, size: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    style: TextStyle(fontSize: screenWidth * 0.031),
                    onTap: () async {
                      final screenHeight = MediaQuery.of(context).size.height;
                      final screenWidth = MediaQuery.of(context).size.width;

                      BottomPicker.date(
                        pickerTitle: Text(
                          "Selecciona la fecha de expedición",
                          style: TextStyle(fontSize: screenWidth * 0.037),
                        ),
                        pickerDescription:
                            SizedBox(height: screenHeight * 0.03),
                        initialDateTime: tempFecExpedicion.text.isNotEmpty
                            ? DateFormat('dd/MM/yyyy')
                                .parse(tempFecExpedicion.text)
                            : DateTime.now(),
                        minDateTime: DateTime(2000),
                        maxDateTime: DateTime(2101),
                        pickerTextStyle: TextStyle(
                            fontSize: screenWidth * 0.050, color: Colors.black),
                        onSubmit: (selectedDate) {
                          setState(() {
                            tempFecExpedicion.text =
                                "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}";
                          });
                        },
                        onCloseButtonPressed: () {
                          print("Picker cerrado");
                        },
                        displayCloseIcon: true,
                        buttonContent:
                            const Icon(Icons.check, color: Colors.white),
                        buttonStyle: BoxDecoration(
                          color: const Color(0xFF0886B5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        buttonWidth: 50,
                        buttonPadding: 10,
                      ).show(context);
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Fecha de Vencimiento
                Text(
                  "Fecha de Vencimiento",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: TextField(
                    controller: tempFecVencimiento,
                    readOnly: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.calendar_today, size: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    style: TextStyle(fontSize: screenWidth * 0.031),
                    onTap: () async {
                      final screenHeight = MediaQuery.of(context).size.height;
                      final screenWidth = MediaQuery.of(context).size.width;

                      BottomPicker.date(
                        pickerTitle: Text(
                          "Selecciona la fecha de vencimiento",
                          style: TextStyle(fontSize: screenWidth * 0.037),
                        ),
                        pickerDescription:
                            SizedBox(height: screenHeight * 0.03),
                        initialDateTime: tempFecVencimiento.text.isNotEmpty
                            ? DateFormat('dd/MM/yyyy')
                                .parse(tempFecVencimiento.text)
                            : DateTime.now(),
                        minDateTime: DateTime(2000),
                        maxDateTime: DateTime(2101),
                        pickerTextStyle: TextStyle(
                            fontSize: screenWidth * 0.050, color: Colors.black),
                        onSubmit: (selectedDate) {
                          setState(() {
                            tempFecVencimiento.text =
                                "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}";
                          });
                        },
                        onCloseButtonPressed: () {
                          print("Picker cerrado");
                        },
                        displayCloseIcon: true,
                        buttonContent:
                            const Icon(Icons.check, color: Colors.white),
                        buttonStyle: BoxDecoration(
                          color: const Color(0xFF0886B5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        buttonWidth: 50,
                        buttonPadding: 10,
                      ).show(context);
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Monto
                Text(
                  "Monto",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: TextField(
                    controller: tempMonto,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.attach_money, size: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      isDense: true,
                      counterText: '',
                    ),
                    style: TextStyle(fontSize: screenWidth * 0.031),
                    keyboardType: TextInputType.number,
                    maxLength: 11,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                    ],
                  ),
                ),
              ],
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
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    content: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: screenWidth * 0.5,
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
                          const SizedBox(width: 7),
                          Lottie.asset(
                            "assets/loading.json",
                            height: screenHeight * 0.08,
                            width: screenHeight * 0.08,
                            repeat: true,
                          )
                        ],
                      ),
                    ),
                  ),
                );

                try {
                  _numTarjetaController.text = tempNumTarjeta.text;
                  _fecExpedicionController.text = tempFecExpedicion.text;
                  _fecVencimientoController.text = tempFecVencimiento.text;
                  _montoController.text = tempMonto.text;

                  final monto = double.tryParse(tempMonto.text);

                  if (monto == null) {
                    debugPrint(
                        'Monto ingresado no es válido: ${tempMonto.text}');
                    Navigator.of(context).pop();
                    return;
                  }

                  VehiclesconService()
                      .actualizarTarjetaCirculacion(
                    widget.vehicle['id'] as int,
                    int.parse(widget.idMainAccount),
                    tempNumTarjeta.text,
                    DateFormat('yyyy-MM-dd').format(
                        DateFormat('dd/MM/yyyy').parse(tempFecExpedicion.text)),
                    DateFormat('yyyy-MM-dd').format(DateFormat('dd/MM/yyyy')
                        .parse(tempFecVencimiento.text)),
                    monto,
                  )
                      .then((_) async {
                    setState(() {
                      _tarjetaCirculacion = VehiclesconService()
                          .obtenerTarjetaCirculacion(
                              widget.vehicle['id'].toString(),
                              widget.idMainAccount.toString());
                    });

                    Map<String, dynamic>? circu =
                        await VehiclesconService().obtenerTarjetaCirculacion(
                      widget.vehicle['id'].toString(),
                      widget.idMainAccount.toString(),
                    );

                    if (circu == null || circu.isEmpty) {
                      debugPrint("⚠ No hay impuestos para eliminar.");
                      return;
                    }

                    if (circu['id'] == null) {
                      debugPrint("⚠ El ID de la circulación es nulo.");
                      return;
                    }

                    int idcircu = circu['id'];

                    String nameNotice = "vehicle_registration_card_updated";
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
                        .replaceAll("{vehicle_plate}", widget.vehicle['placas'])
                        .replaceAll("{card_number}", tempNumTarjeta.text)
                        .replaceAll("{issue_date}", tempFecExpedicion.text)
                        .replaceAll("{expiry_date}", tempFecVencimiento.text);

                    String title = noticeTemplate['title'].replaceAll(
                        "{vehicle_plate}", widget.vehicle['placas']);

                    String finalMessage =
                        "$title|$formattedMessage|${noticeTemplate['icon']}";

                    debugPrint(
                        "📢 Generando notificación por actualizado de impuestos...");

                    final notificationData = {
                      'typeSource': Type,
                      'idOrigin': idcircu,
                      'typEvent': 2,
                      'date': DateTime.now().toIso8601String(),
                      'message': finalMessage,
                      'colNotice': 'tc_Edit',
                      'idMainAcoount': widget.idMainAccount.toString(),
                      'codUsGenerator': widget.userId.toString(),
                      'idDev': widget.userId.toString(),
                    };

                    await NotificationService()
                        .insertNotification(notificationData);

                    await VehiclesconService().updateManagementControlTJ(
                      int.parse(widget.idMainAccount),
                      widget.vehicle['id']! as int,
                      DateFormat('yyyy-MM-dd').format(DateFormat('dd/MM/yyyy')
                          .parse(tempFecVencimiento.text)),
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
                                  "Tarjeta de circulación actualizada exitosamente.",
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
                    Navigator.of(context).pop(true);
                  }).catchError((error) {
                    debugPrint('Error al actualizar la tarjeta: $error');
                    Navigator.of(context).pop();
                    showErrorDialogup(context);
                  });
                } catch (e) {
                  debugPrint('Error inesperado: $e');
                  Navigator.of(context).pop();
                  showErrorDialogup(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0886B5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Actualizar Tarjeta',
                style: TextStyle(fontSize: screenWidth * 0.030),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(String date) {
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(date));
    } catch (e) {
      return date;
    }
  }

  void _deleteCirculationCard() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final currentContext = context;

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
                  'Eliminar Tarjeta',
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
                    color: const Color.fromARGB(
                        255, 246, 246, 246), // Fondo gris claro
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
                  ),
                ),
              ),
              const SizedBox(height: 45),
            ],
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar esta tarjeta de circulación?',
            style: TextStyle(fontSize: screenWidth * 0.033),
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
            TextButton(
              onPressed: () async {
                var loadingDialog = showDialog(
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
                              "Eliminando tarjeta de circulación       ",
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
                      ),
                    ),
                  ),
                );

                try {
                  Map<String, dynamic>? circu =
                      await VehiclesconService().obtenerTarjetaCirculacion(
                    widget.vehicle['id'].toString(),
                    widget.idMainAccount.toString(),
                  );

                  if (circu == null || circu.isEmpty) {
                    debugPrint("⚠ No hay impuestos para eliminar.");
                    return;
                  }

                  if (circu['id'] == null) {
                    debugPrint("⚠ El ID de la circulación es nulo.");
                    return;
                  }

                  int idcircu = circu['id'];

                  debugPrint("📌 Eliminando circulación con ID: $idcircu");

                  await VehiclesconService().eliminarTarjetaCirculacion(
                    widget.vehicle['id'].toString(),
                    widget.idMainAccount.toString(),
                  );

                  String nameNotice = "vehicle_registration_card_deleted";
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

                  String numTar = _numTarjetaController.text;
                  String fecExp = _fecExpedicionController.text;
                  String fecVen = _fecVencimientoController.text;

                  String formattedMessage = message
                      .replaceAll("{vehicle_plate}", widget.vehicle['placas'])
                      .replaceAll("{card_number}", numTar)
                      .replaceAll("{issue_date}", _formatDate(fecExp))
                      .replaceAll("{expiry_date}", _formatDate(fecVen));

                  String title = noticeTemplate['title']
                      .replaceAll("{vehicle_plate}", widget.vehicle['placas']);

                  String finalMessage =
                      "$title|$formattedMessage|${noticeTemplate['icon']}";

                  debugPrint(
                      "📢 Generando notificación por crear de impuestos...");

                  final notificationData = {
                    'typeSource': Type,
                    'idOrigin': idcircu,
                    'typEvent': 3,
                    'date': DateTime.now().toIso8601String(),
                    'message': finalMessage,
                    'colNotice': 'tc_Delete',
                    'idMainAcoount': widget.idMainAccount.toString(),
                    'codUsGenerator': widget.userId.toString(),
                    'idDev': widget.userId.toString(),
                  };

                  await NotificationService()
                      .insertNotification(notificationData);

                  await VehiclesconService().deleteManagementControlTJ(
                      widget.idMainAccount.toString(),
                      widget.vehicle['id'].toString());

                  debugPrint("✅ Notificación enviada con éxito.");

                  Future.delayed(const Duration(milliseconds: 1), () {
                    if (mounted) {
                      Navigator.of(currentContext).pop();
                    }
                  });
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
                                "Tarjeta de circulación eliminada exitosamente.",
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
                  Navigator.of(context).pop();

                  debugPrint('Error al eliminar la tarjeta: $e');
                  showErrorDialodel(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0886B5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Eliminar',
                style: TextStyle(fontSize: screenWidth * 0.030),
              ),
            ),
          ],
        );
      },
    );
  }

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

  Widget _buildCardDetail(String label, String? value, IconData icon) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    String formattedValue = value ?? 'N/A';
    if (value != null && value.contains('-')) {
      try {
        DateTime date = DateTime.parse(value);
        formattedValue = DateFormat('dd/MM/yyyy').format(date);
      } catch (e) {
        debugPrint('Error formateando la fecha: $e');
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color.fromARGB(255, 0, 0, 0),
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
                fontSize: screenWidth * 0.032, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          Text(
            formattedValue,
            style: TextStyle(
                fontSize: screenWidth * 0.032, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildVigenciaCardWithIcon(Map<String, dynamic> data) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    String? fechaVencimiento = data['fecVencimiento']?.toString();
    String vigenciaTexto;
    Color vigenciaColor;
    IconData vigenciaIcon;

    if (fechaVencimiento == null || fechaVencimiento.isEmpty) {
      vigenciaTexto = 'Permanente';
      vigenciaColor = Colors.blue;
      vigenciaIcon = Icons.check_circle;
    } else {
      DateTime vencimiento = DateFormat('yyyy-MM-dd').parse(fechaVencimiento);
      Duration diferencia = vencimiento.difference(DateTime.now());

      if (diferencia.inDays > 0) {
        vigenciaTexto = 'Vigente - Vence en ${diferencia.inDays} días';
        vigenciaColor = Colors.green;
        vigenciaIcon = Icons.date_range;
      } else if (diferencia.inDays == 0) {
        vigenciaTexto = 'Vence hoy';
        vigenciaColor = Colors.orange;
        vigenciaIcon = Icons.warning;
      } else {
        vigenciaTexto = 'Vencido - Venció hace ${diferencia.inDays.abs()} días';
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
