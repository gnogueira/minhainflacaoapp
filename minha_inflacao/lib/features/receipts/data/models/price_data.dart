class PriceData {
  final String ean;
  final String cep5;
  final double avgPrice;
  final double minPrice;
  final double maxPrice;
  final int count;

  const PriceData({
    required this.ean,
    required this.cep5,
    required this.avgPrice,
    required this.minPrice,
    required this.maxPrice,
    required this.count,
  });

  factory PriceData.fromJson(Map<String, dynamic> json) => PriceData(
        ean: json['ean'] as String,
        cep5: json['cep5'] as String,
        avgPrice: (json['avgPrice'] as num).toDouble(),
        minPrice: (json['minPrice'] as num).toDouble(),
        maxPrice: (json['maxPrice'] as num).toDouble(),
        count: json['count'] as int,
      );
}
