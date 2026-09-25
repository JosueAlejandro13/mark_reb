import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bottom_picker/bottom_picker.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/Error_/unexpectedErrorPage.dart';
import 'package:mark_v3/pages/Vehicles_/PayCreditPage.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';
import 'package:mark_v3/services/ConnectionNotification_/NotificationCon_service.dart';
import 'package:mysql1/mysql1.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

//Autor: Josue Hernandez
class Creditpage extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  final String creditPermission;
  final String idMainAccount;
  final String userId;

  const Creditpage({
    super.key,
    required this.vehicle,
    required this.creditPermission,
    required this.idMainAccount,
    required this.userId,
  });

  @override
  _CreditpageState createState() => _CreditpageState();
}

class _CreditpageState extends State<Creditpage> {
  late Future<List<Map<String, dynamic>>> _creditData;
  late TextEditingController nameController;
  late TextEditingController fechaInicioController;
  late TextEditingController montoController;
  late TextEditingController engancheController;
  late TextEditingController interesController;
  late TextEditingController plazoController;
  late TextEditingController comisionController;
  late TextEditingController comisionAperturaController;
  late TextEditingController diaPagoController;
  late TextEditingController dateFirstPaymentController;
  Future<List<Map<String, dynamic>>>? _creditFuture;
  List<Map<String, dynamic>> credit = [];

  bool _hasCredit = false;
  String pay = '';
  String? creditoId;
  late String Type;
  bool _isLoading = true;

  List<Map<String, dynamic>> creditosDisponibles = [];
  String? selectedCreditoParaCrear;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    fechaInicioController = TextEditingController();
    montoController = TextEditingController();
    engancheController = TextEditingController();
    interesController = TextEditingController();
    plazoController = TextEditingController();
    comisionController = TextEditingController();
    comisionAperturaController = TextEditingController();
    diaPagoController = TextEditingController();
    dateFirstPaymentController = TextEditingController();
    _creditFuture = _loadCreditData();

