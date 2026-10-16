class TaxModel {
  final int id;
  final String year;
  final String fechaPago;
  final String fechaExpiracion;
  final String montoTenencia;
  final String montoRefrendo;
  final int estado;
  final String vehicleId;
  final String docUrl;

  TaxModel({
    required this.id,
    required this.year,
    required this.fechaPago,
    required this.fechaExpiracion,
    required this.montoTenencia,
    required this.montoRefrendo,
    required this.estado,
    required this.vehicleId,
    required this.docUrl,
  });

  factory TaxModel.fromMap(Map<String, dynamic> map) {
    return TaxModel(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      year: map['year']?.toString() ?? '',
      fechaPago: map['fechaPago']?.toString() ?? '',
      fechaExpiracion: map['fechaExpiracion']?.toString() ?? '',
      montoTenencia: map['montoTenencia']?.toString() ?? '0',
      montoRefrendo: map['montoRefrendo']?.toString() ?? '0',
      estado: map['estado'] is int ? map['estado'] : int.tryParse(map['estado']?.toString() ?? '0') ?? 0,
      vehicleId: map['vehicle_id']?.toString() ?? map['idvehic']?.toString() ?? '',
      docUrl: map['doc_url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'year': year,
      'fechaPago': fechaPago,
      'fechaExpiracion': fechaExpiracion,
      'montoTenencia': montoTenencia,
      'montoRefrendo': montoRefrendo,
      'estado': estado,
      'vehicle_id': vehicleId,
      'doc_url': docUrl,
    };
  }

  double get totalMonto {
    final tenencia = double.tryParse(montoTenencia) ?? 0.0;
    final refrendo = double.tryParse(montoRefrendo) ?? 0.0;
    return tenencia + refrendo;
  }
}
