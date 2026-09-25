import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

// Autor: Josue Hernandez
class Unexpectederrorpage extends StatelessWidget {
  final VoidCallback onRetry;

  const Unexpectederrorpage({super.key, required this.onRetry});

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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              SizedBox(height: 80),
              Text(
                '¡Ups! Algo salió malo',
                style: TextStyle(
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 0, 0, 0),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Parece que tuvimos un contratiempo. Intenta nuevamente en unos momentos.',
                style: TextStyle(fontSize: screenWidth * 0.035),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Lottie.asset(
                'assets/error.json',
                width: screenWidth * 2,
                height: screenWidth * 0.6,
                repeat: true,
              ),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0886B5),
                  foregroundColor: Colors.white,
                  textStyle: TextStyle(fontSize: screenWidth * 0.031),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