    _initializeData();
    _TypeSource();
    _loadCreditosDisponibles();
  }

  Future<void> _loadCreditosDisponibles() async {
    try {
      final data =
          await VehiclesconService().obtenerCreditos(widget.idMainAccount);
      if (mounted) {
        setState(() {
          creditosDisponibles = data;
          if (creditosDisponibles.isNotEmpty) {
            selectedCreditoParaCrear = creditosDisponibles[0]['id'].toString();
          }
        });
      }
    } catch (e) {
      debugPrint("Error al cargar los créditos disponibles: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al cargar los créditos disponibles')),
        );
      }
    }
  }

  Future<void> _initializeData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _checkCredit();
      if (!mounted) return;

      await _loadCreditData();
      if (!mounted) return;
    } catch (error) {
      _handleError(error);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _TypeSource() async {
    if (!mounted) return;

    try {
      Map<String, dynamic> data =
          await NotificationService().gettypSource("vehic_credit");

      if (mounted) {
        setState(() {
          Type = data['id'].toString();
        });
      }
    } catch (e) {
      debugPrint("Error al obtener el tipo de fuente: $e");
    }
  }

  Future<void> _checkCredit() async {
    List<Map<String, dynamic>> data = await obtenerCreditos();

    if (!mounted) return;

    setState(() {
      _hasCredit = data.isNotEmpty;
    });
  }

  Future<List<Map<String, dynamic>>> _loadCreditData() async {
    if (!mounted) return [];
    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> creditData = await obtenerCreditos();

      if (creditData.isNotEmpty) {
        var credit = creditData[0];
        setState(() {
          creditoId = credit['id'].toString();
          nameController.text = credit['name'].toString();
          fechaInicioController.text = credit['fechaInicio'] != null
              ? DateFormat('yyyy-MM-dd')
                  .format(DateTime.parse(credit['fechaInicio'].toString()))
              : '';
          montoController.text = credit['monto'].toString();
          engancheController.text = credit['enganche'].toString();
          interesController.text = credit['interes'].toString();
          plazoController.text = credit['plazo'].toString();
          comisionController.text = credit['comision'].toString();
          comisionAperturaController.text =
              credit['comisionApertura'].toString();
          diaPagoController.text = credit['diaPago'].toString();
          dateFirstPaymentController.text = credit['dateFirstPayment'] != null
              ? DateFormat('yyyy-MM-dd')
                  .format(DateTime.parse(credit['dateFirstPayment'].toString()))
              : '';
        });

        Map<String, dynamic> nextPaymentData =
            await VehiclesconService().getNextPaymentDate(creditoId!);

        if (mounted) {
          setState(() {
            pay = nextPaymentData.containsKey('fecExpi') &&
                    nextPaymentData['fecExpi'] != null
                ? nextPaymentData['fecExpi'].toString()
                : '';
          });
        }
      }

      return creditData;
    } catch (e) {
      debugPrint("Error al cargar los datos del crédito: $e");
      return [];
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _creditFuture = _loadCreditData();
    });
  }

  Future<List<Map<String, dynamic>>> obtenerCreditos() async {
    VehiclesconService dbService = VehiclesconService();
    String id = widget.vehicle['id'].toString();
    String idMainAccount = widget.idMainAccount;

    try {
      if (!mounted) return [];

      if (credit.isEmpty) {
        credit = await dbService.getCreditos(idMainAccount, id);
      }

      List<Map<String, dynamic>> data =
          await dbService.getCreditos(idMainAccount, id);

      if (!mounted) return [];

      if (data.isNotEmpty) {
        var credit = data[0];

        if (mounted) {
          setState(() {
            creditoId = credit['id'].toString();
            nameController.text = credit['name'].toString();
            fechaInicioController.text = credit['fechaInicio'] != null
                ? DateFormat('yyyy-MM-dd')
                    .format(DateTime.parse(credit['fechaInicio'].toString()))
                : '';
            montoController.text = credit['monto'].toString();
            engancheController.text = credit['enganche'].toString();
            interesController.text = credit['interes'].toString();
            plazoController.text = credit['plazo'].toString();
            comisionController.text = credit['comision'].toString();
            comisionAperturaController.text =
                credit['comisionApertura'].toString();
            diaPagoController.text = credit['diaPago'].toString();
            dateFirstPaymentController.text = credit['dateFirstPayment'] != null
                ? DateFormat('yyyy-MM-dd').format(
                    DateTime.parse(credit['dateFirstPayment'].toString()))
                : '';
          });
        }
      }
      return data;
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
      debugPrint('Error al obtener los impuestos: $error');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (contex) => Unexpectederrorpage(
            onRetry: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (contex) => widget),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    fechaInicioController.dispose();
    montoController.dispose();
    engancheController.dispose();
    interesController.dispose();
    plazoController.dispose();
    comisionController.dispose();
    comisionAperturaController.dispose();
    diaPagoController.dispose();
    dateFirstPaymentController.dispose();
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

                if (_hasCredit && hasEditPermission(widget.creditPermission)) {
                  menuItems.add(_buildPopupMenuItem(
                      context, 'edit', 'Editar', Icons.edit));
                }
                if (_hasCredit &&
                    hasDeletePermission(widget.creditPermission)) {
                  menuItems.add(_buildPopupMenuItem(
                      context, 'delete', 'Eliminar', Icons.delete));
                }
                if (!_hasCredit &&
                    hasCreatePermission(widget.creditPermission)) {
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
                      _updateCredit();
                    } else if (value == 'delete') {
                      _deleteCredit();
                    } else if (value == 'create') {
                      _createCredit();
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
                    'Crédito - ${widget.vehicle['make']} ${widget.vehicle['model']}',
                    style: TextStyle(
                        fontSize: screenWidth * 0.050,
                        color: Colors.black,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _creditFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _buildLoadingIndicator(
                              screenHeight, screenWidth);
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return _buildEmptyState(screenWidth);
                        }

                        List<Map<String, dynamic>> creditos = snapshot.data!;
                        return ListView.builder(
                          itemCount: creditos.length,
                          itemBuilder: (context, index) {
                            var credit = creditos[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInsuranceInfoCard(
                                  context,
                                  credit['name'] ?? 'Desconocido',
                                  credit['fechaInicio'] is DateTime
                                      ? credit['fechaInicio']
                                      : DateTime.tryParse(credit['fechaInicio']
                                                  ?.toString() ??
                                              '') ??
                                          DateTime.now(),
                                  credit['plazo'] is int
                                      ? credit['plazo']
                                      : int.tryParse(
                                              credit['plazo']?.toString() ??
                                                  '0') ??
                                          0,
                                  double.tryParse(
                                          credit['enganche']?.toString() ??
                                              '0.0') ??
                                      0.0,
                                  double.tryParse(credit['monto']?.toString() ??
                                          '0.0') ??
                                      0.0,
                                  credit['comision'] is int
                                      ? credit['comision']
                                      : int.tryParse(
                                              credit['comision']?.toString() ??
                                                  '0') ??
                                          0,
                                  credit['comisionApertura'] is int
                                      ? credit['comisionApertura']
                                      : int.tryParse(credit['comisionApertura']
                                                  ?.toString() ??
                                              '0') ??
                                          0,
                                  credit['dateFirstPayment'] is DateTime
                                      ? credit['dateFirstPayment']
                                      : DateTime.tryParse(
                                              credit['dateFirstPayment']
                                                      ?.toString() ??
                                                  '') ??
                                          DateTime.now(),
                                  credit['interes'] is int
                                      ? credit['interes']
                                      : int.parse(
                                          credit['interes']?.toString() ?? '0'),
                                ),
                                const SizedBox(height: 20),
                                _buildVigenciaCardWithIcon(pay),
                                const SizedBox(height: 20),
                                Align(
                                  alignment: Alignment.center,
                                  child: ElevatedButton(
                                    onPressed: pay.isEmpty
                                        ? null
                                        : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    PayCreditPage(
                                                        creditoId: creditoId,
                                                        vehicle: widget.vehicle,
                                                        idMainAccount: widget
                                                            .idMainAccount,
                                                        userId: widget.userId),
                                              ),
                                            );
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0886B5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      elevation: 5,
                                      minimumSize: Size(screenWidth * 0.35,
                                          screenHeight * 0.045),
                                    ),
                                    child: Text(
                                      'Registrar pago',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: screenWidth * 0.030,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
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

  void _createCredit() async {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    TextEditingController montoController = TextEditingController();
    TextEditingController engancheController = TextEditingController();
    TextEditingController interesController = TextEditingController();
    TextEditingController plazoController = TextEditingController();
    TextEditingController comisionController = TextEditingController();
    TextEditingController comisionAperturaController = TextEditingController();
    TextEditingController fechaInicioController = TextEditingController();
    TextEditingController dateFirstPaymentController = TextEditingController();

    DateTime? fechaInicio;
    DateTime? dateFirstPayment;

    String? selectedcreditos;
    if (creditosDisponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay créditos disponibles')),
      );
      return;
    }
    final creditoBase = creditosDisponibles.first;

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
        pickerDescription: SizedBox(height: screenHeight * 0.03),
        initialDateTime: isFechaInicio
            ? fechaInicio ?? DateTime.now()
            : dateFirstPayment ?? DateTime.now(),
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
              dateFirstPayment = selectedDate;
              dateFirstPaymentController.text = _formatDate(selectedDate);
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
                  'Crear Nuevo Crédito',
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
                      icon: const Icon(Icons.close),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Créditos",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: DropdownButtonFormField2<String>(

                    value: selectedcreditos,
                    decoration: InputDecoration(
                         contentPadding: const EdgeInsets.symmetric(
                                    vertical: 13, horizontal: 12),
                      prefixIcon: const Icon(Icons.business, size: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                    ),
                    isExpanded: true,
                    items: creditosDisponibles.map((compania) {
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
                        selectedcreditos = value;
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
                              ),                  ),
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
                                    const Icon(Icons.monetization_on, size: 15),
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
                            "Enganche",
                            style: TextStyle(
                              fontSize: screenWidth * 0.031,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextField(
                            controller: engancheController,
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
                            "Interés",
                            style: TextStyle(
                              fontSize: screenWidth * 0.031,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                       TextField(
                        controller: interesController,
                        decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.percent, size: 15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                            isDense: true,
                            counterText: ''),
                        style: TextStyle(fontSize: screenWidth * 0.031),
                        keyboardType: TextInputType.number,
                        maxLength: 3,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
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
                            "Plazo (meses)",
                            style: TextStyle(
                              fontSize: screenWidth * 0.031,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                       TextField(
                        controller: plazoController,
                        decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.timer, size: 15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                            isDense: true,
                            counterText: ''),
                        style: TextStyle(fontSize: screenWidth * 0.031),
                        keyboardType: TextInputType.number,
                        maxLength: 2,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
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
                            "Comisión",
                            style: TextStyle(
                              fontSize: screenWidth * 0.031,
                              fontWeight: FontWeight.w600,
                            ),
                          ), 
                      TextField(
                        controller: comisionController,
                        decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.money_off, size: 15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                            isDense: true,
                            counterText: ''),
                        style: TextStyle(fontSize: screenWidth * 0.031),
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
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
                            "Comisión Apertura",
                            style: TextStyle(
                              fontSize: screenWidth * 0.031,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      TextField(
                        controller: comisionAperturaController,
                        decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.account_balance_wallet,
                                size: 15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                            isDense: true,
                            counterText: ''),
                        style: TextStyle(fontSize: screenWidth * 0.031),
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                        ],
                      ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Fecha de inicio",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextField(
                  controller: fechaInicioController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.date_range, size: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                  ),
                  readOnly: true,
                  onTap: () => selectDate(context, true),
                  style: TextStyle(fontSize: screenWidth * 0.031),
                ),
                const SizedBox(height: 8),
                Text(
                  "Fecha de primer pago",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextField(
                  controller: dateFirstPaymentController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.calendar_today, size: 15),
                  ),
                  readOnly: true,
                  onTap: () => selectDate(context, false),
                  style: TextStyle(fontSize: screenWidth * 0.031),
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
                  borderRadius:
                      BorderRadius.circular(10), // ← Ajusta el redondeo aquí
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (fechaInicio != null) {
                  bool success = false;

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
                                "Creando crédito        ",
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
                    VehiclesconService dbService = VehiclesconService();
                    DateTime fechaInicioUTC = fechaInicio!.toUtc();
                    DateTime dateFirstPaymentUTC = dateFirstPayment!.toUtc();

                    await dbService.crearCredito(
                      widget.idMainAccount.toString(),
                      widget.vehicle['id'].toString(),
                      selectedcreditos!,
                      fechaInicioUTC,
                      montoController.text,
                      engancheController.text,
                      interesController.text,
                      plazoController.text,
                      comisionController.text,
                      comisionAperturaController.text,
                      dateFirstPaymentUTC,
                    );

                    List<Map<String, dynamic>> credito =
                        await VehiclesconService().getCreditos(
                      widget.idMainAccount.toString(),
                      widget.vehicle['id'].toString(),
                    );

                    if (credito.isEmpty) {
                      debugPrint("⚠ No hay crédito creado.");
                      return;
                    }

                    int idcredito = credito.first['id'];

                    setState(() {
                      _creditFuture = obtenerCreditos();
                    });

                    String nameNotice = "vehicle_credit_added";
                    Map<String, dynamic>? noticeTemplate =
                        await NotificationService().getNoticeByName(nameNotice);

                    if (noticeTemplate != null) {
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

                      String message = utf8.decode(messageBytes);
                      String formattedMessage = message.replaceAll(
                          "{vehicle_plate}", widget.vehicle['placas']);
                      String title = noticeTemplate['title'].replaceAll(
                          "{vehicle_plate}", widget.vehicle['placas']);

                      String finalMessage =
                          "$title|$formattedMessage|${noticeTemplate['icon']}";

                      final notificationData = {
                        'typeSource': Type,
                        'idOrigin': idcredito,
                        'typEvent': 1,
                        'date': DateTime.now().toIso8601String(),
                        'message': finalMessage,
                        'colNotice': 'credit_New',
                        'idMainAcoount': widget.idMainAccount.toString(),
                        'codUsGenerator': widget.userId.toString(),
                        'idDev': widget.userId.toString(),
                      };

                      debugPrint("notificationData: $notificationData");
                      await NotificationService()
                          .insertNotification(notificationData);
                    }

                    int nPayments = int.tryParse(plazoController.text) ?? 0;
                    if (nPayments > 0) {
                      await VehiclesconService().insertarPagosCredito(
                        widget.idMainAccount,
                        idcredito,
                        nPayments,
                        dateFirstPaymentUTC,
                      );

                      Map<String, dynamic> nextPaymentData =
                          await VehiclesconService()
                              .getNextPaymentDate(idcredito.toString());

                      DateTime? firstPaymentDate =
                          nextPaymentData.containsKey('fecExpi') &&
                                  nextPaymentData['fecExpi'] != null
                              ? DateTime.parse(
                                  nextPaymentData['fecExpi'].toString())
                              : null;

                      if (firstPaymentDate != null) {
                        await VehiclesconService().insertManagementControlCd(
                          widget.idMainAccount.toString(),
                          widget.vehicle['id'].toString(),
                          firstPaymentDate,
                        );

                        debugPrint(
                            '✅ Primera fecha obtenida y enviada: $firstPaymentDate');
                      } else {
                        debugPrint(
                            '❌ No se encontró la primera fecha de pago.');
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Por favor ingrese un número válido para el plazo'),
                      ));
                    }

                    debugPrint("✅ Notificación enviada con éxito.");
                    showTopSnackBar(
                        Overlay.of(context),
                        Material(
                            color: Colors.transparent,
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 0, 155, 85),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(children: [
                                const Icon(Icons.check,
                                    color: Colors.white, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(
                                  'Crédito creado con exitosamente.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: screenWidth * 0.034,
                                    fontWeight: FontWeight.normal,
                                  ),
                                )),
                              ]),
                            )));
                    success = true;
                  } catch (e) {
                    debugPrint("❌ Error al crear crédito: $e");
                    Navigator.of(context).pop();
                    showErrorDialog(context);
                  }

                  if (success) {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(true);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Por favor completa todos los campos')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0886B5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              ),
              child: Text('Crear Crédito',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
            ),
          ],
        );
      },
    );
  }

  void _updateCredit() async {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    DateTime? fechaInicio;
    DateTime? dateFirstPayment;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Lottie.asset(
                'assets/loading.json',
                height: screenHeight * 0.1,
                width: screenHeight * 0.1,
                repeat: true,
              ),
            ));

    try {
      credit = await VehiclesconService().obtenerCreditos(widget.idMainAccount);
    } catch (e) {
      print("Error al cargar datos: $e");
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
                    "Error al cargar creditos.",
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

    List<Map<String, dynamic>> creditos = await VehiclesconService()
        .getCreditos(
            widget.idMainAccount.toString(), widget.vehicle['id'].toString());

    Navigator.of(context).pop(); // Cerrar el diálogo de carga

    if (creditos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró información del seguro')),
      );
      return;
    }

    Map<String, dynamic> creditoActual = creditos[0];

    String? selectedCreditos = credit
        .firstWhere((comp) => comp['name'] == creditoActual['name'],
            orElse: () => {'id': null})['id']
        ?.toString();

    try {
      fechaInicio = DateTime.parse(creditoActual['fechaInicio'].toString());
      dateFirstPayment =
          DateTime.parse(creditoActual['dateFirstPayment'].toString());
      fechaInicioController.text = _formatDate(fechaInicio);
      dateFirstPaymentController.text = _formatDate(dateFirstPayment);
    } catch (e) {
      debugPrint("Error al parsear fechas: $e");
      fechaInicio = DateTime.now();
      dateFirstPayment = DateTime.now();
    }

    Future<void> selectDate(BuildContext context, bool isFechaInicio) async {
      final screenHeight = MediaQuery.of(context).size.height;
      final screenWidth = MediaQuery.of(context).size.width;

      BottomPicker.date(
        pickerTitle: Text(
          isFechaInicio ? "Fecha inicio" : "Fecha de vencimiento ",
          style: TextStyle(fontSize: screenWidth * 0.037),
        ),
        dismissable: true,
        pickerDescription: SizedBox(height: screenHeight * 0.03),
        initialDateTime: isFechaInicio
            ? fechaInicio ?? DateTime.now()
            : dateFirstPayment ?? DateTime.now(),
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
              dateFirstPayment = selectedDate;
              dateFirstPaymentController.text = _formatDate(selectedDate);
            }
          });
        },
        onCloseButtonPressed: () {
          print("Picker cerrado");
        },
        displayCloseIcon: true,
        buttonContent: const Icon(Icons.check, color: Colors.white),
        buttonStyle: BoxDecoration(
          color: const Color(0xFF0886B5),
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
                  'Actualizar Crédito',
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
                  "Crédito",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: DropdownButtonFormField2<String>(
                    value: selectedCreditos,
                    decoration: InputDecoration(
                       contentPadding: const EdgeInsets.symmetric(
                                    vertical: 13, horizontal: 12),
                      prefixIcon: const Icon(
                        Icons.credit_card,
                        size: 15,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                    ),
                    isExpanded: true,
                    items: credit.map((compania) {
                      return DropdownMenuItem<String>(
                        value: compania['id'].toString(),
                        child: Text(compania['name'],
                            style: TextStyle(fontSize: screenWidth * 0.031)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCreditos = value;
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                    const Icon(Icons.monetization_on, size: 15),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  borderSide:
                                      const BorderSide(color: Colors.black),
                                ),
                                isDense: true,
                                counterText: ''),
                            style: TextStyle(fontSize: screenWidth * 0.031),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(12),
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
                            "Enganche",
                            style: TextStyle(
                              fontSize: screenWidth * 0.031,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextField(
                            controller: engancheController,
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
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(12),
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
                            "Interés",
                            style: TextStyle(
                              fontSize: screenWidth * 0.031,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextField(
                            controller: interesController,
                            decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.percent,
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
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            keyboardType: TextInputType.number,
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
                            "Plazo (meses)",
                            style: TextStyle(
                              fontSize: screenWidth * 0.031,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextField(
                            controller: plazoController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.timer,
                                size: 15,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide:
                                    const BorderSide(color: Colors.black),
                              ),
                            ),
                            style: TextStyle(fontSize: screenWidth * 0.031),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
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
                            "Comisión",
                            style: TextStyle(
                              fontSize: screenWidth * 0.031,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextField(
                            controller: comisionController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.money_off,
                                size: 15,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide:
                                    const BorderSide(color: Colors.black),
                              ),
                            ),
                            style: TextStyle(fontSize: screenWidth * 0.031),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(12),
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
                            "Comisión Apertura",
                            style: TextStyle(
                              fontSize: screenWidth * 0.031,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextField(
                            controller: comisionAperturaController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                  Icons.account_balance_wallet,
                                  size: 15),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide:
                                    const BorderSide(color: Colors.black),
                              ),
                            ),
                            style: TextStyle(fontSize: screenWidth * 0.031),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                    prefixIcon: const Icon(Icons.calendar_today, size: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                  ),
                  readOnly: true,
                  onTap: () => selectDate(context, true),
                  style: TextStyle(fontSize: screenWidth * 0.031),
                ),
                const SizedBox(height: 8),
                Text(
                  "Fecha de primer pago",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextField(
                  controller: dateFirstPaymentController,
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
                  onTap: () => selectDate(context, false),
                  style: TextStyle(fontSize: screenWidth * 0.031),
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
                  borderRadius:
                      BorderRadius.circular(10), // ← Ajusta el redondeo aquí
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (fechaInicio != null) {
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

                  bool success = false;

                  try {
                    VehiclesconService dbService = VehiclesconService();
                    DateTime fechaInicioUTC = fechaInicio!.toUtc();
                    DateTime dateFirstPaymentUTC = dateFirstPayment!.toUtc();
                    await dbService.actualizarCredito(
                      widget.idMainAccount.toString(),
                      widget.vehicle['id'].toString(),
                      selectedCreditos!,
                      DateFormat('yyyy-MM-dd')
                          .format(DateTime.parse(fechaInicioUTC.toString())),
                      montoController.text,
                      engancheController.text,
                      interesController.text,
                      plazoController.text,
                      comisionController.text,
                      comisionAperturaController.text,
                      DateFormat('yyyy-MM-dd').format(
                          DateTime.parse(dateFirstPaymentUTC.toString())),
                    );

                    setState(() {
                      _creditFuture = obtenerCreditos();
                    });

                    List<Map<String, dynamic>> credito =
                        await VehiclesconService().getCreditos(
                      widget.idMainAccount.toString(),
                      widget.vehicle['id'].toString(),
                    );

                    if (credito.isEmpty) {
                      debugPrint("⚠ No hay crédito actualizado.");
                      return;
                    }

                    int idcredito = credito.first['id'];

                    String nameNotice = "vehicle_credit_updated";
                    Map<String, dynamic>? noticeTemplate =
                        await NotificationService().getNoticeByName(nameNotice);

                    if (noticeTemplate != null) {
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

                      String message = utf8.decode(messageBytes);
                      String formattedMessage = message.replaceAll(
                          "{vehicle_plate}", widget.vehicle['placas']);
                      String title = noticeTemplate['title'].replaceAll(
                          "{vehicle_plate}", widget.vehicle['placas']);

                      String finalMessage =
                          "$title|$formattedMessage|${noticeTemplate['icon']}";

                      final notificationData = {
                        'typeSource': Type,
                        'idOrigin': idcredito,
                        'typEvent': 2,
                        'date': DateTime.now().toIso8601String(),
                        'message': finalMessage,
                        'colNotice': 'credit_Edit',
                        'idMainAcoount': widget.idMainAccount.toString(),
                        'codUsGenerator': widget.userId.toString(),
                        'idDev': widget.userId.toString(),
                      };

                      debugPrint("notificationData: $notificationData");
                      await NotificationService()
                          .insertNotification(notificationData);
                    }

                    try {
                      String plazoActual = creditoActual['plazo'].toString();

                      if (plazoController.text.isNotEmpty &&
                          RegExp(r'^\d+$').hasMatch(plazoController.text)) {
                        DateTime fechaInicialActual = DateTime.parse(
                            creditoActual['dateFirstPayment'].toString());
                        DateTime nuevaFechaInicial = DateFormat('yyyy-MM-dd')
                            .parse(dateFirstPaymentUTC.toString());

                        if (plazoController.text != plazoActual ||
                            fechaInicialActual != nuevaFechaInicial) {
                          await VehiclesconService().UpdatePagosCredito(
                            widget.idMainAccount,
                            idcredito.toString(),
                            int.parse(plazoController.text),
                            nuevaFechaInicial,
                          );

                          debugPrint('Pagos actualizados correctamente');
                        } else {
                          debugPrint(
                              'No hay cambios en el plazo o la fecha inicial');
                        }
                      } else {
                        debugPrint('El plazo ingresado no es válido');
                      }
                    } catch (e) {
                      debugPrint('Error al actualizar los pagos: $e');
                    }

                    Map<String, dynamic> nextPaymentData =
                        await VehiclesconService()
                            .getNextPaymentDate(idcredito.toString());

                    DateTime? firstPaymentDate = nextPaymentData
                                .containsKey('fecExpi') &&
                            nextPaymentData['fecExpi'] != null
                        ? DateTime.parse(nextPaymentData['fecExpi'].toString())
                        : null;

                    if (firstPaymentDate != null) {
                      await VehiclesconService().updateManagementControlCd(
                        widget.idMainAccount.toString(),
                        widget.vehicle['id'].toString(),
                        firstPaymentDate,
                      );
                      debugPrint(
                          '✅ Primera fecha obtenida y enviada: $firstPaymentDate');
                    } else {
                      debugPrint('❌ No se encontró la primera fecha de pago.');
                    }

                    debugPrint("✅ Notificación enviada con éxito.");
                    showTopSnackBar(
                        Overlay.of(context),
                        Material(
                          color: Colors.transparent,
                          child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 0, 155, 85),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(children: [
                                const Icon(Icons.check,
                                    color: Colors.white, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Crédito actualizado exitosamente',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.034,
                                      color: Colors.white,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                )
                              ])),
                        ));

                    success = true;
                  } catch (e) {
                    debugPrint("❌ Error al actualizar crédito: $e");
                    Navigator.of(context).pop();
                    showErrorDialogup(context);
                  }

                  if (success) {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Por favor completa todos los campos')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0886B5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              ),
              child: Text('Actualizar Crédito',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
            ),
          ],
        );
      },
    );
  }

  void _deleteCredit() {
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
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 45),
            ],
          ),
          content: Text('¿Estás seguro de que deseas eliminar este crédito?',
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
                  borderRadius:
                      BorderRadius.circular(10), // ← Ajusta el redondeo aquí
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
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
                                "Eliminando crédito        ",
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
                  List<Map<String, dynamic>> credit =
                      await VehiclesconService().getCreditos(
                    widget.idMainAccount.toString(),
                    widget.vehicle['id'].toString(),
                  );

                  if (credit.isEmpty) {
                    debugPrint("No hay créditos para borrar");
                  }

                  int idCredit = credit.first['id'];

                  await VehiclesconService()
                      .eliminarCredito(widget.idMainAccount.toString(),
                          widget.vehicle['id'].toString())
                      .then((_) async {
                    String nameNotice = "vehicle_credit_deleted";
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

                    String formattedMessage = message.replaceAll(
                        "{vehicle_plate}", widget.vehicle['placas']);

                    String title = noticeTemplate['title'].replaceAll(
                        "{vehicle_plate}", widget.vehicle['placas']);

                    String finalMessage =
                        "$title|$formattedMessage|${noticeTemplate['icon']}";

                    debugPrint("Generando notificación por eliminar");

                    final notificationData = {
                      'typeSource': Type,
                      'idOrigin': idCredit,
                      'typEvent': 3,
                      'date': DateTime.now().toIso8601String(),
                      'message': finalMessage,
                      'colNotice': 'credit_Delete',
                      'idMainAcoount': widget.idMainAccount.toString(),
                      'codUsGenerator': widget.userId.toString(),
                      'idDev': widget.userId.toString(),
                    };

                    await NotificationService()
                        .insertNotification(notificationData);

                    await VehiclesconService().eliminarPayCredit(
                        widget.idMainAccount, idCredit.toString());

                    await VehiclesconService().deleteManagementControlCd(
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
                                    'Crédito eliminado exitosamente',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.034,
                                      color: Colors.white,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            )),
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
                    _creditData = obtenerCreditos();
                  });
                  Navigator.of(context).pop();
                } catch (e) {
                  debugPrint("Error al eliminar seguro: $e");
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

  Widget _buildInsuranceInfoCard(
    BuildContext context,
    String name,
    DateTime fechaInicio,
    int plazo,
    double enganche,
    double monto,
    int comision,
    int comisionApertura,
    DateTime dateFirstPayment,
    int interes,
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
                const Icon(Icons.credit_card, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
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
            const Divider(),
            Row(
              children: [
                const Icon(Icons.monetization_on,
                    color: Colors.black, size: 22),
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
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.attach_money, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Enganche: ',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: Colors.black,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  currencyFormat.format(enganche), // ← Aquí está el cambio

                  style: TextStyle(
                      fontSize: screenWidth * 0.032, color: Colors.grey[700]),
                )
              ],
            ),
            const SizedBox(height: 6),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.percent, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Interés: ',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
                Text(
                  '${interes.toString()} %',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032, color: Colors.grey[700]),
                )
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.timer, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Plazo: ',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: Colors.black,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  '${plazo.toString()} meses',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032, color: Colors.grey[700]),
                )
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.money_off, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Comision: ',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: Colors.black,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  currencyFormat.format(comision),
                  style: TextStyle(
                      fontSize: screenWidth * 0.032, color: Colors.grey[700]),
                )
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.account_balance_wallet,
                    color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Comisión de Apertura: ',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: Colors.black,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  currencyFormat.format(comisionApertura),
                  style: TextStyle(
                      fontSize: screenWidth * 0.032, color: Colors.grey[700]),
                )
              ],
            ),
            const SizedBox(height: 6),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.date_range, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Fecha de inicio',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: Colors.black,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  ' ${_formatDate(fechaInicio)} ',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Primer pago',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: Colors.black,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  ' ${_formatDate(dateFirstPayment)} ',
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

  Widget _buildLoadingIndicator(double screenHeight, double screenWidth) {
    return Center(
      child: SizedBox(
        height: screenHeight * 0.8,
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
  }

  Widget _buildEmptyState(double screenWidth) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.warning_rounded, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No se ha encontrado un crédito activo en este momento.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenWidth * 0.040,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Verifica que la información esté registrada',
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  PopupMenuEntry<String> _buildPopupMenuItem(
      BuildContext context, String value, String title, IconData icon) {
    final screenWidth = MediaQuery.of(context).size.width;

    return PopupMenuItem<String>(
      value: value,
      padding: EdgeInsets.zero,
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

  Widget _infoRow(IconData icon, String label, String value) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: const Color.fromARGB(255, 0, 0, 0)),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: TextStyle(
              fontSize: screenWidth * 0.032,
              color: Colors.black,
              fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style:
              TextStyle(fontSize: screenWidth * 0.032, color: Colors.grey[700]),
        ),
      ],
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'No disponible';

    try {
      if (date is DateTime) {
        return DateFormat('yyyy-MM-dd').format(date);
      } else if (date is String) {
        DateTime parsedDate = DateFormat('dd/MM/yyyy').parse(date);
        return DateFormat('yyyy-MM-dd').format(parsedDate);
      }
    } catch (e) {
      debugPrint("❌ Error al formatear fecha: $e");
    }

    return 'Formato inválido';
  }

  Widget _buildVigenciaCardWithIcon(String datepay) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    String vigenciaTexto;
    Color vigenciaColor;
    IconData vigenciaIcon;

    if (datepay.isEmpty) {
      vigenciaTexto = 'Sin fecha de pago';
      vigenciaColor = Colors.grey[700]!;
      vigenciaIcon = Icons.check_circle;
    } else {
      try {
        DateTime vencimiento = DateFormat('yyyy-MM-dd').parse(datepay);
        Duration diferencia = vencimiento.difference(DateTime.now());

        if (diferencia.inDays > 0) {
          vigenciaTexto =
              'Tu próximo pago es dentro de ${diferencia.inDays} días.';
          vigenciaColor = Colors.green;
          vigenciaIcon = Icons.date_range;
        } else if (diferencia.inDays == 0) {
          vigenciaTexto =
              '¡Hoy es el último día! Realizá el pago para evitar cargos adicionales.';
          vigenciaColor = Colors.orange;
          vigenciaIcon = Icons.warning;
        } else {
          vigenciaTexto = 'Venció hace ${diferencia.inDays.abs()} días';
          vigenciaColor = Colors.red;
          vigenciaIcon = Icons.error;
        }
      } catch (e) {
        vigenciaTexto = 'Fecha inválida';
        vigenciaColor = Colors.grey[700]!;
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

  bool hasCreatePermission(String permission) {
    return (int.parse(permission) & 4) == 4 || (int.parse(permission) & 1) == 1;
  }
}
