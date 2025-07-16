class VendorModel {
  final String address;
  final String email;
  final String emiratesIdBackUrl;
  final String emiratesIdFrontUrl;
  final String fullName;
  final String mobile;
  final String profileImageUrl;

  VendorModel({
    required this.address,
    required this.email,
    required this.emiratesIdBackUrl,
    required this.emiratesIdFrontUrl,
    required this.fullName,
    required this.mobile,
    required this.profileImageUrl,
  });

  factory VendorModel.fromFirestore(Map<String, dynamic> map) {
    return VendorModel(
      address: map['address'] ?? '',
      email: map['email'] ?? '',
      emiratesIdBackUrl: map['emiratesIdBack'] ?? '',
      emiratesIdFrontUrl: map['emiratesIdFront'] ?? 0,
      fullName: map['fullName'] ?? 0,
      mobile: map['mobile'] ?? '',
      profileImageUrl: map['profileImage'] ?? '',
    );
  }

  // Method to convert the Product to a Map (e.g., for Firestore)
  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'email': email,
      'emiratesIdBack': emiratesIdBackUrl,
      'emiratesIdFront': emiratesIdFrontUrl,
      'fullName': fullName,
      'mobile': mobile,
      'profileImage': profileImageUrl,
    };
  }
}