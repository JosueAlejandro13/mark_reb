import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

// Autor: Josue Hernandez
class ClientErrrorPage extends StatelessWidget {
  final VoidCallback onRetry;

  // ignore: use_super_parameters
  const ClientErrrorPage({Key? key, required this.onRetry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
        double appBarHeight = 30.0;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight),
        child: AppBar(

        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black,
            size: 19,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      ),
      body: Stack(
        children: [
          // Fondo animado
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
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SizedBox(height: 80),
                  Text(
                    'No se encontró información del cliente',
                    style: TextStyle(
                      fontSize: screenWidth * 0.05,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 0, 0, 0),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No fue posible completar la solicitud en este momento. Por favor, inténtalo más tarde.',
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Lottie.asset(
                    'assets/sindatos.json', 
                    width: screenWidth * 2,
                    height: screenWidth * 0.6,
                    repeat: true, // Repite la animación
                  ),
                  ElevatedButton(
                    onPressed: onRetry,
                    // ignore: sort_child_properties_last
                    child: const Text('Reintentar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0886B5),
                      foregroundColor: Colors.white,
                      textStyle: TextStyle(fontSize: screenWidth * 0.031),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
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
