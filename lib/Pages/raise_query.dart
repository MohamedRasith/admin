import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CreateTicketWithVendor extends StatefulWidget {
  @override
  _CreateTicketWithVendorState createState() => _CreateTicketWithVendorState();
}

class _CreateTicketWithVendorState extends State<CreateTicketWithVendor> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String? selectedVendorId;
  String? selectedVendorName;

  List<Map<String, String>> vendorsList = [];

  @override
  void initState() {
    super.initState();
    fetchVendors();
  }

  Future<void> fetchVendors() async {
    final snapshot = await FirebaseFirestore.instance.collection('vendors').get();
    final List<Map<String, String>> temp = snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'name': doc['vendorName'].toString(),
      };
    }).toList();


    setState(() {
      vendorsList = temp;
    });
  }

  Future<void> submitTicket() async {
    if (selectedVendorId == null || _titleController.text.isEmpty || _descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('tickets').add({
      'title': _titleController.text,
      'description': _descController.text,
      'vendorId': selectedVendorId,
      'vendorName': selectedVendorName,
      'createdAt': Timestamp.now(),
      'status': 'open',
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ticket submitted')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: IconThemeData(color: Colors.white),
          title: Text('Send Query to Vendor', style: TextStyle(color: Colors.white),)),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Dropdown to select vendor
            DropdownButtonFormField<String>(
              hint: Text("Select Vendor"),
              value: selectedVendorId,
              items: vendorsList.map((vendor) {
                return DropdownMenuItem<String>(
                  value: vendor['id'],
                  child: Text(vendor['name'] ?? ''),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedVendorId = value;
                  selectedVendorName = vendorsList.firstWhere((v) => v['id'] == value)['name'];
                });
              },
            ),
            SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Ticket Title'),
            ),
            TextField(
              controller: _descController,
              decoration: InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: submitTicket,
              child: Text('Submit Ticket'),
            ),
          ],
        ),
      ),
    );
  }
}
