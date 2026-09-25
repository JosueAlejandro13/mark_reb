import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bottom_picker/bottom_picker.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
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
class InsurancePage extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  final String insurancePermission;
  final String idMainAccount;
  final String userId;

  const InsurancePage(
      {super.key,
      required this.insurancePermission,
      required this.vehicle,
      required this.idMainAccount,
      required this.userId});

  @override
  _InsurancePageState createState() => _InsurancePageState();
}

class _InsurancePageState extends State<InsurancePage> {
  late Future<List<Map<String, dynamic>>> _insuranceData;
  late TextEditingController polizaNumController;
  late TextEditingController deducibleController;
  late TextEditingController montoController;
  late TextEditingController observacionesController;
  late TextEditingController fechaInicioController;
  late TextEditingController fechaVencimientoController;
  bool _hasInsurance = false;
  late String Type;
  List<Map<String, dynamic>> companias = [];
  List<Map<String, dynamic>> coberturas = [];
  bool _isDisposed = false;

  final NumberFormat currencyFormat = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 2,
  );
  @override
  void initState() {
    super.initState();
    polizaNumController = TextEditingController();
    deducibleController = TextEditingController();
    montoController = TextEditingController();
    observacionesController = TextEditingController();
    fechaInicioController = TextEditingController();
    fechaVencimientoController = TextEditingController();
    _checkInsurance().catchError((error) {
      _handleError(error);
    });
    _insuranceData = obtenerSeguros();

    _TypeSource().catchError((error) {
      if (!_isDisposed) {
        _handleError(error);
      }
    });
  }

  Future<void> _TypeSource() async {
    try {
      Map<String, dynamic> data =
          await NotificationService().gettypSource("vehic_insurance");
      debugPrint("📢 Tipo de fuente: $data");

      // Verificar tanto mounted como _isDisposed
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

  Future<void> _checkInsurance() async {
    List<Map<String, dynamic>> data = await obtenerSeguros();
    setState(() {
      _hasInsurance = data.isNotEmpty;
    });
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() {
      _insuranceData = VehiclesconService().obtenerSegurosPorVehiculo(
          widget.vehicle['id'].toString(), widget.idMainAccount.toString());
    });
    await _checkInsurance();
  }

  Future<List<Map<String, dynamic>>> obtenerSeguros() async {
    VehiclesconService dbService = VehiclesconService();
    String id = widget.vehicle['id'].toString();
    String idMainAccount = widget.idMainAccount;

    try {
      if (companias.isEmpty) {
        companias = await dbService.obtenerCompanias();
      }
      if (coberturas.isEmpty) {
        coberturas = await dbService.obtenerTipoCobertura();
      }

      return await dbService
          .obtenerSegurosPorVehiculo(id, idMainAccount)
          .then((data) {
        if (!mounted) return data;
        if (mounted && data.isNotEmpty) {
          var insurance = data[0];
          polizaNumController.text = insurance['polizaNum'].toString();
          deducibleController.text = insurance['deducible'].toString();
          montoController.text = insurance['monto'].toString();
          observacionesController.text = insurance['observaciones'].toString();
          fechaInicioController.text = insurance['fechaInicio'].toString();
          fechaVencimientoController.text =
              insurance['fechaVencimiento'].toString();
        }
        return data;
      });
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
      rethrow;
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
      rethrow;
    } catch (e) {
      debugPrint('Error al obtener los seguros: $e');
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
      return [];
    }
  }

  void _handleError(dynamic error) {
    if (!mounted) return;

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
      debugPrint('Error al obtener los seguros: $error');
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

  @override
  void dispose() {
    _isDisposed = true;
    polizaNumController.dispose();
    deducibleController.dispose();
    montoController.dispose();
    observacionesController.dispose();
    fechaInicioController.dispose();
    fechaVencimientoController.dispose();
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

                if (_hasInsurance &&
                    hasEditPermission(widget.insurancePermission)) {
                  menuItems.add(_buildPopupMenuItem(
                      context, 'edit', 'Editar', Icons.edit));
                }

                if (_hasInsurance &&
                    hasDeletePermission(widget.insurancePermission)) {
                  menuItems.add(_buildPopupMenuItem(
                      context, 'delete', 'Eliminar', Icons.delete));
                }

                if (hasCreatePermissio(widget.insurancePermission)) {
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
                      _showEditInsuranceDialog();
                    } else if (value == 'delete') {
                      _deleteInsuranceDialog();
                    } else if (value == 'create') {
                      _showCreateInsuranceDialog();
                    }
                  });
                } else {}
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
                    'Seguro - ${widget.vehicle['make']} ${widget.vehicle['model']}',
                    style: TextStyle(
                      fontSize: screenWidth * 0.050,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _insuranceData,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            // ignore: sized_box_for_whitespace
                            child: Container(
                              height: MediaQuery.of(context).size.height * 0.8,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Lottie.asset(
                                    "assets/loading.json",
                                    height: screenHeight * 0.2,
                                    width: screenWidth * 0.2,
                                    repeat: true,
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return ListView(
                            children: [
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.warning_rounded,
                                      size: 64,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No se encontraron seguros.',
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
                                      style: TextStyle(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        List<Map<String, dynamic>> seguros = snapshot.data!;
                        return ListView.builder(
                          itemCount: seguros.length,
                          itemBuilder: (context, index) {
                            var seguro = seguros[index];

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInsuranceInfoCard(
                                  context,
                                  seguro['idCompania'] ??
                                      'Compañía Desconocida',
                                  seguro['polizaNum'] ??
                                      'Número de Póliza Desconocido',
                                  seguro['idTipoCobertura'] ??
                                      'Cobertura Desconocida',
                                  double.tryParse(
                                          seguro['deducible']?.toString() ??
                                              '0.0') ??
                                      0.0,
                                  double.tryParse(seguro['monto']?.toString() ??
                                          '0.0') ??
                                      0.0,
                                  seguro['fechaInicio'] ?? DateTime.now(),
                                  seguro['fechaVencimiento'] ?? DateTime.now(),
                                ),
                                const SizedBox(height: 20),
                                _buildVigenciaCardWithIcon(seguro),
                              ],
                            );
                          },
                        );
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

  void _showCreateInsuranceDialog() async {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    TextEditingController polizaNumController = TextEditingController();
    TextEditingController deducibleController = TextEditingController();
    TextEditingController montoController = TextEditingController();
    TextEditingController observacionesController = TextEditingController();
    TextEditingController fechaInicioController = TextEditingController();
    TextEditingController fechaVencimientoController = TextEditingController();

    DateTime? fechaInicio;
    DateTime? fechaVencimiento;

    String? selectedCompania;
    String? selectedTipoCobertura;

    Future<void> selectDate(BuildContext context, bool isFechaInicio) async {
      final screenHeight = MediaQuery.of(context).size.height;
      final screenWidth = MediaQuery.of(context).size.width;

      BottomPicker.date(
        pickerTitle: Text(
          isFechaInicio
              ? "Selecciona la fecha de inicio"
              : "Selecciona la fecha de vencimiento",
          style: TextStyle(fontSize: screenWidth * 0.037),
        ),
        dismissable: true,
        pickerDescription: SizedBox(
            height: screenHeight * 0.03), // Espacio entre título y picker
        initialDateTime: isFechaInicio
            ? fechaInicio ?? DateTime.now()
            : fechaVencimiento ?? DateTime.now(),
        minDateTime: DateTime(2000),
        maxDateTime: DateTime(2101),
        pickerTextStyle:
            TextStyle(fontSize: screenWidth * 0.050, color: Colors.black),
        onSubmit: (selectedDate) {
          setState(() {
            if (isFechaInicio) {
              fechaInicio = selectedDate;
              fechaInicioController.text = _formatDate(selectedDate);
            } else {
              fechaVencimiento = selectedDate;
              fechaVencimientoController.text = _formatDate(selectedDate);
            }
          });
        },
        onCloseButtonPressed: () {
          print("Picker cerrado");
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
    }

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
                  'Crear Nuevo Seguro',
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Compañía Aseguradora",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: DropdownButtonFormField2<String>(
                    value: selectedCompania,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 13, horizontal: 12),
                      prefixIcon: const Icon(
                        Icons.business,
                        size: 15,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                    ),
                    isExpanded: true,
                    items: companias.map((compania) {
                      return DropdownMenuItem<String>(
                        value: compania['id'].toString(),
                        child: Text(
                          compania['name'],
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: screenWidth * 0.031),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCompania = value;
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
                ),
                const SizedBox(height: 8),
                Text(
                  "Tipo de Cobertura",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: DropdownButtonFormField2<String>(
                    value: selectedTipoCobertura,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.shield, size: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(
                          color: Colors.black,
                        ),
                      ),
                    ),
                    isExpanded: true,
                    items: coberturas.map((cobertura) {
                      return DropdownMenuItem<String>(
                        value: cobertura['id'].toString(),
                        child: Text(
                          cobertura['name'],
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: screenWidth * 0.031),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedTipoCobertura = value;
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
                ),
                const SizedBox(height: 8),
                Text(
                  "Número de Póliza",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextField(
                  controller: polizaNumController,
                  decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.description,
                        size: 15,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                      isDense: true,
                      counterText: ''),
                  style: TextStyle(fontSize: screenWidth * 0.031),
                  maxLength: 20,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Deducible
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Deducible",
                            style: TextStyle(
                              fontSize: screenWidth * 0.031,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextField(
                            controller: deducibleController,
                            decoration: InputDecoration(
                              prefixIcon:
                                  const Icon(Icons.attach_money, size: 15),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide:
                                    const BorderSide(color: Colors.black),
                              ),
                              isDense: true,
                              counterText: '',
                            ),
                            style: TextStyle(fontSize: screenWidth * 0.031),
                            keyboardType: TextInputType.number,
                            maxLength: 12,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9]')),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Monto
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Monto",
                            style: TextStyle(
                              fontSize: screenWidth * 0.031,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextField(
                            controller: montoController,
                            decoration: InputDecoration(
                              prefixIcon:
                                  const Icon(Icons.attach_money, size: 15),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide:
                                    const BorderSide(color: Colors.black),
                              ),
                              isDense: true,
                              counterText: '',
                            ),
                            style: TextStyle(fontSize: screenWidth * 0.031),
                            keyboardType: TextInputType.number,
                            maxLength: 12,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9]')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fecha de Inicio
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Fecha de Inicio",
                            style: TextStyle(
                              fontSize: screenWidth * 0.031,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextField(
                            controller: fechaInicioController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide:
                                    const BorderSide(color: Colors.black),
                              ),
                              isDense: true,
                            ),
                            readOnly: true,
                            onTap: () => selectDate(context, true),
                            style: TextStyle(fontSize: screenWidth * 0.031),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Fecha de Vencimiento
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Fecha de Vencimiento",
                            style: TextStyle(
                              fontSize: screenWidth * 0.030,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextField(
                            controller: fechaVencimientoController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide:
                                    const BorderSide(color: Colors.black),
                              ),
                              isDense: true,
                            ),
                            readOnly: true,
                            onTap: () => selectDate(context, false),
                            style: TextStyle(fontSize: screenWidth * 0.031),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Observaciones",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextField(
                  controller: observacionesController,
                  decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.comment,
                        size: 15,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                      isDense: true,
                      counterText: ''),
                  style: TextStyle(fontSize: screenWidth * 0.031),
                  maxLength: 40,
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
                if (selectedCompania != null &&
                    selectedTipoCobertura != null &&
                    fechaInicio != null &&
                    fechaVencimiento != null) {
                  if (fechaInicio!.isAfter(fechaVencimiento!)) {
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
                                  "La fecha de inicio no puede ser mayor a la fecha de vencimiento.",
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
                            maxWidth: screenWidth * 0.5,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  "Creando seguro        ",
                                  style:
                                      TextStyle(fontSize: screenWidth * 0.033),
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

                    VehiclesconService dbService = VehiclesconService();

                    await dbService.crearSeguro(
                      widget.vehicle['id'].toString(),
                      selectedCompania!,
                      widget.vehicle['idMainAccount'].toString(),
                      polizaNumController.text,
                      selectedTipoCobertura!,
                      fechaInicioController.text,
                      fechaVencimientoController.text,
                      deducibleController.text,
                      montoController.text,
                      observacionesController.text,
                    );

                    setState(() {
                      _insuranceData = obtenerSeguros();
                    });

                    List<Map<String, dynamic>> insurance =
                        await VehiclesconService().obtenerSegurosPorVehiculo(
                      widget.vehicle['id'].toString(),
                      widget.idMainAccount.toString(),
                    );

                    if (insurance.isEmpty) {
                      debugPrint("⚠ No hay insurance para actualizado.");
                      return;
                    }

                    int idinsurance = insurance.first['id'];

                    String nameNotice = "vehicle_insurance_added";
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
                        .replaceAll("{policy_number}", polizaNumController.text)
                        .replaceAll(
                            "{contract_date}", fechaInicioController.text)
                        .replaceAll(
                            "{expiry_date}", fechaVencimientoController.text);

                    String title = noticeTemplate['title'].replaceAll(
                        "{vehicle_plate}", widget.vehicle['placas']);

                    String finalMessage =
                        "$title|$formattedMessage|${noticeTemplate['icon']}";

                    debugPrint("📢 Generando notificación por crear seguro...");

                    final notificationData = {
                      'typeSource': Type,
                      'idOrigin': idinsurance,
                      'typEvent': 1,
                      'date': DateTime.now().toIso8601String(),
                      'message': formattedMessage,
                      'colNotice': 'insurace_New',
                      'idMainAcoount': widget.idMainAccount.toString(),
                      'codUsGenerator': widget.userId.toString(),
                      'idDev': widget.userId.toString(),
                    };

                    await NotificationService()
                        .insertNotification(notificationData);

                    await VehiclesconService().insertManagementControlINS(
                        widget.idMainAccount.toString(),
                        widget.vehicle['id'].toString(),
                        DateFormat('yyyy-MM-dd')
                            .parse(fechaVencimientoController.text));

                    debugPrint("✅ Notificación enviada con éxito.");

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
                                  "Seguro creado exitosamente.",
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
                    debugPrint("Error al crear seguro: $e");
                    showErrorDialog(context);
                  }
                } else {
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
                                "Por favor, completa todos los campos",
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0886B5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              ),
              child: Text('Crear Seguro',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(dynamic date) {
    if (date is DateTime) {
      return DateFormat('yyyy-MM-dd').format(date);
    } else if (date is String) {
      DateTime parsedDate;
      try {
        parsedDate = DateFormat('dd/MM/yyyy').parse(date);
        return DateFormat('yyyy-MM-dd').format(parsedDate);
      } catch (e) {
        return date;
      }
    }
    return '';
  }

  Widget _buildInsuranceInfoCard(
    BuildContext context,
    String compania,
    String policyNumber,
    String tipoCobertura,
    double deducible,
    double monto,
    DateTime fechaInicio,
    DateTime fechaVencimiento,
  ) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.business, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    compania,
                    style: TextStyle(
                        fontSize: screenWidth * 0.032,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Divider(),
            Row(
              children: [
                const Icon(Icons.shield, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Tipo de Cobertura: ',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: Colors.black,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  tipoCobertura,
                  style: TextStyle(
                      fontSize: screenWidth * 0.032, color: Colors.grey[700]),
                )
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.description, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Póliza: ',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
                Text(
                  policyNumber,
                  style: TextStyle(
                      fontSize: screenWidth * 0.032, color: Colors.grey[700]),
                )
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.attach_money, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Deducible: ',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: Colors.black,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  currencyFormat.format(deducible),
                  style: TextStyle(
                      fontSize: screenWidth * 0.032, color: Colors.grey[700]),
                )
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.attach_money, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Monto: ',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: Colors.black,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  currencyFormat.format(monto),
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
                  'Fecha de inicio',
                  style: TextStyle(
                      fontSize: screenWidth * 0.033,
                      color: Colors.black,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  ' ${_formatDate(fechaInicio)} ',
                  style: TextStyle(
                      fontSize: screenWidth * 0.033, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Fecha de vencimiento',
                  style: TextStyle(
                      fontSize: screenWidth * 0.033,
                      color: Colors.black,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  ' ${_formatDate(fechaVencimiento)} ',
                  style: TextStyle(
                      fontSize: screenWidth * 0.033, color: Colors.grey[700]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _deleteInsuranceDialog() {
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
                      constraints: BoxConstraints(),
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
          content: Text('¿Estás seguro de que deseas eliminar este seguro?',
              style: TextStyle(fontSize: screenWidth * 0.033)),
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
              child: Text('Cancelar',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
              onPressed: () => Navigator.of(context).pop(),
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
                                "Eliminando Seguro        ",
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
                  List<Map<String, dynamic>> insurance =
                      await VehiclesconService().obtenerSegurosPorVehiculo(
                    widget.vehicle['id'].toString(),
                    widget.idMainAccount.toString(),
                  );

                  if (insurance.isEmpty) {
                    debugPrint("⚠ No hay insurance para actualizado.");
                    return;
                  }

                  int idinsurance = insurance.first['id'];

                  await VehiclesconService()
                      .eliminarSeguro(widget.vehicle['id'].toString(),
                          widget.idMainAccount.toString())
                      .then((_) async {
                    String nameNotice = "vehicle_insurance_deleted";
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
                        .replaceAll("{policy_number}", polizaNumController.text)
                        .replaceAll(
                            "{contract_date}",
                            _formatDate(
                                DateTime.parse(fechaInicioController.text)))
                        .replaceAll(
                            "{expiry_date}",
                            _formatDate(DateTime.parse(
                                fechaVencimientoController.text)));

                    String title = noticeTemplate['title'].replaceAll(
                        "{vehicle_plate}", widget.vehicle['placas']);

                    String finalMessage =
                        "$title|$formattedMessage|${noticeTemplate['icon']}";

                    debugPrint(
                        "📢 Generando notificación por eliminación de Seguro...");

                    final notificationData = {
                      'typeSource': Type,
                      'idOrigin': idinsurance,
                      'typEvent': 3,
                      'date': DateTime.now().toIso8601String(),
                      'message': finalMessage,
                      'colNotice': 'insurace_Delete',
                      'idMainAcoount': widget.idMainAccount.toString(),
                      'codUsGenerator': widget.userId.toString(),
                      'idDev': widget.userId.toString(),
                    };

                    await NotificationService()
                        .insertNotification(notificationData);

                    await VehiclesconService().deleteManagementControlINS(
                      widget.idMainAccount.toString(),
                      widget.vehicle['id'].toString(),
                    );

                    Navigator.of(currentContext).pop();

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
                                  "Seguro eliminada exitosamente.",
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

                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        Navigator.of(currentContext).pop();
                        Navigator.of(currentContext).pop();
                      }
                    });
                  });

                  setState(() {
                    _insuranceData = obtenerSeguros();
                  });
                } catch (e) {
                  debugPrint("Error al eliminar seguro: $e");
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

  void _showEditInsuranceDialog() async {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    DateTime? fechaInicio;
    DateTime? fechaVencimiento;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Lottie.asset(
          'assets/loading.json',
          height: screenHeight * 0.1,
          width: screenWidth * 0.1,
          repeat: true,
        ),
      ),
    );

    List<Map<String, dynamic>> seguros = [];

    try {
      seguros = await VehiclesconService().obtenerSegurosPorVehiculo(
        widget.vehicle['id'].toString(),
        widget.idMainAccount.toString(),
      );
    } catch (e) {
      debugPrint("Error al obtener seguros: $e");

      if (mounted) {
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
                      "Error al cargar seguros.",
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
      return;
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (seguros.isEmpty) {
      if (mounted) Navigator.of(context).pop();

      Navigator.of(context, rootNavigator: true).pop();

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
                    "No se encontró información del seguro.",
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

    Map<String, dynamic> seguroActual = seguros[0];

    String? selectedCompania = companias
        .firstWhere((comp) => comp['name'] == seguroActual['idCompania'],
            orElse: () => {'id': null})['id']
        ?.toString();

    String? selectedTipoCobertura = coberturas
        .firstWhere((cob) => cob['name'] == seguroActual['idTipoCobertura'],
            orElse: () => {'id': null})['id']
        ?.toString();

    try {
      fechaInicio = DateTime.parse(seguroActual['fechaInicio'].toString());
      fechaVencimiento =
          DateTime.parse(seguroActual['fechaVencimiento'].toString());
      fechaInicioController.text = _formatDate(fechaInicio);
      fechaVencimientoController.text = _formatDate(fechaVencimiento);
    } catch (e) {
      debugPrint("Error al parsear fechas: $e");
      fechaInicio = DateTime.now();
      fechaVencimiento = DateTime.now();
    }

    Future<void> selectDate(BuildContext context, bool isFechaInicio) async {
      final screenHeight = MediaQuery.of(context).size.height;
      final screenWidth = MediaQuery.of(context).size.width;

      BottomPicker.date(
        pickerTitle: Text(
          isFechaInicio ? "Fecha de inicio" : "Fecha de vencimiento",
          style: TextStyle(fontSize: screenWidth * 0.037),
        ),
        dismissable: true,
        pickerDescription: SizedBox(height: screenHeight * 0.03),
        initialDateTime: isFechaInicio
            ? fechaInicio ?? DateTime.now()
            : fechaVencimiento ?? DateTime.now(),
        minDateTime: DateTime(2000),
        maxDateTime: DateTime(2101),
        pickerTextStyle:
            TextStyle(fontSize: screenWidth * 0.050, color: Colors.black),
        onSubmit: (selectedDate) {
          setState(() {
            if (isFechaInicio) {
              fechaInicio = selectedDate;
              fechaInicioController.text = _formatDate(selectedDate);
            } else {
              fechaVencimiento = selectedDate;
              fechaVencimientoController.text = _formatDate(selectedDate);
            }
          });
        },
        onCloseButtonPressed: () {
          print("Picker cerrado");
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
    }

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
                  'Actualizar Seguro',
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Compañía Aseguradora",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: DropdownButtonFormField2<String>(
                    value: selectedCompania,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 13, horizontal: 12),
                      prefixIcon: const Icon(
                        Icons.business,
                        size: 15,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                    ),
                    isExpanded: true,
                    items: companias.map((compania) {
                      return DropdownMenuItem<String>(
                        value: compania['id'].toString(),
                        child: Text(compania['name'],
                            style: TextStyle(fontSize: screenWidth * 0.031)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCompania = value;
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
                ),
                const SizedBox(height: 8),
                Text(
                  "Tipo de Cobertura",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                DropdownButtonFormField2<String>(
                  isExpanded: true,
                  value: selectedTipoCobertura,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 13, horizontal: 12),
                    prefixIcon: const Icon(Icons.shield, size: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                  ),
                  items: coberturas.map((cobertura) {
                    return DropdownMenuItem<String>(
                      value: cobertura['id'].toString(),
                      child: Text(cobertura['name'],
                          style: TextStyle(fontSize: screenWidth * 0.031)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedTipoCobertura = value;
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
                const SizedBox(height: 8),
                Text(
                  "Número de Póliza",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextField(
                  controller: polizaNumController,
                  decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.description,
                        size: 15,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                      isDense: true,
                      counterText: ''),
                  style: TextStyle(fontSize: screenWidth * 0.031),
                  maxLength: 20,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Deducible",
                            style: TextStyle(
                              fontSize: screenWidth * 0.031,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextField(
                            controller: deducibleController,
                            decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.attach_money,
                                  size: 15,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  borderSide:
                                      const BorderSide(color: Colors.black),
                                ),
                                isDense: true,
                                counterText: ''),
                            style: TextStyle(fontSize: screenWidth * 0.031),
                            keyboardType: TextInputType.number,
                            maxLength: 12,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9]')),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Monto",
                            style: TextStyle(
                              fontSize: screenWidth * 0.031,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextField(
                            controller: montoController,
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
                            style: TextStyle(fontSize: screenWidth * 0.031),
                            keyboardType: TextInputType.number,
                            maxLength: 12,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9]')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Fecha de Inicio",
                            style: TextStyle(
                              fontSize: screenWidth * 0.031,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextField(
                            controller: fechaInicioController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide:
                                    const BorderSide(color: Colors.black),
                              ),
                            ),
                            readOnly: true,
                            onTap: () => selectDate(context, true),
                            style: TextStyle(fontSize: screenWidth * 0.031),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Fecha de Vencimiento",
                            style: TextStyle(
                              fontSize: screenWidth * 0.030,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextField(
                            controller: fechaVencimientoController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide:
                                    const BorderSide(color: Colors.black),
                              ),
                            ),
                            readOnly: true,
                            onTap: () => selectDate(context, false),
                            style: TextStyle(fontSize: screenWidth * 0.031),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Observaciones",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextField(
                  controller: observacionesController,
                  decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.comment, size: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                      isDense: true,
                      counterText: ''),
                  style: TextStyle(fontSize: screenWidth * 0.031),
                  maxLength: 40,
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
                if (selectedCompania != null &&
                    selectedTipoCobertura != null &&
                    fechaInicio != null &&
                    fechaVencimiento != null) {
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
                  try {
                    VehiclesconService dbService = VehiclesconService();

                    DateTime fechaInicioUTC = fechaInicio!.toUtc();
                    DateTime fechaVencimientoUTC = fechaVencimiento!.toUtc();
                    await dbService.actualizarSeguroPorVehiculo(
                      widget.vehicle['id'].toString(),
                      widget.idMainAccount.toString(),
                      selectedCompania!,
                      polizaNumController.text,
                      selectedTipoCobertura!,
                      DateFormat('yyyy-MM-dd')
                          .format(DateTime.parse(fechaInicioUTC.toString())),
                      DateFormat('yyyy-MM-dd').format(
                          DateTime.parse(fechaVencimientoUTC.toString())),
                      double.parse(deducibleController.text),
                      double.parse(montoController.text),
                      observacionesController.text,
                    );

                    setState(() {
                      _insuranceData = obtenerSeguros();
                    });

                    List<Map<String, dynamic>> insurance =
                        await VehiclesconService().obtenerSegurosPorVehiculo(
                      widget.vehicle['id'].toString(),
                      widget.idMainAccount.toString(),
                    );

                    if (insurance.isEmpty) {
                      debugPrint("⚠ No hay idverificacion para actualizado.");
                      return;
                    }

                    int idinsurance = insurance.first['id'];

                    setState(() {});

                    String nameNotice = "vehicle_insurance_updated";
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
                        .replaceAll("{policy_number}", polizaNumController.text)
                        .replaceAll(
                            "{contract_date}",
                            _formatDate(
                                DateTime.parse(fechaInicioController.text)))
                        .replaceAll(
                            "{expiry_date}",
                            _formatDate(DateTime.parse(
                                fechaVencimientoController.text)));

                    String title = noticeTemplate['title'].replaceAll(
                        "{vehicle_plate}", widget.vehicle['placas']);

                    String finalMessage =
                        "$title|$formattedMessage|${noticeTemplate['icon']}";

                    debugPrint(
                        "📢 Generando notificación por actualizado de Seguro...");

                    final notificationData = {
                      'typeSource': Type,
                      'idOrigin': idinsurance,
                      'typEvent': 2,
                      'date': DateTime.now().toIso8601String(),
                      'message': finalMessage,
                      'colNotice': 'insurace_Edit',
                      'idMainAcoount': widget.idMainAccount.toString(),
                      'codUsGenerator': widget.userId.toString(),
                      'idDev': widget.userId.toString(),
                    };

                    await NotificationService()
                        .insertNotification(notificationData);

                    await VehiclesconService().updateManagementControlINS(
                        widget.idMainAccount.toString(),
                        widget.vehicle['id'].toString(),
                        fechaVencimientoUTC.toIso8601String());

                    Navigator.of(context).pop();
                    debugPrint('Seguro actualizado exitosamente');
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
                                  "Seguro actualizado exitosamente.",
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
                    debugPrint("Error al actualizar el seguro: $e");
                    Navigator.of(context).pop();
                    showErrorDialogup(context);
                  }
                } else {
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
                                "Por favor, completa todos los campos",
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0886B5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              ),
              child: Text('Actualizar Seguro',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
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

  Widget _buildVigenciaCardWithIcon(Map<String, dynamic> data) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    String? fechaVencimiento = data['fechaVencimiento']?.toString();
    String vigenciaTexto;
    Color vigenciaColor;
    IconData vigenciaIcon;

    if (fechaVencimiento == null || fechaVencimiento.isEmpty) {
      vigenciaTexto = 'Sin fecha de vencimiento';
      vigenciaColor = Colors.grey[700]!;
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
