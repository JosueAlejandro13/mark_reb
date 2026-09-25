import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/pages/Error_/ClientErrrorPage.dart';
import 'package:mark_v3/services/ConnectionRoutes_/RoutesCon_service.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

//Autor: Josue Hernandez
class DeliverPage extends StatefulWidget {
  final String clientId;
  final String idMainAccount;
  final String idAssignClients;

  const DeliverPage(
      {super.key,
      required this.clientId,
      required this.idMainAccount,
      required this.idAssignClients});

  @override
  _DeliverPageState createState() => _DeliverPageState();
}

class _DeliverPageState extends State<DeliverPage> {
  bool isLoading = true;

  final RoutesconService dbService = RoutesconService();

  String clientName = '';
  String clientAddress = '';
  String clientstreetNum = '';
  String clientintNum = '';
  String clientcolonia = '';
  String clientdelegacion = '';
  String clientciudad = '';
  String clientpais = '';
  String clientcp = '';
  String clienttelefono = '';
  String clientmail = '';
  String clientcod = '';
  List<Map<String, dynamic>> products = [];
  List<TextEditingController> quantityControllers = [];

  Future<void> loadClientData() async {
    setState(() {
      isLoading = true;
    });

    try {
      debugPrint(
          'clientId: ${widget.clientId}, idMainAccount: ${widget.idMainAccount}, asigg: ${widget.idAssignClients}');

      final clientData =
          await dbService.obtenerCliente(widget.clientId, widget.idMainAccount);
      final productData = await dbService.obtenerCapacidadYProductosPorCliente(
          int.parse(widget.clientId),
          widget.idMainAccount,
          widget.idMainAccount);

      setState(() {
        clientName = clientData?['namClient'] ?? '';
        clientAddress = clientData?['calle'] ?? '';
        clientstreetNum = clientData?['streetNum'] ?? '';
        clientintNum = clientData?['intNum'] ?? '';
        clientcolonia = clientData?['colonia'] ?? '';
        clientdelegacion = clientData?['delegacion'] ?? '';
        clientciudad = clientData?['ciudad'] ?? '';
        clientpais = clientData?['pais'] ?? '';
        clientcp = clientData?['cp'] ?? '';
        clienttelefono = clientData?['telefono'] ?? '';
        clientmail = clientData?['mail'] ?? '';
        clientcod = clientData?['cod'] ?? '';
        products = productData;
        quantityControllers =
            List.generate(products.length, (index) => TextEditingController());
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Tipo de error: ${e.runtimeType}');
      debugPrint('Error: $e');
      if (e.toString().contains('SocketException')) {
        debugPrint('SocketException: Error de conexión.');

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
      } else if (e.toString().contains('TimeoutException')) {
        debugPrint('TimeoutException: Tiempo de espera excedido.');

        if (mounted) {
          await Navigator.of(context).push(
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
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ClientErrrorPage(
                onRetry: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => widget),
                  );
                },
              ),
            ),
          );
        }
        debugPrint('Error al cargar los datos del cliente: $e');
      }

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await loadClientData();
  }

  @override
  void initState() {
    super.initState();
    debugPrint("Valor de clientId en DeliverPage: ${widget.clientId}");
    loadClientData();
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
        onRefresh: _refreshData,
        color: Colors.black,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(seconds: 5),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 250, 250, 250),
                    Color.fromARGB(255, 205, 240, 255),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            isLoading
                ? Center(
                    child: Lottie.asset(
                    'assets/loading.json',
                    width: screenWidth * 0.2,
                    height: screenHeight * 0.2,
                    repeat: true,
                  ))
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Entrega de Productos',
                                style: TextStyle(
                      fontSize: screenWidth * 0.050,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,),
                            textAlign: TextAlign.left,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 6,
                          color: const Color.fromARGB(255, 255, 255, 255),
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Datos del Cliente',
                                  style: TextStyle(
                                      fontSize: screenWidth * 0.037,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text('Nombre: $clientName',
                                    style: TextStyle(
                                        fontSize: screenWidth * 0.034),
                                    softWrap: true),
                                const SizedBox(height: 8),
                                Text(
                                  clientcod,
                                  style:
                                      TextStyle(fontSize: screenWidth * 0.034),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                    'Dirección: $clientAddress, $clientstreetNum, $clientintNum, $clientcolonia, $clientdelegacion, $clientciudad, $clientcp, $clientpais.',
                                    style: TextStyle(
                                        fontSize: screenWidth * 0.034),
                                    softWrap: true),
                                const SizedBox(height: 8),
                                Text('Contacto: $clienttelefono, $clientmail',
                                    style: TextStyle(
                                        fontSize: screenWidth * 0.034),
                                    softWrap: true),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 6,
                          color: const Color.fromARGB(255, 255, 255, 255),
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Productos a Entregar',
                                  style: TextStyle(
                                      fontSize: screenWidth * 0.037,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Column(
                                  children:
                                      List.generate(products.length, (index) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Wrap(
                                              alignment: WrapAlignment.start,
                                              spacing: 8.0,
                                              runSpacing: 4.0,
                                              children: [
                                                Text(
                                                  'Capacidad: ${products[index]['capacity']} ',
                                                  style: TextStyle(
                                                      fontSize:
                                                          screenWidth * 0.032),
                                                ),
                                                Text(
                                                  'Código: ${products[index]['codProduct']}  ',
                                                  style: TextStyle(
                                                      fontSize:
                                                          screenWidth * 0.032),
                                                ),
                                                Text(
                                                  'Producto: ${products[index]['product_name'] ?? 'Producto desconocido'}',
                                                  style: TextStyle(
                                                      fontSize:
                                                          screenWidth * 0.032),
                                                ),
                                                Text(
                                                  'Categoria: ${products[index]['categoria']}',
                                                  style: TextStyle(
                                                      fontSize:
                                                          screenWidth * 0.032),
                                                ),
                                                Text(
                                                  'Costo: \$${double.parse(products[index]['costo'].toString()).toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                      fontSize:
                                                          screenWidth * 0.032),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 50,
                                            child: TextField(
                                              controller:
                                                  quantityControllers[index],
                                              keyboardType:
                                                  TextInputType.number,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontSize:
                                                      screenWidth * 0.032),
                                              decoration: InputDecoration(
                                                labelText:
                                                    '${products[index]['unidad']}',
                                                border: OutlineInputBorder(
                                                  borderSide: const BorderSide(
                                                      color: Colors.grey,
                                                      width: 1.0),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                isDense: true,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 6,
                                                        horizontal: 8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 6,
                          color: const Color.fromARGB(255, 255, 255, 255),
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Comentarios',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.033,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextField(
                                    maxLines: 2,
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.032,
                                      fontWeight: FontWeight.normal,
                                    ),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                          width: 1.0,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      hintText: 'Escribe tus comentarios',
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        vertical: 6,
                                        horizontal: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              showTopSnackBar(
                                Overlay.of(context),
                                Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color:
                                          const Color.fromARGB(255, 0, 155, 85),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check,
                                            color: Colors.white, size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            "Productos entregados",
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
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: const Color(0xFF0886B5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              minimumSize: const Size(200, 12),
                            ),
                            child: Text(
                              'Entregar',
                              style: TextStyle(fontSize: screenWidth * 0.030),
                            ),
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
}
