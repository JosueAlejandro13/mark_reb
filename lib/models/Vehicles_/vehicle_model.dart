// Modelo de Vehículo
class Vehicle {
  final String id;
  final String placas;
  final String vin;
  final String make;
  final String model;
  final String year;
  final String cilindrada;
  final String nCilindros;
  final String promConsumo;
  final String capacidadTanque;
  final String color;
  final String tipoVehiculoNombre;
  final String tipoCombustibleNombre;
  final String Estado;
  final String Status;
  final String ColorEngo;
  final String marca;
  final String modelo;
  final String startDate;
  final String endDate;
  final String idStatus;
  final String odom;
  final String dep;
  final Map<String, dynamic> raw;

  Vehicle({
    required this.id,
    required this.placas,
    required this.vin,
    required this.make,
    required this.model,
    required this.year,
    required this.cilindrada,
    required this.nCilindros,
    required this.promConsumo,
    required this.capacidadTanque,
    required this.color,
    required this.tipoVehiculoNombre,
    required this.tipoCombustibleNombre,
    required this.ColorEngo,
    required this.Estado,
    required this.marca,
    required this.modelo,
    required this.Status,
    required this.startDate,
    required this.endDate,
    required this.idStatus,
    required this.odom,
    this.dep = '',
    this.raw = const {},
  });

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    String odomValue = '';
    if (map['gps'] is Map && (map['gps'] as Map)['odometro'] != null) {
      odomValue = (map['gps'] as Map)['odometro'].toString();
    } else if (map['odometro'] != null) {
      odomValue = map['odometro'].toString();
    } else if (map['odom'] != null) {
      odomValue = map['odom'].toString();
    } else if (map['odometer'] != null) {
      odomValue = map['odometer'].toString();
    }

    final makeValue =
        (map['make'] ?? map['marca'] ?? map['brand'] ?? '').toString();
    final modelValue = (map['model'] ?? map['modelo'] ?? '').toString();
    final yearValue = (map['year'] ?? map['anio'] ?? '').toString();
    final statusValue = (map['Status'] ??
            map['status'] ??
            map['estatus'] ??
            map['Estado'] ??
            'Activo')
        .toString();
    final colorValue = (map['color'] ?? map['ColorEngo'] ?? '').toString();
    final vinValue = (map['vin'] ?? map['engineNumber'] ?? '').toString();
    final platesValue = (map['placas'] ?? map['plates'] ?? '').toString();
    final idValue =
        (map['idVehic'] ?? map['idvehic'] ?? map['id'] ?? '').toString();
    final tankCapacity =
        (map['capacidadTanque'] ?? map['fuelTankCapacity'] ?? '').toString();
    final vehicleType =
        (map['tipoVehiculoNombre'] ?? map['tipo'] ?? '').toString();
    final fuelType =
        (map['tipoCombustibleNombre'] ?? map['combustible'] ?? '').toString();

    return Vehicle(
      id: idValue,
      placas: platesValue,
      vin: vinValue,
      make: makeValue,
      model: modelValue,
      year: yearValue,
      cilindrada: map['cilindrada']?.toString() ?? '',
      nCilindros: map['nCilindros']?.toString() ?? '',
      promConsumo: map['promConsumo']?.toString() ?? '',
      capacidadTanque: tankCapacity,
      color: colorValue,
      tipoVehiculoNombre: vehicleType,
      tipoCombustibleNombre: fuelType,
      Estado: statusValue,
      Status: statusValue,
      ColorEngo: colorValue,
      marca: makeValue,
      modelo: modelValue,
      startDate: map['startDate']?.toString() ?? '',
      endDate: map['endDate']?.toString() ?? '',
      idStatus: (map['idStatus'] ?? map['idEstatus'] ?? '')?.toString() ?? '',
      odom: odomValue,
      dep: map['dep']?.toString() ?? '',
      raw: map,
    );
  }

  Map<String, dynamic> toMap() {
    if (raw.isNotEmpty) return Map<String, dynamic>.from(raw);
    return {
      'idvehic': id,
      'id': id,
      'placas': placas,
      'vin': vin,
      'make': make,
      'model': model,
      'year': year,
      'cilindrada': cilindrada,
      'nCilindros': nCilindros,
      'promConsumo': promConsumo,
      'capacidadTanque': capacidadTanque,
      'color': color,
      'tipoVehiculoNombre': tipoVehiculoNombre,
      'tipoCombustibleNombre': tipoCombustibleNombre,
      'Estado': Estado,
      'Status': Status,
      'ColorEngo': ColorEngo,
      'marca': marca,
      'modelo': modelo,
      'startDate': startDate,
      'endDate': endDate,
      'idStatus': idStatus,
      'odom': odom,
      'dep': dep,
    };
  }

  String get economic =>
      (raw['economico'] ?? raw['eco'] ?? raw['name'] ?? placas).toString();

  String get plates => placas;

  Map<String, dynamic> toJson() => toMap();
}
