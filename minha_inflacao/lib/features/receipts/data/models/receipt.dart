enum Confidence { high, medium, low }

class ReceiptItem {
  final String? ean;
  final String rawName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;
  final Confidence confidence;

  const ReceiptItem({
    required this.ean,
    required this.rawName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
    required this.confidence,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
        ean: json['ean'] as String?,
        rawName: json['rawName'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unit: json['unit'] as String,
        unitPrice: (json['unitPrice'] as num).toDouble(),
        totalPrice: (json['totalPrice'] as num).toDouble(),
        confidence: Confidence.values.byName(json['confidence'] as String),
      );

  Map<String, dynamic> toJson() => {
        'ean': ean,
        'rawName': rawName,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'totalPrice': totalPrice,
        'confidence': confidence.name,
      };

  ReceiptItem copyWith({
    String? ean,
    String? rawName,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? totalPrice,
    Confidence? confidence,
  }) =>
      ReceiptItem(
        ean: ean ?? this.ean,
        rawName: rawName ?? this.rawName,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        unitPrice: unitPrice ?? this.unitPrice,
        totalPrice: totalPrice ?? this.totalPrice,
        confidence: confidence ?? this.confidence,
      );
}

class ParsedReceipt {
  final String storeName;
  final String storeAddress;
  final String cep;
  final String receiptDate;
  final double total;
  final List<ReceiptItem> items;

  const ParsedReceipt({
    required this.storeName,
    required this.storeAddress,
    required this.cep,
    required this.receiptDate,
    required this.total,
    required this.items,
  });

  factory ParsedReceipt.fromJson(Map<String, dynamic> json) => ParsedReceipt(
        storeName: json['storeName'] as String,
        storeAddress: json['storeAddress'] as String,
        cep: json['cep'] as String,
        receiptDate: json['receiptDate'] as String,
        total: (json['total'] as num).toDouble(),
        items: (json['items'] as List)
            .map((e) => ReceiptItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'storeName': storeName,
        'storeAddress': storeAddress,
        'cep': cep,
        'receiptDate': receiptDate,
        'total': total,
        'items': items.map((e) => e.toJson()).toList(),
      };

  ParsedReceipt copyWith({
    String? storeName,
    String? storeAddress,
    String? cep,
    String? receiptDate,
    double? total,
    List<ReceiptItem>? items,
  }) =>
      ParsedReceipt(
        storeName: storeName ?? this.storeName,
        storeAddress: storeAddress ?? this.storeAddress,
        cep: cep ?? this.cep,
        receiptDate: receiptDate ?? this.receiptDate,
        total: total ?? this.total,
        items: items ?? this.items,
      );
}

class Receipt {
  final String id;
  final String storeName;
  final String storeAddress;
  final String cep5;
  final DateTime date;
  final double total;
  final String status; // "pending_review" | "confirmed" | "error"
  final String imageUrl;

  const Receipt({
    required this.id,
    required this.storeName,
    required this.storeAddress,
    required this.cep5,
    required this.date,
    required this.total,
    required this.status,
    required this.imageUrl,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) => Receipt(
        id: json['id'] as String,
        storeName: json['storeName'] as String,
        storeAddress: json['storeAddress'] as String,
        cep5: json['cep5'] as String,
        date: DateTime.parse(json['date'] as String),
        total: (json['total'] as num).toDouble(),
        status: json['status'] as String,
        imageUrl: json['imageUrl'] as String,
      );
}
