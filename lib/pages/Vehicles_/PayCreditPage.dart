import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/Error_/unexpectedErrorPage.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';
import 'package:mark_v3/services/ConnectionNotification_/NotificationCon_service.dart';
import 'package:mysql1/mysql1.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

//Autor: Josue Hernandez
class PayCreditPage extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  final String? creditoId;
  final String idMainAccount;
  final String userId;

  const PayCreditPage({
    super.key,
    required this.vehicle,
    required this.creditoId,
    required this.idMainAccount,
    required this.userId,
  });

  @override
  _PayCreditPageState createState() => _PayCreditPageState();
}

class _PayCreditPageState extends State<PayCreditPage> {
  final TextEditingController _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late String Type;
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _getPaymentHistory();
      await _TypeSource();
    } on SocketException catch (e) {
      debugPrint("❌ Error de conexión: $e");
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
      return;
    } on TimeoutException catch (e) {
      debugPrint("⏳ Tiempo de espera excedido: $e");
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
      return;
    } catch (e) {
      debugPrint("⚠️ Error inesperado: $e");
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
      return;
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
          await NotificationService().gettypSource("vehic_creditBreakdown");

      if (mounted) {
        setState(() {
          Type = data['id'].toString();
        });
      }
    } catch (e) {
      debugPrint("Error al obtener el tipo de fuente: $e");
    }
  }

  Future<void> _refreshData() async {
    await _getPaymentHistory();
  }

  Future<void> _getPaymentHistory() async {
    if (!mounted) return;
    try {
      List<Map<String, dynamic>> history =
          await VehiclesconService().getPaymentHistory(widget.creditoId!);
      if (mounted) {
        setState(() {
          _paymentHistory = history;
        });
      }
    } catch (e) {
      debugPrint("Error al obtener el historial de pagos: $e");
    }
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
            if (_isLoading) _buildLoadingIndicator(screenHeight, screenWidth),
            if (!_isLoading)
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registrar pago',
                        style: TextStyle(
                            fontSize: screenWidth * 0.050,
                            color: Colors.black,
                            fontWeight: FontWeight.bold),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.08),
                        child: Column(
                          children: [
                            const SizedBox(height: 30),
                            _buildPaymentForm(),
                            const SizedBox(height: 20),
                            _buildPaymentHistoryCard(),
                          ],
                        ),
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

  Widget _buildPaymentForm() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Ingrese el monto a pagar',
            style: TextStyle(
              fontSize: screenWidth * 0.036,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: screenWidth * 0.4,
            child: TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              maxLength: 10,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
              ],
              decoration: InputDecoration(
                labelText: 'Monto',
                labelStyle: TextStyle(fontSize: screenWidth * 0.031),
                prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                counterText: '',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingrese un monto válido';
                }
                if (value.length > 10) {
                  return 'Máximo 10 caracteres permitidos';
                }
                if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                  return 'Solo se permiten números';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'El monto debe ser mayor a 0';
                }
                return null;
              },
              style: TextStyle(fontSize: screenWidth * 0.031),
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: screenWidth * 0.3,
            child: ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
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
                                "Registrando pago        ",
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

                  Timer(const Duration(milliseconds: 50), () async {
                    try {
                      await _registrarPago();

                      Navigator.of(context).pop();
                    } catch (error) {
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
                                const Icon(Icons.error,
                                    color: Colors.white, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Error al registrar el pago. Intente nuevamente más tarde.",
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
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0886B5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(
                'Registrar Pago',
                style: TextStyle(
                  fontSize: screenWidth * 0.030,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryCard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Historial de Pagos',
              style: TextStyle(
                fontSize: screenWidth * 0.038,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(thickness: 1),
            const SizedBox(height: 10),
            _paymentHistory.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        "No hay pagos registrados",
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  )
                : SizedBox(
                    height: screenHeight * 0.45,
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _paymentHistory.length,
                      itemBuilder: (context, index) {
                        var pago = _paymentHistory[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green[700]),
                                  if (index < _paymentHistory.length - 1)
                                    Container(
                                      width: 3,
                                      height: 60,
                                      color: Colors.green[700],
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "#${pago['nPayment']}  - Monto pagado: ${currencyFormat.format(double.parse(pago['monto'].toString()))}",
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.033,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Fecha de pago: ${_formatDate(pago['fecPayment'])}\nFecha de vencimiento: ${_formatDate(pago['fecExpi'])}",
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.032,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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

  String _formatDate(dynamic date) {
    if (date == null) return 'No disponible';

    try {
      if (date is DateTime) {
        return DateFormat('yyyy-MM-dd').format(date);
      } else if (date is String) {
        DateTime parsedDate;

        if (date.contains('-')) {
          parsedDate = DateTime.parse(date);
        } else {
          parsedDate = DateFormat('dd/MM/yyyy').parse(date);
        }

        return DateFormat('yyyy-MM-dd').format(parsedDate);
      }
    } catch (e) {
      debugPrint("❌ Error al formatear fecha: $e");
    }

    return 'Formato inválido';
  }

  Future<void> _registrarPago() async {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final monto = _amountController.text;
    final creditoId = widget.creditoId;

    try {
      if (creditoId != null) {
        await _insertarPagoEnBaseDeDatos(creditoId, monto);
      } else {
        throw Exception('❌ No se encontró el ID del crédito');
      }
      Navigator.of(context).pop(true);

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
                    "Pago registrado correctamente: \$ $monto",
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
      _amountController.clear();
    } catch (e) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            "Error al registrar el pago",
            style: TextStyle(fontSize: screenWidth * 0.040),
          ),
          content: Text(
            "Vuelva a intentarlo más tarde.",
            style: TextStyle(
              fontSize: screenWidth * 0.030,
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
              child: Text('Aceptar',
                  style: TextStyle(fontSize: screenWidth * 0.030)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _insertarPagoEnBaseDeDatos(
      String creditoId, String monto) async {
    try {
      final service = VehiclesconService();

      int? insertedPaymentId =
          await service.insertRegistrarPagos(int.parse(creditoId), monto);

      Map<String, dynamic> nextPaymentDataMang =
          await VehiclesconService().getNextPaymentDate(creditoId.toString());

      DateTime? mang = nextPaymentDataMang.containsKey('fecExpi') &&
              nextPaymentDataMang['fecExpi'] != null
          ? DateTime.parse(nextPaymentDataMang['fecExpi'].toString())
          : null;

      String nameNotice = "vehicle_credit_payment_made";
      Map<String, dynamic>? noticeTemplate =
          await NotificationService().getNoticeByName(nameNotice);

      if (noticeTemplate == null) {
        throw Exception(
            "⚠ No se encontró la plantilla de notificación con nameNotice: $nameNotice");
      }

      List<int> messageBytes;
      if (noticeTemplate['message'] is Blob) {
        messageBytes = await (noticeTemplate['message'] as Blob).toBytes();
      } else if (noticeTemplate['message'] is List<int>) {
        messageBytes = noticeTemplate['message'] as List<int>;
      } else {
        throw Exception(
            "⚠ El campo 'message' no es un Blob ni una lista de bytes.");
      }

      String message;
      try {
        message = utf8.decode(messageBytes);
      } catch (e) {
        throw Exception("Error al decodificar el mensaje: $e");
      }

      String formattedMessage = message
          .replaceAll("{vehicle_plate}", widget.vehicle['placas'])
          .replaceAll(
              "{payment_date}", _formatDate(DateTime.now().toIso8601String()));

      String title = noticeTemplate['title']
          .replaceAll("{vehicle_plate}", widget.vehicle['placas']);

      String finalMessage =
          "$title|$formattedMessage|${noticeTemplate['icon']}";

      final notificationData = {
        'typeSource': Type,
        'idOrigin': insertedPaymentId,
        'typEvent': 1,
        'date': DateTime.now().toIso8601String(),
        'message': finalMessage,
        'colNotice': 'credit_Payment',
        'idMainAcoount': widget.idMainAccount.toString(),
        'codUsGenerator': widget.userId.toString(),
        'idDev': widget.userId.toString(),
      };

      await NotificationService().insertNotification(notificationData);

      if (mang != null) {
        await VehiclesconService().insertManagementControlCd(
            widget.idMainAccount.toString(),
            widget.vehicle['id'].toString(),
            mang);
      } else {
        throw Exception('❌ No se encontró la primera fecha de pago.');
      }
    } catch (e) {
      debugPrint('Error al registrar el pago: $e');
      // ignore: use_rethrow_when_possible
      throw e;
    }
  }
}
