class CreditPaymentModel {
  final int id;
  final String nPayment;
  final String monto;
  final String fecPayment;
  final String fecExpi;

  CreditPaymentModel({
    required this.id,
    required this.nPayment,
    required this.monto,
    required this.fecPayment,
    required this.fecExpi,
  });

  factory CreditPaymentModel.fromMap(Map<String, dynamic> map) {
    return CreditPaymentModel(
      id: map['id'] is int
          ? map['id']
          : int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      nPayment: map['nPayment']?.toString() ?? '',
      monto: map['monto']?.toString() ?? '0',
      fecPayment: map['fecPayment']?.toString() ?? '',
      fecExpi: map['fecExpi']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nPayment': nPayment,
      'monto': monto,
      'fecPayment': fecPayment,
      'fecExpi': fecExpi,
    };
  }
}
