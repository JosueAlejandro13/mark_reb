class CirculationCardModel {
  final int id;
  final String numTarjeta;
  final String fecExpedicion;
  final String fecVencimiento;
  final String monto;
  final List<dynamic> fotos;

  CirculationCardModel({
    required this.id,
    required this.numTarjeta,
    required this.fecExpedicion,
    required this.fecVencimiento,
    required this.monto,
    this.fotos = const [],
  });

  factory CirculationCardModel.fromMap(Map<String, dynamic> map) {
    return CirculationCardModel(
      id: map['id'] is int
          ? map['id']
          : int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      numTarjeta: map['numTarjeta']?.toString() ?? '',
      fecExpedicion: map['fecExpedicion']?.toString() ?? '',
      fecVencimiento: map['fecVencimiento']?.toString() ?? '',
      monto: map['monto']?.toString() ?? '0',
      fotos: map['fotos'] is List ? (map['fotos'] as List) : const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numTarjeta': numTarjeta,
      'fecExpedicion': fecExpedicion,
      'fecVencimiento': fecVencimiento,
      'monto': monto,
      'fotos': fotos,
    };
  }
}
