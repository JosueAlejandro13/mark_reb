import 'package:mark_v3/services/mark_api_client.dart';

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
  final String photo;
  final Map<String, dynamic> raw;

  String get foto => photo;

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
    this.photo = '',
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
    final vinValue =
        (map['vin'] ?? map['serie'] ?? map['engineNumber'] ?? '').toString().trim();
    final platesValue = (map['placas'] ?? map['plates'] ?? '').toString().trim();
    final idValue =
        (map['idVehic'] ?? map['idvehic'] ?? map['id'] ?? '').toString();

    String tankCapacity =
        (map['capacidadTanque'] ?? map['fuelTankCapacity'] ?? '').toString().trim();
    if (tankCapacity == '0' || tankCapacity == '0.0') tankCapacity = '';

    final vehicleType =
        (map['tipoVehiculoNombre'] ?? map['tipoVehiculo'] ?? map['tipo'] ?? '').toString().trim();
    final fuelType =
        (map['tipoCombustibleNombre'] ?? map['tipoCombustible'] ?? map['combustible'] ?? '').toString().trim();

    String cilindradaValue =
        (map['cilindrada'] ?? map['motor'] ?? '').toString().trim();
    if (cilindradaValue == '0' || cilindradaValue == '0.0') cilindradaValue = '';

    String nCilindrosValue =
        (map['nCilindros'] ?? map['cilindros'] ?? map['noCilindros'] ?? '').toString().trim();
    if (nCilindrosValue == '0') nCilindrosValue = '';

    String promConsumoValue = (map['promConsumoTexto'] ??
            map['rendimientoTexto'] ??
            map['promConsumo'] ??
            map['rendimiento'] ??
            '')
        .toString()
        .trim();
    if (promConsumoValue == '0' || promConsumoValue == '0.0') promConsumoValue = '';

    final rawFoto = (map['foto'] ?? map['photo'] ?? '').toString().trim();
    final photoValue = rawFoto.isNotEmpty
        ? (rawFoto.startsWith('http://') || rawFoto.startsWith('https://')
            ? rawFoto
            : MarkApiClient.instance.resolveAssetUrl(rawFoto))
        : '';

    return Vehicle(
      id: idValue,
      placas: platesValue,
      vin: vinValue,
      make: makeValue,
      model: modelValue,
      year: yearValue,
      cilindrada: cilindradaValue,
      nCilindros: nCilindrosValue,
      promConsumo: promConsumoValue,
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
      photo: photoValue,
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
      'photo': photo,
      'foto': photo,
    };
  }

  String get economic =>
      (raw['economico'] ?? raw['eco'] ?? raw['name'] ?? placas).toString();

  String get plates => placas;

  Map<String, dynamic> toJson() => toMap();
}
