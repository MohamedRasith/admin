import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String name;
  final String description;
  final int price;
  final int discount;
  final String imageUrl;
  final String vendorName;
  final int totalCount;
  final Timestamp timestamp;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.discount,
    required this.imageUrl,
    required this.vendorName,
    required this.totalCount,
    required this.timestamp,
  });

  // Factory constructor to create a Product from a Map (e.g., from Firestore)
  factory ProductModel.fromFirestore(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: map['price'] ?? 0,
      discount: map['discount'] ?? 0,
      imageUrl: map['imageUrl'] ?? '',
      vendorName: map['vendorName'] ?? '',
      totalCount: map['totalCount'] ?? 0,
      timestamp: map['timestamp'] ?? Timestamp.now(),
    );
  }

  // Method to convert the Product to a Map (e.g., for Firestore)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'discount': discount,
      'imageUrl': imageUrl,
      'vendorName': vendorName,
      'totalCount': totalCount,
      'timestamp': timestamp,
    };
  }

  // Method to get formatted date from timestamp
  String getFormattedDate() {
    return Timestamp.fromDate(timestamp.toDate()).toDate().toString();
  }
}
