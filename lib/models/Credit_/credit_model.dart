class CreditModel {
  final int id;
  final String name;
  final String idEntidadFinanciera;
  final String monto;
  final String enganche;
  final String interes;
  final String plazo;
  final String comision;
  final String comisionApertura;
  final String fechaInicio;
  final String dateFirstPayment;
  final String docUrl;

  CreditModel({
    required this.id,
    required this.name,
    required this.idEntidadFinanciera,
    required this.monto,
    required this.enganche,
    required this.interes,
    required this.plazo,
    required this.comision,
    required this.comisionApertura,
    required this.fechaInicio,
    required this.dateFirstPayment,
    required this.docUrl,
  });

  factory CreditModel.fromMap(Map<String, dynamic> map) {
    return CreditModel(
      id: map['id'] is int
          ? map['id']
          : int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      name: map['name']?.toString() ?? '',
      idEntidadFinanciera: map['idEntidadFinanciera']?.toString() ?? '',
      monto: map['monto']?.toString() ?? '0',
      enganche: map['enganche']?.toString() ?? '0',
      interes: map['interes']?.toString() ?? '0',
      plazo: map['plazo']?.toString() ?? '0',
      comision: map['comision']?.toString() ?? '0',
      comisionApertura: map['comisionApertura']?.toString() ?? '0',
      fechaInicio: map['fechaInicio']?.toString() ?? '',
      dateFirstPayment: map['dateFirstPayment']?.toString() ?? '',
      docUrl: map['doc_url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'idEntidadFinanciera': idEntidadFinanciera,
      'monto': monto,
      'enganche': enganche,
      'interes': interes,
      'plazo': plazo,
      'comision': comision,
      'comisionApertura': comisionApertura,
      'fechaInicio': fechaInicio,
      'dateFirstPayment': dateFirstPayment,
      'doc_url': docUrl,
    };
  }
}
