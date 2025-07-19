import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UpdateVendorPage extends StatelessWidget {
  final DocumentSnapshot vendor;
  const UpdateVendorPage({super.key, required this.vendor});
  @override
  Widget build(BuildContext context) {
    // Build update form here
    return Scaffold(
      appBar: AppBar(title: const Text("Update Vendor")),
      body: Center(child: Text("TODO: Implement update form")),
    );
  }
}
