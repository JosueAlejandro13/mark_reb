import 'package:flutter/material.dart';

//Autor: Josue Hernandez
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(45.0),
        child: AppBar(
          backgroundColor: const Color(0xFF0886B5),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: const Center(
        child: Text(
          'Página de reportes',
          style: TextStyle(fontSize: 24, color: Colors.black),
        ),
      ),
    );
  }
}
