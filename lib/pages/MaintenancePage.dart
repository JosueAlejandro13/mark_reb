import 'package:flutter/material.dart';

class MaintenancePage extends StatelessWidget {
  final Map<String, dynamic> vehicle;

  const MaintenancePage({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(45.0), 
                  child: Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0886B5),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(0, 7), // solo hacia abajo
            blurRadius: 4,
          ),
        ],
      ),
          child: AppBar(
        backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 19,),
              onPressed: () => Navigator.pop(context),
            ),
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
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detalles del Vehículo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildVehicleInfo(),
                  const SizedBox(height: 24),
                  const Text(
                    'Historial de Mantenimiento',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMaintenanceRecord(
                      "Cambio de Aceite", "12/09/2023", "Taller ABC"),
                  _buildMaintenanceRecord(
                      "Revisión de Frenos", "22/08/2023", "Taller XYZ"),
                  _buildMaintenanceRecord(
                      "Cambio de Neumáticos", "15/07/2023", "AutoShop"),
                  // Agrega más registros aquí si es necesario
                ],
              ),
            ),
          ],
        ));
  }

  Widget _buildVehicleInfo() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVehicleDetailRow(Icons.directions_car, 'Marca',
                vehicle['make']?.toString() ?? 'N/A'),
            _buildVehicleDetailRow(Icons.model_training, 'Modelo',
                vehicle['model']?.toString() ?? 'N/A'),
            _buildVehicleDetailRow(Icons.calendar_today, 'Año',
                vehicle['year']?.toString() ?? 'N/A'),
            _buildVehicleDetailRow(Icons.confirmation_number, 'VIN',
                vehicle['vin']?.toString() ?? 'N/A'),
            _buildVehicleDetailRow(Icons.assignment, 'Placas',
                vehicle['placas']?.toString() ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceRecord(String title, String date, String location) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: const Icon(Icons.build, color: Colors.black54),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Fecha: $date\nLugar: $location'),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.black54),
        onTap: () {
          // Acción al seleccionar un registro de mantenimiento
        },
      ),
    );
  }
}
