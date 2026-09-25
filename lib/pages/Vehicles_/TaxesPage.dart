import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bottom_picker/bottom_picker.dart';
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
class TaxesPage extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  final String taxesPermission;
  final String circulationCardPermission;
  final String idMainAccount;
  final String userId;

  const TaxesPage({
    super.key,
    required this.circulationCardPermission,
    required this.vehicle,
    required this.taxesPermission,
    required this.idMainAccount,
    required this.userId,
  });

  @override
  _TaxesPageState createState() => _TaxesPageState();
}

class _TaxesPageState extends State<TaxesPage> {
  late Future<List<Map<String, dynamic>>> _impuestos;
  late TextEditingController _yearController;
  late TextEditingController _paymentDateController;
  late TextEditingController _expiryDateController;
  late TextEditingController _tenancyAmountController;
  late TextEditingController _renewalAmountController;
  bool _hasTaxes = false;
  late String Type;

  final currencyFormatter = NumberFormat.simpleCurrency(locale: 'es_MX');

  @override
  void initState() {
    super.initState();

    _yearController = TextEditingController();
    _paymentDateController = TextEditingController();
    _expiryDateController = TextEditingController();
    _tenancyAmountController = TextEditingController();
    _renewalAmountController = TextEditingController();

    _checkTaxes().catchError((error) {
      _handleError(error);
    });

    _TypeSource();

    _impuestos = VehiclesconService()
        .obtenerImpuestosPorVehiculo(
            widget.vehicle['id'].toString(), widget.idMainAccount.toString())
        .then((data) {
      if (data.isNotEmpty) {
        var impuesto = data[0];
        _yearController.text = impuesto['year'].toString();
        _paymentDateController.text = _formatDate(impuesto['fechaPago']);
        _expiryDateController.text = _formatDate(impuesto['fechaExpiracion']);
        _tenancyAmountController.text = impuesto['montoTenencia'].toString();
        _renewalAmountController.text = impuesto['montoRefrendo'].toString();
      }
      return data;
    }).catchError((error) {
      _handleError(error);
      return null;
    });
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

  Future<void> _TypeSource() async {
    if (!mounted) return;
    try {
      Map<String, dynamic> data =
          await NotificationService().gettypSource('vehic_taxs');

      if (mounted) {
        setState(() {
          Type = data['id'].toString();
        });
      }
    } catch (e) {
      debugPrint("Error al obtener el tipo de fuente: $e");
    }
  }

  Future<void> _checkTaxes() async {
    List<Map<String, dynamic>> data = await VehiclesconService()
        .obtenerImpuestosPorVehiculo(
            widget.vehicle['id'].toString(), widget.idMainAccount.toString());
    setState(() {
      _hasTaxes = data.isNotEmpty;
    });
  }

  Future<void> _refreshData() async {
    setState(() {
      _impuestos = VehiclesconService().obtenerImpuestosPorVehiculo(
          widget.vehicle['id'].toString(), widget.idMainAccount.toString());
    });
    await _checkTaxes();
  }

  @override
  void dispose() {
    _yearController.dispose();
    _paymentDateController.dispose();
    _expiryDateController.dispose();
    _tenancyAmountController.dispose();
    _renewalAmountController.dispose();

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

                if (_hasTaxes && hasEditPermission(widget.taxesPermission)) {
                  menuItems.add(_buildPopupMenuItem(
                      context, 'edit', 'Editar', Icons.edit));
                }
                if (_hasTaxes && hasDeletePermission(widget.taxesPermission)) {
                  menuItems.add(_buildPopupMenuItem(
                      context, 'delete', 'Eliminar', Icons.delete));
                }
                if (hasCreatePermissio(widget.taxesPermission)) {
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
                      _updateTax();
                    } else if (value == 'delete') {
                      _deleteTaxes();
                    } else if (value == 'create') {
                      _mostrarDialogoCrearImpuesto();
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
                      'Impuestos - ${widget.vehicle['make']} ${widget.vehicle['model']}',
                      style: TextStyle(
                          fontSize: screenWidth * 0.050,
                          color: Colors.black,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _impuestos,
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
                          return SizedBox(
                            height: MediaQuery.of(context).size.height * 0.8,
                            child: const Center(
                                child: Text('Error al cargar los impuestos')),
                          );
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return SizedBox(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.warning_rounded,
                                    size: 64,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No se encontraron impuestos.',
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
                          );
                        } else {
                          List<Map<String, dynamic>> impuestos = snapshot.data!;
                          return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: impuestos.length,
                              itemBuilder: (context, index) {
                                var impuesto = impuestos[index];

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    _buildTaxInfoCard(
                                      context,
                                      'Año: ${impuesto['year']}',
                                      impuesto['fechaPago'],
                                      impuesto['fechaExpiracion'],
                                      double.parse(
                                          impuesto['montoTenencia'].toString()),
                                      double.parse(
                                          impuesto['montoRefrendo'].toString()),
                                      impuesto['status'],
                                      impuesto['id'].toString(),
                                    ),
                                    const SizedBox(height: 20),
                                    _buildVigenciaCardWithIcon(impuesto),
                                  ],
                                );
                              });
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

  String _formatDate(dynamic date) {
    if (date is DateTime) {
      return DateFormat('dd/MM/yyyy').format(date);
    } else if (date is String) {
      try {
        DateTime parsedDate = DateFormat('yyyy-MM-dd').parse(date);
        return DateFormat('dd/MM/yyyy').format(parsedDate);
      } catch (e) {
        debugPrint('Error al formatear la fecha: $e');
        return '';
      }
    }
    return '';
  }

  Widget _buildTaxInfoCard(
      BuildContext context,
      String title,
      dynamic fechaPago,
      dynamic fechaExpiracion,
      double montoTenencia,
      double montoRefrendo,
      int status,
      String idImpuesto) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                  fontSize: screenWidth * 0.034,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            const SizedBox(height: 4),
            const Divider(),
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Fecha de Pago: ',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: screenWidth * 0.032,
                      color: const Color.fromARGB(255, 0, 0, 0)),
                ),
                Text(
                  _formatDate(fechaPago),
                  style: TextStyle(
                      fontSize: screenWidth * 0.032, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Fecha de Expiración: ',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: screenWidth * 0.032,
                      color: const Color.fromARGB(255, 0, 0, 0)),
                ),
                Text(
                  _formatDate(fechaExpiracion),
                  style: TextStyle(
                      fontSize: screenWidth * 0.032, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.attach_money, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Monto Tenencia: ',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 0, 0, 0)),
                ),
                Text(
                  currencyFormat.format(montoTenencia), // ← Aquí está el cambio

                  style: TextStyle(
                      fontSize: screenWidth * 0.032, color: Colors.grey[600]),
                )
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.attach_money, color: Colors.black, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Monto Refrendo: ',
                  style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 0, 0, 0)),
                ),
                Text(
                  currencyFormat.format(montoRefrendo), // ← Aquí está el cambio
                  style: TextStyle(
                      fontSize: screenWidth * 0.032, color: Colors.grey[600]),
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
  void _updateTax() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
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
                  'Actualizar Impuesto',
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Año del Impuesto",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildTextField(
                  controller: _yearController,
                  prefixIcon: Icons.calendar_today,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Fecha de Pago",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildDateField(
                  controller: _paymentDateController,
                ),
                const SizedBox(height: 8),
                Text(
                  "Fecha de Expiración",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildDateField(
                  controller: _expiryDateController,
                ),
                const SizedBox(height: 8),
                Text(
                  "Monto Tenencia",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildTextField(
                  controller: _tenancyAmountController,
                  prefixIcon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                ),
                const SizedBox(height: 8),
                Text(
                  "Monto Refrendo",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildTextField(
                  controller: _renewalAmountController,
                  prefixIcon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
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
                  )),
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
            ),
            ElevatedButton(
              onPressed: () async {
                await _saveTaxChanges(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0886B5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              ),
              child: Text('Actualizar Impuesto',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.45,
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        decoration: InputDecoration(
            prefixIcon: Icon(
              prefixIcon,
              size: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: const BorderSide(color: Colors.black),
            ),
            isDense: true,
            counterText: ""),
        style: TextStyle(fontSize: screenWidth * 0.031),
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.45,
      child: TextField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          prefixIcon: const Icon(
            Icons.calendar_today,
            size: 15,
          ),
        ),
        style: TextStyle(fontSize: screenWidth * 0.031),
        onTap: () async {
          DateTime initialDate;
          try {
            initialDate = controller.text.isNotEmpty
                ? DateFormat('dd/MM/yyyy').parse(controller.text)
                : DateTime.now();
          } catch (e) {
            initialDate = DateTime.now();
          }

          BottomPicker.date(
            pickerTitle: Text(
              "Selecciona una fecha",
              style: TextStyle(fontSize: screenWidth * 0.037),
            ),
            pickerDescription: SizedBox(height: screenHeight * 0.03),
            initialDateTime: initialDate,
            minDateTime: DateTime(2000),
            maxDateTime: DateTime(2101),
            pickerTextStyle:
                TextStyle(fontSize: screenWidth * 0.050, color: Colors.black),
            onSubmit: (selectedDate) {
              controller.text = DateFormat('dd/MM/yyyy').format(selectedDate);
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
        },
      ),
    );
  }

  Future<void> _saveTaxChanges(BuildContext context) async {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.5,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                child: Text(
                  "Guardando cambios        ",
                  style: TextStyle(fontSize: screenWidth * 0.033),
                ),
              ),
              const SizedBox(width: 20),
              Lottie.asset(
                "assets/loading.json",
                height: screenHeight * 0.08,
                width: screenHeight * 0.08,
                repeat: true,
              )
            ])),
      ),
    );

    try {
      final paymentDate =
          DateFormat('dd/MM/yyyy').parse(_paymentDateController.text);

      final formattedPaymentDate = DateFormat('yyyy-MM-dd').format(paymentDate);

      final expiryDate =
          DateFormat('dd/MM/yyyy').parse(_expiryDateController.text);

      final formattedExpiryDate = DateFormat('yyyy-MM-dd').format(expiryDate);

      await VehiclesconService().actualizarImpuesto(
        widget.vehicle['id'].toString(),
        widget.idMainAccount.toString(),
        int.tryParse(_yearController.text) ?? 0,
        formattedPaymentDate,
        formattedExpiryDate,
        double.tryParse(_tenancyAmountController.text) ?? 0.0,
        double.tryParse(_renewalAmountController.text) ?? 0.0,
      );
      setState(() {
        _impuestos = VehiclesconService().obtenerImpuestosPorVehiculo(
            widget.vehicle['id'].toString(), widget.idMainAccount.toString());
      });

      List<Map<String, dynamic>> impuestos =
          await VehiclesconService().obtenerImpuestosPorVehiculo(
        widget.vehicle['id'].toString(),
        widget.idMainAccount.toString(),
      );

      if (impuestos.isEmpty) {
        debugPrint("⚠ No hay impuestos para actualizado.");
        return;
      }

      int idImpuesto = impuestos.first['id'];

      String nameNotice = "vehicle_tax_payment_updated";
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

      String year = _yearController.text;
      String paymentD = _paymentDateController.text;
      String expiryD = _expiryDateController.text;

      String formattedMessage = message
          .replaceAll("{tax_period}", year)
          .replaceAll("{vehicle_plate}", widget.vehicle['placas'])
          .replaceAll("{payment_date}", paymentD)
          .replaceAll("{due_date}", expiryD);

      String title = noticeTemplate['title']
          .replaceAll("{vehicle_plate}", widget.vehicle['placas']);

      String finalMessage =
          "$title|$formattedMessage|${noticeTemplate['icon']}";

      debugPrint("📢 Generando notificación por actualizado de impuestos...");

      final notificationData = {
        'typeSource': Type,
        'idOrigin': idImpuesto,
        'typEvent': 2,
        'date': DateTime.now().toIso8601String(),
        'message': finalMessage,
        'colNotice': 'tax_Edit',
        'idMainAcoount': widget.idMainAccount.toString(),
        'codUsGenerator': widget.userId.toString(),
        'idDev': widget.userId.toString(),
      };

      await NotificationService().insertNotification(notificationData);

      debugPrint("✅ Notificación enviada con éxito.");

      await VehiclesconService().updateManagementControlTax(
          widget.idMainAccount.toString(),
          widget.vehicle['id'].toString(),
          formattedExpiryDate);

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
                const Icon(Icons.check, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Impuesto actualizado exitosamente.",
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
      debugPrint('Error al actualizar el impuesto: $e');
      Navigator.of(context).pop();
      showErrorDialogup(context);
    }
  }

  void _deleteTaxes() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final currentContext = context;

    showDialog(
      context: currentContext,
      builder: (BuildContext dialogContext) {
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
          content: Text('¿Estás seguro de que deseas eliminar los impuestos?',
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
                  )),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('Cancelar',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    content: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: screenWidth * 0.5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              "Eliminando impuestos   ",
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
                  List<Map<String, dynamic>> impuestos =
                      await VehiclesconService().obtenerImpuestosPorVehiculo(
                    widget.vehicle['id'].toString(),
                    widget.idMainAccount.toString(),
                  );

                  if (impuestos.isEmpty) {
                    debugPrint("⚠ No hay impuestos para eliminar.");
                    return;
                  }

                  int idImpuesto = impuestos.first['id'];

                  await VehiclesconService().eliminarImpuestosPorVehiculo(
                    widget.vehicle['id'].toString(),
                    widget.idMainAccount.toString(),
                  );

                  String nameNotice = "vehicle_tax_payment_deleted";
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

                  String year = _yearController.text;
                  String paymentD = _paymentDateController.text;
                  String expiryD = _expiryDateController.text;

                  String formattedMessage = message
                      .replaceAll("{tax_period}", year)
                      .replaceAll("{vehicle_plate}", widget.vehicle['placas'])
                      .replaceAll("{payment_date}", paymentD)
                      .replaceAll("{due_date}", expiryD);

                  String title = noticeTemplate['title']
                      .replaceAll("{vehicle_plate}", widget.vehicle['placas']);

                  String finalMessage =
                      "$title|$formattedMessage|${noticeTemplate['icon']}";

                  debugPrint(
                      "📢 Generando notificación por eliminación de impuestos...");

                  final notificationData = {
                    'typeSource': Type,
                    'idOrigin': idImpuesto,
                    'typEvent': 3,
                    'date': DateTime.now().toIso8601String(),
                    'message': finalMessage,
                    'colNotice': 'tax_Delete',
                    'idMainAcoount': widget.idMainAccount.toString(),
                    'codUsGenerator': widget.userId.toString(),
                    'idDev': widget.userId.toString(),
                  };

                  await NotificationService()
                      .insertNotification(notificationData);

                  debugPrint("✅ Notificación enviada con éxito.");

                  await VehiclesconService().deleteManagementControlTax(
                    widget.idMainAccount.toString(),
                    widget.vehicle['id'].toString(),
                  );

                  if (!mounted) return;
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
                                "Impuesto eliminado exitosamente.",
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
                      Navigator.of(currentContext).pop();
                    }
                  });
                } catch (e) {
                  debugPrint('❌ Error al eliminar los impuestos: $e');
                  if (!mounted) return;

                  Navigator.of(currentContext).pop();
                  showErrorDialodel(context);
                }
              },
              style: TextButton.styleFrom(
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
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoCrearImpuesto() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final TextEditingController yearController = TextEditingController();
    final TextEditingController paymentDateController = TextEditingController();
    final TextEditingController expiryDateController = TextEditingController();
    final TextEditingController tenancyAmountController =
        TextEditingController();
    final TextEditingController renewalAmountController =
        TextEditingController();

    void validarYCrearImpuesto() async {
      if (paymentDateController.text.isEmpty) {
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
                      "Por favor seleccione la fecha de pago.",
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
      if (expiryDateController.text.isEmpty) {
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
                      "Por favor seleccione la fecha de expiración.",
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
      final paymentDate = DateTime.tryParse(paymentDateController.text);
      final expiryDate = DateTime.tryParse(expiryDateController.text);
      if (paymentDate == null || expiryDate == null) {
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
      if (paymentDate.isAfter(expiryDate)) {
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
                      "La fecha de pago no puede ser mayor que la fecha de expiración.",
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
                    "Creando impuesto    ",
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
        int idImpuesto = await VehiclesconService().crearImpuesto(
          widget.vehicle['id'].toString(),
          widget.vehicle['idMainAccount'].toString(),
          int.tryParse(yearController.text) ?? 0,
          paymentDateController.text,
          expiryDateController.text,
          double.tryParse(tenancyAmountController.text) ?? 0.0,
          double.tryParse(renewalAmountController.text) ?? 0.0,
        );
        setState(() {
          _impuestos = VehiclesconService().obtenerImpuestosPorVehiculo(
              widget.vehicle['id'].toString(), widget.idMainAccount.toString());
        });

        String nameNotice = "vehicle_tax_payment_added";
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
            .replaceAll("{tax_period}", yearController.text)
            .replaceAll("{vehicle_plate}", widget.vehicle['placas'])
            .replaceAll("{payment_date}", paymentDateController.text)
            .replaceAll("{due_date}", expiryDateController.text);

        String title = noticeTemplate['title']
            .replaceAll("{vehicle_plate}", widget.vehicle['placas']);

        String finalMessage =
            "$title|$formattedMessage|${noticeTemplate['icon']}";

        debugPrint("📢 Generando notificación por crear de impuestos...");

        final notificationData = {
          'typeSource': Type,
          'idOrigin': idImpuesto,
          'typEvent': 1,
          'date': DateTime.now().toIso8601String(),
          'message': finalMessage,
          'colNotice': 'tax_New',
          'idMainAcoount': widget.idMainAccount.toString(),
          'codUsGenerator': widget.userId.toString(),
          'idDev': widget.userId.toString(),
        };

        await NotificationService().insertNotification(notificationData);

        debugPrint("✅ Notificación enviada con éxito.");

        await VehiclesconService().insertManagementControlTax(
          widget.vehicle['idMainAccount'].toString(),
          widget.vehicle['id'].toString(),
          DateFormat('yyyy-MM-dd').parse(expiryDateController.text),
        );

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
                  const Icon(Icons.check, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Impuesto creado exitosamente.",
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
        debugPrint('Error al crear el impuesto: $e');
        Navigator.of(context).pop();
        showErrorDialog(context);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
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
                  'Crear Impuesto',
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Año",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: TextField(
                    controller: yearController,
                    decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.calendar_today, size: 15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                        isDense: true,
                        counterText: ''),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                    ],
                    style: TextStyle(fontSize: screenWidth * 0.031),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Fecha de Pago",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: TextField(
                    controller: paymentDateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.calendar_today, size: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                    ),
                    style: TextStyle(fontSize: screenWidth * 0.031),
                    onTap: () async {
                      BottomPicker.date(
                        pickerTitle: Text(
                          "Selecciona la fecha de pago",
                          style: TextStyle(fontSize: screenWidth * 0.037),
                        ),
                        pickerDescription:
                            SizedBox(height: screenHeight * 0.03),
                        initialDateTime: DateTime.now(),
                        minDateTime: DateTime(2000),
                        maxDateTime: DateTime(2101),
                        pickerTextStyle: TextStyle(
                            fontSize: screenWidth * 0.050, color: Colors.black),
                        onSubmit: (pickedDate) {
                          setState(() {
                            paymentDateController.text =
                                DateFormat('yyyy-MM-dd').format(pickedDate);
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
                  "Fecha de Expiración",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: TextField(
                    controller: expiryDateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.calendar_today, size: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                    ),
                    style: TextStyle(fontSize: screenWidth * 0.031),
                    onTap: () async {
                      BottomPicker.date(
                        pickerTitle: Text(
                          "Selecciona la fecha de Expiración",
                          style: TextStyle(fontSize: screenWidth * 0.037),
                        ),
                        pickerDescription:
                            SizedBox(height: screenHeight * 0.03),
                        initialDateTime: DateTime.now(),
                        minDateTime: DateTime(2000),
                        maxDateTime: DateTime(2101),
                        pickerTextStyle: TextStyle(
                            fontSize: screenWidth * 0.050, color: Colors.black),
                        onSubmit: (pickedDate) {
                          setState(() {
                            expiryDateController.text =
                                DateFormat('yyyy-MM-dd').format(pickedDate);
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
                  "Monto Tenencia",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: TextField(
                    controller: tenancyAmountController,
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
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                    ],
                    style: TextStyle(fontSize: screenWidth * 0.031),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Monto Refrendo",
                  style: TextStyle(
                    fontSize: screenWidth * 0.031,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: TextField(
                    controller: renewalAmountController,
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
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                    ],
                    style: TextStyle(fontSize: screenWidth * 0.031),
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
              onPressed: validarYCrearImpuesto,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0886B5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              ),
              child: Text('Crear Impuesto',
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
    String? fechaVencimiento = data['fechaExpiracion']?.toString();
    String vigenciaTexto;
    Color vigenciaColor;
    IconData vigenciaIcon;

    if (fechaVencimiento == null || fechaVencimiento.isEmpty) {
      vigenciaTexto = 'Sin fecha de vencimiento';
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
