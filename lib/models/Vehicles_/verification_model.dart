class VerificationModel {
  final int id;
  final String idHolograma;
  final String fecVerificacion;
  final String proximaVerific;
  final String monto;
  final int estado;
  final String docUrl;

  VerificationModel({
    required this.id,
    required this.idHolograma,
    required this.fecVerificacion,
    required this.proximaVerific,
    required this.monto,
    required this.estado,
    required this.docUrl,
  });

  factory VerificationModel.fromMap(Map<String, dynamic> map) {
    return VerificationModel(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      idHolograma: map['idHolograma']?.toString() ?? '',
      fecVerificacion: map['fecVerificacion']?.toString() ?? '',
      proximaVerific: map['proximaVerific']?.toString() ?? '',
      monto: map['monto']?.toString() ?? '0',
      estado: map['estado'] is int ? map['estado'] : int.tryParse(map['estado']?.toString() ?? '0') ?? 0,
      docUrl: map['doc_url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'idHolograma': idHolograma,
      'fecVerificacion': fecVerificacion,
      'proximaVerific': proximaVerific,
      'monto': monto,
      'estado': estado,
      'doc_url': docUrl,
    };
  }
}
