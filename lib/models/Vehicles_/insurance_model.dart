class InsuranceModel {
  final int id;
  final String idCompania;
  final String polizaNum;
  final String idTipoCobertura;
  final String deducible;
  final String monto;
  final String fechaInicio;
  final String fechaVencimiento;
  final String observaciones;
  final String docUrl;
  final List<dynamic> fotos;

  InsuranceModel({
    required this.id,
    required this.idCompania,
    required this.polizaNum,
    required this.idTipoCobertura,
    required this.deducible,
    required this.monto,
    required this.fechaInicio,
    required this.fechaVencimiento,
    required this.observaciones,
    required this.docUrl,
    this.fotos = const [],
  });

  factory InsuranceModel.fromMap(Map<String, dynamic> map) {
    return InsuranceModel(
      id: map['id'] is int
          ? map['id']
          : int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      idCompania: map['idCompania']?.toString() ?? '',
      polizaNum: map['polizaNum']?.toString() ?? '',
      idTipoCobertura: map['idTipoCobertura']?.toString() ?? '',
      deducible: map['deducible']?.toString() ?? '0',
      monto: map['monto']?.toString() ?? '0',
      fechaInicio: map['fechaInicio']?.toString() ?? '',
      fechaVencimiento: map['fechaVencimiento']?.toString() ?? '',
      observaciones: map['observaciones']?.toString() ?? '',
      docUrl: map['doc_url']?.toString() ?? '',
      fotos: map['fotos'] is List ? (map['fotos'] as List) : const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'idCompania': idCompania,
      'polizaNum': polizaNum,
      'idTipoCobertura': idTipoCobertura,
      'deducible': deducible,
      'monto': monto,
      'fechaInicio': fechaInicio,
      'fechaVencimiento': fechaVencimiento,
      'observaciones': observaciones,
      'doc_url': docUrl,
      'fotos': fotos,
    };
  }
}
