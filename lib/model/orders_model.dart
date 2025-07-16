import 'package:cloud_firestore/cloud_firestore.dart';

class ProductDetail {
  final String asin;
  final String barcode;
  final String boxCount;
  final String confirmed;
  final String firebaseId;
  final String orderId;
  final String requested;
  final String title;
  final String total;
  final String unitCost;

  ProductDetail({
    required this.asin,
    required this.barcode,
    required this.boxCount,
    required this.confirmed,
    required this.firebaseId,
    required this.orderId,
    required this.requested,
    required this.title,
    required this.total,
    required this.unitCost,
  });

  factory ProductDetail.fromMap(Map<String, dynamic> map) {
    return ProductDetail(
      asin: map['asin'] ?? '',
      barcode: map['barcode'] ?? '',
      boxCount: map['boxCount'] ?? '',
      confirmed: map['confirmed'] ?? '',
      firebaseId: map['firebaseId'] ?? '',
      orderId: map['orderId'] ?? '',
      requested: map['requested'] ?? '',
      title: map['title'] ?? '',
      total: map['total'] ?? '',
      unitCost: map['unitCost'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'asin': asin,
      'barcode': barcode,
      'boxCount': boxCount,
      'confirmed': confirmed,
      'firebaseId': firebaseId,
      'orderId': orderId,
      'requested': requested,
      'title': title,
      'total': total,
      'unitCost': unitCost,
    };
  }
}

class OrderModel {
  final String amazonPONumber;
  final String appointmentId;
  final DateTime appointmentDate;
  final String asn;
  final String bnbPONumber;
  final String boxCount;
  final Timestamp createdAt;
  final String location;
  final String productName;
  final int productQuantity;
  final List<ProductDetail> products;
  final String vendor;


  OrderModel({
    required this.amazonPONumber,
    required this.appointmentId,
    required this.appointmentDate,
    required this.asn,
    required this.bnbPONumber,
    required this.boxCount,
    required this.createdAt,
    required this.location,
    required this.productName,
    required this.productQuantity,
    required this.products,
    required this.vendor,
  });

  factory OrderModel.fromFirestore(Map<String, dynamic> firestore) {
    var productList = <ProductDetail>[];
    if (firestore['products'] != null) {
      productList = (firestore['products'] as List)
          .map((e) => ProductDetail.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }

    return OrderModel(
      amazonPONumber: firestore['amazonPONumber'] ?? '',
      appointmentId: firestore['appointmentId'] ?? '',
      appointmentDate: (firestore['appointmentDate'] as Timestamp).toDate(),
      asn: firestore['asn'] ?? '',
      bnbPONumber: firestore['bnbPONumber'] ?? '',
      boxCount: firestore['boxCount'] ?? '',
      createdAt: firestore['createdAt'],
      location: firestore['location'] ?? '',
      productName: firestore['productName'] ?? '',
      productQuantity: firestore['productQuantity'] ?? 0,
      products: productList,
      vendor: firestore['vendor'] ?? "",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amazonPONumber': amazonPONumber,
      'appointmentId': appointmentId,
      'appointmentDate': Timestamp.fromDate(appointmentDate),
      'asn': asn,
      'bnbPONumber': bnbPONumber,
      'boxCount': boxCount,
      'createdAt': createdAt,
      'location': location,
      'productName': productName,
      'productQuantity': productQuantity,
      'products': products.map((e) => e.toMap()).toList(),
      'vendor': vendor,
    };
  }
}
