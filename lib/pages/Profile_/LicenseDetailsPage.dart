// ignore_for_file: unnecessary_null_comparison
import 'dart:async';
import 'dart:io';
import 'package:bottom_picker/bottom_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/services/ConnectionProfile_/ProfileCon_service.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

//Autor: Josue Hernandez
class LicenseDetailsPage extends StatefulWidget {
  final String idCollaborator;

  const LicenseDetailsPage({super.key, required this.idCollaborator});

  @override
  _LicenseDetailsPageState createState() => _LicenseDetailsPageState();
}

class _LicenseDetailsPageState extends State<LicenseDetailsPage> {
  late Future<Map<String, dynamic>?> licenseDataFuture;
  final _formKey = GlobalKey<FormState>();
  String? licNum;
  String? licClass;
  DateTime? dueDate;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    licenseDataFuture = fetchLicenseDataById(widget.idCollaborator);
  }

  Future<void> _refreshData() async {
    if (mounted) {
      setState(() {
        licenseDataFuture = ProfileconService()
            .obtenerLicenciaPorColaborador(widget.idCollaborator);
      });
    }
  }

  Future<Map<String, dynamic>?> fetchLicenseDataById(
      String idCollaborator) async {
    try {
      final licenseData = await ProfileconService()
          .obtenerLicenciaPorColaborador(idCollaborator);

      if (licenseData == null || licenseData.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No tienes licencia.')),
          );
        }
        return null;
      } else {
        return licenseData;
      }
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
      if (mounted) {}
    }
  }

  Future<void> _addNewLicense() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      if (mounted) {
        setState(() {
          isLoading = true;
        });
      }
      try {
        await ProfileconService().agregarNuevaLicencia({
          'idCollaborator': widget.idCollaborator,
          'licNum': licNum,
          'licClass': licClass,
          'dueDate': dueDate!.toIso8601String(),
        });

        if (mounted) {
          setState(() {
            licenseDataFuture = fetchLicenseDataById(widget.idCollaborator);
            licNum = null;
            licClass = null;
            dueDate = null;
            isLoading = false;
          });
        }
        if (mounted) {
          final screenWidth = MediaQuery.of(context).size.width;
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
                        "Licencia añadida exitosamente.",
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
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        if (mounted) {
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
                        "Error al agregar la licencia. Intente nuevamente más tarde.",
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
              height: screenHeight,
              width: screenWidth,
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
            Container(
              constraints: BoxConstraints(
                minHeight: screenHeight,
              ),
              child: FutureBuilder<Map<String, dynamic>?>(
                future: licenseDataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                        child: Lottie.asset(
                      'assets/loading.json',
                      width: screenWidth * 0.2,
                      height: screenWidth * 0.2,
                      repeat: true,
                    ));
                  } else if (snapshot.hasError) {
                    return const Center(child: Text('Error al cargar datos'));
                  } else if (snapshot.hasData) {
                    final licenseData = snapshot.data;
                    if (licenseData != null) {
                      return _buildLicenseDetailsContent(licenseData);
                    } else {
                      return _buildAddLicenseSection();
                    }
                  } else {
                    return _buildAddLicenseSection();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseDetailsContent(Map<String, dynamic> licenseData) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Licencia de Conducir',
              style: TextStyle(
                fontSize: screenWidth * 0.050,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 16),
          _buildLicenseCard(licenseData),
          const SizedBox(height: 16),
          _buildExpirationCard(licenseData),
        ],
      ),
    );
  }

  Widget _buildLicenseCard(Map<String, dynamic> licenseData) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    bool isPermanent = false;

    dynamic dueDate = licenseData['dueDate'];
    DateTime? parsedDueDate;

    if (dueDate is String) {
      try {
        parsedDueDate = DateTime.parse(dueDate);
      } catch (e) {
        isPermanent = true;
      }
    } else if (dueDate is DateTime) {
      parsedDueDate = dueDate;
    }

    if (parsedDueDate == null ||
        parsedDueDate.year <= 0 ||
        parsedDueDate.isBefore(DateTime(1900))) {
      isPermanent = true;
    }

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.credit_card,
                    size: screenWidth * 0.09,
                    color: const Color.fromARGB(255, 0, 0, 0)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Licencia de Conducir',
                        style: TextStyle(
                            fontSize: screenWidth * 0.036,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'N° Licencia: ${licenseData['licNum'] ?? 'N/A'}',
                        style: TextStyle(
                            fontSize: screenWidth * 0.032,
                            color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 1),
            _buildInfoRow(
              Icons.tab,
              'Tipo',
              licenseData['licClass'] ?? 'N/A',
            ),
            if (!isPermanent)
              _buildInfoRow(Icons.calendar_today, 'Fecha de Vencimiento',
                  _formatDueDate(dueDate)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon,
              size: screenWidth * 0.057,
              color: const Color.fromARGB(255, 0, 0, 0)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: screenWidth * 0.031, color: Colors.black54)),
                Text(value,
                    style: TextStyle(
                        fontSize: screenWidth * 0.032,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDueDate(dynamic dueDate) {
    if (dueDate is String) {
      try {
        DateTime parsedDate = DateTime.parse(dueDate);
        return DateFormat('dd/MM/yyyy').format(parsedDate);
      } catch (e) {
        return 'Fecha inválida';
      }
    } else if (dueDate is DateTime) {
      return DateFormat('dd/MM/yyyy').format(dueDate);
    }
    return 'Fecha inválida';
  }

  Widget _buildExpirationCard(Map<String, dynamic> licenseData) {
    IconData icon;
    Color color;
    String statusText;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    dynamic dueDate = licenseData['dueDate'];
    DateTime? parsedDueDate;

    if (dueDate is String) {
      try {
        parsedDueDate = DateTime.parse(dueDate);
      } catch (e) {
        return const Text('Error al procesar la fecha de vencimiento.');
      }
    } else if (dueDate is DateTime) {
      parsedDueDate = dueDate;
    } else {
      return const Text('Fecha de vencimiento no válida.');
    }

    if (parsedDueDate.year <= 0 || parsedDueDate.isBefore(DateTime(1900))) {
      icon = Icons.check_circle_outline;
      color = Colors.blue;
      statusText = 'Licencia permanente';
      return Card(
        elevation: 6,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: screenWidth * 0.059),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                        fontSize: screenWidth * 0.034,
                        color: color,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'No requiere renovación',
                style: TextStyle(
                    fontSize: screenWidth * 0.032, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    DateTime now = DateTime.now();

    bool isExpired = parsedDueDate.isBefore(now);
    bool isCloseToExpiration = parsedDueDate.isAfter(now) &&
        parsedDueDate.isBefore(now.add(const Duration(days: 30)));

    if (isExpired) {
      icon = Icons.error_outline;
      color = Colors.red;
      statusText = 'Licencia expirada';
    } else if (isCloseToExpiration) {
      icon = Icons.warning;
      color = Colors.orange;
      statusText = 'Licencia por vencerse';
    } else {
      icon = Icons.check_circle_outline;
      color = Colors.green;
      statusText = 'Licencia vigente';
    }

    int daysRemaining = _calculateDaysRemaining(parsedDueDate);
    String daysText = isExpired
        ? 'Días desde el vencimiento: ${-daysRemaining}'
        : 'Días restantes: $daysRemaining';

    return Card(
      elevation: 5,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                      fontSize: screenWidth * 0.034,
                      color: color,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(daysText,
                style: TextStyle(
                    fontSize: screenWidth * 0.032, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  bool isPermanent = false;

  Widget _buildAddLicenseSection() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No se encontró licencia',
            style: TextStyle(
              fontSize: screenWidth * 0.050,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Card(
              elevation: 6,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Agrega una nueva licencia de conducir',
                        style: TextStyle(
                          fontSize: screenWidth * 0.036,
                          color: const Color.fromARGB(255, 0, 0, 0),
                        )),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildIconTextFormField(
                              label: 'N° Licencia',
                              icon: Icons.credit_card,
                              onSaved: (value) => licNum = value,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Ingresa el No. Licencia';
                                }
                                return null;
                              },
                              maxLength: 10),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildIconTextFormField(
                              label: 'Tipo',
                              icon: Icons.class_,
                              onSaved: (value) => licClass = value,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Ingresa la categoría';
                                }
                                return null;
                              },
                              maxLength: 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Si tu licencia es permanente, pulsa el botón de permanente.',
                      style: TextStyle(
                          fontSize: screenWidth * 0.029, color: const Color.fromARGB(255, 0, 0, 0)),
                    ),
                    const SizedBox(height: 10),
                    if (!isPermanent)
                      Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: screenWidth * 0.6,
                          child: _buildDateField(),
                        ),
                      ),
                    const SizedBox(height: 25),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF0886B5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          textStyle: TextStyle(fontSize: screenWidth * 0.030),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            // Toggle entre true/false
                            isPermanent = !isPermanent;

                            if (isPermanent) {
                              dueDate = DateTime(1000, 1, 1);
                            } else {
                              dueDate = null;
                            }
                          });
                        },
                        child: Text(
                          isPermanent ? 'No Permanente' : 'Permanente',
                          style: TextStyle(fontSize: screenWidth * 0.030),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    isLoading
                        ? Center(
                            child: Lottie.asset(
                              'assets/loading.json',
                              width: screenWidth * 0.2,
                              height: screenWidth * 0.2,
                              repeat: true,
                            ),
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: const Color(0xFF0886B5),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              minimumSize: const Size(200, 12),
                            ),
                            onPressed: _addNewLicense,
                            child: Text('Agregar Licencia',
                                style:
                                    TextStyle(fontSize: screenWidth * 0.030)),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconTextFormField({
    required String label,
    required IconData icon,
    required FormFieldSetter<String> onSaved,
    required FormFieldValidator<String> validator,
    required int maxLength,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return TextFormField(
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: screenWidth * 0.030),
        prefixIcon: Icon(
          icon,
          size: screenWidth * 0.05,
        ),
        isDense: true,
        counterText: "",
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(
              color: Color.fromARGB(255, 180, 180, 180), width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Color(0xFF0886B5), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Colors.red, width: 2.0),
        ),
        
              errorStyle:
                                      TextStyle(fontSize: screenWidth * 0.028),
      ),
      style: TextStyle(fontSize: screenWidth * 0.031),
      onSaved: onSaved,
      validator: validator,
    );
  }

  Widget _buildDateField() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Fecha de Vencimiento',
        labelStyle: TextStyle(fontSize: screenWidth * 0.031),
        prefixIcon: Icon(
          Icons.calendar_today,
          size: screenWidth * 0.05,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide:
              const BorderSide(color: Color.fromARGB(255, 0, 0, 0), width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Color(0xFF0886B5), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Colors.red, width: 2.0),
          
        ),
              errorStyle:
                                      TextStyle(fontSize: screenWidth * 0.028),
      ),
      style: TextStyle(fontSize: screenWidth * 0.031),
      readOnly: true,
      onTap: () async {
        BottomPicker.date(
          pickerTitle: Text(
            "Seleccionar fecha",
            style: TextStyle(fontSize: screenWidth * 0.037),
          ),
          dismissable: true,
          pickerDescription: SizedBox(height: screenHeight * 0.03),
          initialDateTime: dueDate ?? DateTime.now(),
          minDateTime: DateTime(1999),
          maxDateTime: DateTime(2101),
          pickerTextStyle:
              TextStyle(fontSize: screenWidth * 0.050, color: Colors.black),
          onSubmit: (selectedDate) {
            setState(() {
              dueDate = selectedDate;
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
      },
      controller: TextEditingController(
        text: dueDate != null ? DateFormat('dd/MM/yyyy').format(dueDate!) : '',
      ),
      validator: (value) {
        if (dueDate == null) {
          return 'Seleccione la fecha' ;
        }
        return null;
      },
    );
  }

  int _calculateDaysRemaining(DateTime dueDate) {
    DateTime now = DateTime.now();
    return dueDate.difference(now).inDays;
  }
}
