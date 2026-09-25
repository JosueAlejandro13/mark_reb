import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/ServiceStation_/ServiceStatioRagePage.dart';
import 'package:mark_v3/services/ConnectionStation_/StationCon_service.dart';
import 'package:mark_v3/services/database_service.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../Error_/unexpectedErrorPage.dart';

class ServiceStationForm extends StatefulWidget {
  final String idMainAccount;
  final String idCollaborator;

  const ServiceStationForm(
      {super.key, required this.idMainAccount, required this.idCollaborator});

  @override
  _ServiceStationFormState createState() => _ServiceStationFormState();
}

class _ServiceStationFormState extends State<ServiceStationForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _litersController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _TypFuel;
  String? _gasType;
  String? _gasTypeName;
  String? _stationCode;

  final StationService dbService = StationService();
  final DatabaseService dbServiceF = DatabaseService();
  List<Map<String, dynamic>> _configurations = [];
  bool _isLoading = true;

  double? _latitude;
  double? _longitude;
  DateTime? _fecha;
  double? _regular;
  double? _premium;
  double? _diesel;
  double? _selectedFuelPrice;
  bool _isFuelValid = true;
  bool isCancelled = false;

  // ignore: prefer_final_fields
  List<List<int>> _allowedFuelCombinations = [
    [3, 4], //diesel
    [8, 9, 6, 7], //premium - regular
  ];

  @override
  void initState() {
    super.initState();
    debugPrint(
        "idMainAccount: ${widget.idMainAccount}, idCollaborator: ${widget.idCollaborator}");
    _loadAllData();
  }

  Future<void> _withLoading(Future<void> Function() action) async {
    if (isCancelled) return;
    setState(() {
      _isLoading = true;
    });
    try {
      await action();
    } finally {
      if (mounted && !isCancelled) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAllData() async {
    await _withLoading(() async {
      try {
        // Obtener la ubicación
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('El servicio de ubicación está deshabilitado.');
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            debugPrint('Permiso de ubicación denegado');
            return;
          }
        }

        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        if (!isCancelled && mounted) {
          setState(() {
            _latitude = position.latitude;
            _longitude = position.longitude;
          });
        }
        debugPrint('Ubicación obtenida: $_latitude, $_longitude');

        _TypFuel = StationService().getTypeFuel().catchError((e) {
          debugPrint("Error al obtener el typeFuel: $e");
          return [];
        });

        if (_latitude != null && _longitude != null && !isCancelled) {
          var data = await dbService.buscarEstacionCercanaConPrecio(
              _latitude!, _longitude!);

          if (data != null && mounted && !isCancelled) {
            debugPrint('Estación más cercana encontrada: ${data['code']}');

            setState(() {
              _stationCode = data['code'];
              _fecha = data['fecha'];
              _regular = data['regular'];
              _premium = data['premium'];
              _diesel = data['diesel'];
            });
          } else if (!isCancelled && mounted) {
            debugPrint('No se encontró ninguna estación cercana.');
            await Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => ServiceStationRagePage(
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

        if (!isCancelled) {
          final List<Map<String, dynamic>> config =
              await dbService.getresupply(widget.idCollaborator);
          debugPrint(
              'Datos obtenidos en _fetchgetresupplyConfiguration: $config');

          if (mounted && !isCancelled) {
            setState(() {
              _configurations = config;

              if (_configurations.isNotEmpty) {
                _gasType = _configurations.first['idtipoCombustibleNombre']
                    ?.toString();
                _gasTypeName = _configurations.first['tipoCombustibleNombre'];

                if (_gasType != null) {
                  int gasTypeInt = int.parse(_gasType!);

                  for (var combination in _allowedFuelCombinations) {
                    if (combination.contains(gasTypeInt)) {
                      _setFuelPrice(gasTypeInt);
                      break;
                    }
                  }
                }
              }
            });
          }
        }
      } catch (e) {
        if (!isCancelled) {
          _handleError(e);
        }
      }
    });
  }

  void cancelProcess() {
    setState(() {
      isCancelled = true;
    });
  }

  @override
  void dispose() {
    isCancelled = true;
    super.dispose();
  }

  void _handleError(Object e) {
    if (isCancelled) return;
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
      debugPrint('Error al obtener configuración de la ruta: $e');
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

  Future<void> _submitForm() async {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_configurations.isNotEmpty) {
        int idVehic = _configurations.first['idvehic'];
        String odom = _configurations.first['odom'].toString();

        debugPrint('🔹 Ejecutando EstacionesDeServicio...');
        debugPrint('📤 Datos a enviar:');
        debugPrint('idUs: ${widget.idCollaborator}');
        debugPrint('idSubAcco: ${widget.idMainAccount}');
        debugPrint('idVehic: $idVehic');
        debugPrint('Odom: $odom');
        debugPrint('Tipo de Combustible: $_gasType');
        debugPrint('Litros: ${_litersController.text}');

        // Mostrar el diálogo de carga
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
                      "Guardando cambios",
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
          await dbService.EstacionesDeServicio(
            id: 0,
            idUs: int.parse(widget.idMainAccount),
            idSubAcco: int.parse(widget.idCollaborator),
            idVehic: idVehic,
            odom: odom,
            codeES: _stationCode ?? '',
            typFuel: _gasType ?? '',
            datePrice: _fecha!.toUtc(),
            priceLts: _selectedFuelPrice != null
                ? _selectedFuelPrice.toString()
                : '0.0',
            lts: int.parse(_litersController.text),
            dateCreated: DateTime.now(),
          );

          Navigator.of(context, rootNavigator: true).pop();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text(
                "Reabastecimiento registrado",
                style: TextStyle(
                  fontSize: screenWidth * 0.040,
                  fontWeight: FontWeight.w500,
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
                      "Se ha registrado el reabastecimiento correctamente.",
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
                    Navigator.of(context).pop(true);
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
        } catch (e) {
          Navigator.of(context, rootNavigator: true).pop();

          debugPrint('❌ Error al enviar los datos: $e');
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
                        "Error al enviar los datos. Intente nuevamente más tarde.",
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
      } else {
        debugPrint('⚠️ No se encontraron datos en _configurations');
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
                      "No hay datos de vehículo disponibles.",
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
  }

  void _setFuelPrice(int idTipo) {
    if (idTipo == 3 || idTipo == 4) {
      _selectedFuelPrice = _diesel?.toDouble();
    } else if (idTipo == 6 || idTipo == 7) {
      _selectedFuelPrice = _regular?.toDouble();
    } else if (idTipo == 8 || idTipo == 9) {
      _selectedFuelPrice = _premium?.toDouble();
    } else {
      _selectedFuelPrice = null;
    }

    debugPrint(
        'Tipo de combustible: $idTipo, Precio seleccionado: $_selectedFuelPrice');

    setState(() {});
  }

  String _formatDate(dynamic date) {
    if (date is DateTime) {
      return DateFormat('dd/MM/yyyy').format(date);
    } else if (date is String) {
      DateTime parsedDate;
      try {
        parsedDate = DateTime.parse(date);
      } catch (e) {
        return date;
      }

      return DateFormat('dd/MM/yyyy').format(parsedDate);
    }
    return '';
  }

  Widget _buildFuelInfo(
      String label, String price, Color color, IconData icon) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: screenWidth * 0.050,
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.030,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '\$$price',
          style: TextStyle(
            fontSize: screenWidth * 0.030,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    double appBarHeight = 30.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight),
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
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Reabastecimiento',
                          style: TextStyle(
                            fontSize: screenWidth * 0.050,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 15),
                        Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(
                                20.0), // Más espacio interno
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.speed, // Icono de odómetro
                                      color: Colors.blue,
                                      size: screenWidth * 0.1,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Odómetro:  ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: screenWidth * 0.032,
                                      ),
                                    ),
                                    Text(
                                      _configurations.isNotEmpty
                                          ? _configurations.first['odom']
                                          : 'N/A',
                                      style: TextStyle(
                                        color:
                                            const Color.fromARGB(255, 0, 0, 0),
                                        fontSize: screenWidth * 0.030,
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(
                                  color: Colors.grey[300],
                                  thickness: 1,
                                  height: 24, // Espacio antes del divisor
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Fecha:   ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: screenWidth * 0.032,
                                      ),
                                    ),
                                    Text(
                                      _formatDate(_fecha?.toString() ?? 'N/A'),
                                      style: TextStyle(
                                        color:
                                            const Color.fromARGB(255, 0, 0, 0),
                                        fontSize: screenWidth * 0.030,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 20),
                                Center(
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _buildFuelInfo(
                                              'Regular',
                                              _regular?.toString() ?? 'N/A',
                                              Colors.green,
                                              Icons.local_gas_station),
                                          _buildFuelInfo(
                                              'Premium',
                                              _premium?.toString() ?? 'N/A',
                                              const Color.fromARGB(
                                                  255, 255, 0, 0),
                                              Icons.local_gas_station),
                                          _buildFuelInfo(
                                              'Diésel',
                                              _diesel?.toString() ?? 'N/A',
                                              const Color.fromARGB(
                                                  255, 0, 0, 0),
                                              Icons.local_gas_station),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 15),
                        Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 6,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Título "Registrar"
                                Text(
                                  'Registrar',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.040,
                                    color: const Color.fromARGB(255, 0, 0, 0),
                                  ),
                                ),
                                SizedBox(height: 20),
                                // Formulario
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: FutureBuilder<
                                                List<Map<String, dynamic>>>(
                                              future: _TypFuel,
                                              builder: (context, snapshot) {
                                                if (snapshot.hasError) {
                                                  return Text(
                                                      'Error: ${snapshot.error}',
                                                      style: TextStyle(
                                                          fontSize:
                                                              screenWidth *
                                                                  0.028));
                                                }

                                                if (!snapshot.hasData ||
                                                    snapshot.data!.isEmpty) {
                                                  return Text(
                                                      'No hay tipos de combustible',
                                                      style: TextStyle(
                                                          fontSize:
                                                              screenWidth *
                                                                  0.028));
                                                }

                                                List<Map<String, dynamic>>
                                                    fuelTypes =
                                                    (snapshot.data ?? [])
                                                        .where((fuel) =>
                                                            fuel['id'] !=
                                                                null &&
                                                            fuel['name'] !=
                                                                null)
                                                        .toList();

                                                return DropdownButtonFormField2<
                                                    String>(
                                                  value: _gasType,
                                                  decoration: InputDecoration(
                                                    labelText:
                                                        'Tipo de Gasolina',
                                                    labelStyle: TextStyle(
                                                        fontSize: screenWidth *
                                                            0.028),
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            vertical: 11,
                                                            horizontal: 12),
                                                    fillColor: Colors.white,
                                                    filled: true,
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6),
                                                      borderSide:
                                                          const BorderSide(
                                                              color: Color
                                                                  .fromARGB(255,
                                                                      0, 0, 0),
                                                              width: 1),
                                                    ),
                                                    isDense: true,
                                                  ),
                                                  items: fuelTypes.map((fuel) {
                                                    return DropdownMenuItem<
                                                        String>(
                                                      value:
                                                          fuel['id'].toString(),
                                                      child: Text(
                                                        fuel['name'],
                                                        style: TextStyle(
                                                            fontSize:
                                                                screenWidth *
                                                                    0.028),
                                                      ),
                                                    );
                                                  }).toList(),
                                                  onChanged: (value) {
                                                    setState(() {
                                                      int selectedFuel =
                                                          int.parse(value!);

                                                      bool isValid = false;

                                                      if (_configurations
                                                              .isEmpty ||
                                                          _gasType == null) {
                                                        isValid = true;
                                                      } else {
                                                        for (var combination
                                                            in _allowedFuelCombinations) {
                                                          if (combination.contains(
                                                                  selectedFuel) &&
                                                              combination.contains(
                                                                  int.parse(
                                                                      _gasType!))) {
                                                            isValid = true;
                                                            break;
                                                          }
                                                        }
                                                      }

                                                      if (!isValid &&
                                                          _gasType != null) {
                                                        _isFuelValid = false;
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .hideCurrentSnackBar();

                                                        showTopSnackBar(
                                                          Overlay.of(context),
                                                          Material(
                                                            color: Colors
                                                                .transparent,
                                                            child: Container(
                                                              margin:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          20),
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(16),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Color(
                                                                    0xFF0886B5),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12),
                                                              ),
                                                              child: Row(
                                                                children: [
                                                                  const Icon(
                                                                      Icons
                                                                          .error,
                                                                      color: Colors
                                                                          .white,
                                                                      size: 24),
                                                                  const SizedBox(
                                                                      width:
                                                                          12),
                                                                  Expanded(
                                                                    child: Text(
                                                                      "Este vehículo no admite este tipo de gasolina",
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            screenWidth *
                                                                                0.034,
                                                                        color: Colors
                                                                            .white,
                                                                        fontWeight:
                                                                            FontWeight.normal,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      } else {
                                                        _isFuelValid = true;
                                                        _gasType = value;
                                                        _gasTypeName = fuelTypes
                                                            .firstWhere((fuel) =>
                                                                fuel['id']
                                                                    .toString() ==
                                                                value)['name'];
                                                        _setFuelPrice(
                                                            selectedFuel);
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .hideCurrentSnackBar();
                                                      }
                                                    });
                                                  },
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize:
                                                        screenWidth * 0.031,
                                                  ),
                                                  buttonStyleData:
                                                      const ButtonStyleData(
                                                    padding: EdgeInsets.only(
                                                        right: 8),
                                                  ),
                                                  iconStyleData:
                                                      const IconStyleData(
                                                    icon: Icon(
                                                      Icons.arrow_drop_down,
                                                      color: Colors.black45,
                                                    ),
                                                  ),
                                                  dropdownStyleData:
                                                      DropdownStyleData(
                                                    maxHeight: 250,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              15),
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  menuItemStyleData:
                                                      const MenuItemStyleData(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 10),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Expanded(
                                            flex: 1,
                                            child: TextFormField(
                                              controller: _litersController,
                                              decoration: InputDecoration(
                                                  labelText: 'Litros',
                                                  labelStyle: TextStyle(
                                                      fontSize:
                                                          screenWidth * 0.028),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                    vertical: 13,
                                                    horizontal: 16,
                                                  ),
                                                  isDense: true,
                                                  counterText: ''),
                                              keyboardType:
                                                  TextInputType.number,
                                              maxLength: 2,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .allow(RegExp(r'[0-9]')),
                                              ],
                                              style: TextStyle(
                                                  fontSize:
                                                      screenWidth * 0.030),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return '';
                                                }
                                                return null;
                                              },
                                              enabled: _isFuelValid,
                                            ),
                                          ),
                                        ],
                                      ),

                                      SizedBox(height: 30),
                                      // Botón de enviar
                                      ElevatedButton(
                                        onPressed:
                                            _isFuelValid ? _submitForm : null,
                                        style: ElevatedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor:
                                              const Color(0xFF0886B5),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 12),
                                          textStyle: TextStyle(
                                              fontSize: screenWidth * 0.030),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                          'Registrar',
                                        ),
                                      ),
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
                ),
        ],
      ),
    );
  }
}
