import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html;

class OrderDetailsPage extends StatefulWidget {
  final QueryDocumentSnapshot order;
  const OrderDetailsPage({super.key, required this.order});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  late List<Map<String, dynamic>> products;
  var total;
  late TextEditingController appointmentIdController;
  late TextEditingController asnController;
  late TextEditingController bnbPONumberController;
  late TextEditingController locationController;
  late TextEditingController vendorController;
  late TextEditingController boxesController;

  DateTime? appointmentDate;
  int totalBoxCount = 0;

  @override
  void initState() {
    super.initState();
    final data = widget.order.data() as Map<String, dynamic>;

    appointmentIdController = TextEditingController(text: data['appointmentId'] ?? '');
    asnController = TextEditingController(text: data['asn'] ?? '');
    bnbPONumberController = TextEditingController(text: data['bnbPONumber'] ?? '');
    locationController = TextEditingController(text: data['location'] ?? '');
    vendorController = TextEditingController(text: data['vendor'] ?? '');
    appointmentDate = data['appointmentDate']?.toDate();
    boxesController = TextEditingController(text: data['boxCount']?.toString() ?? '');

    products = (data['products'] as List<dynamic>).map((e) => Map<String, dynamic>.from(e)).toList();


    for (var product in products) {
      if (product['confirmed'] == null || product['confirmed'].toString().isEmpty) {
        product['confirmed'] = 0;
      }
    }
  }

  String insertLineBreaks(String text, int interval) {
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % interval == 0 && i != text.length - 1) {
        buffer.write('\n');
      }
    }
    return buffer.toString();
  }


  Future<void> uploadProofOfDelivery() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final fileBytes = file.bytes;
    final fileName = file.name;

    if (fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load file.")),
      );
      return;
    }

    try {
      // Upload to Firebase Storage
      final ref = FirebaseStorage.instance.ref().child('proof_of_delivery/$fileName');
      final uploadTask = await ref.putData(fileBytes);
      final fileUrl = await ref.getDownloadURL();

      // Update Firestore order document with file URL
      await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({
        'proofOfDeliveryUrl': fileUrl,
        'status' : 'Delivered'
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Proof of Delivery uploaded successfully.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.order.data() as Map<String, dynamic>;
    appointmentDate = (data['appointmentDate'] as Timestamp).toDate();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
          backgroundColor: Colors.black,
          title: Text("Order: ${data['amazonPONumber']}", style: TextStyle(color: Colors.white),)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Table(
              border: TableBorder.all(color: Colors.grey), // <-- Add this line
              columnWidths: const {
                0: IntrinsicColumnWidth(),
                1: IntrinsicColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("ASN:", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(controller: asnController, decoration: InputDecoration(border: InputBorder.none),),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("BNB PO NUmber:", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(widget.order['bnbPONumber'] ?? ''),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("Appointment ID:", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(controller: appointmentIdController, decoration: InputDecoration(border: InputBorder.none),),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("Appointment Date & Time:", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: InkWell(
                        onTap: () async {
                          // Pick Date
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: appointmentDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );

                          if (pickedDate != null) {
                            // Pick Time
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(appointmentDate ?? DateTime.now()),
                            );

                            if (pickedTime != null) {
                              final combinedDateTime = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );

                              setState(() {
                                appointmentDate = combinedDateTime;
                              });
                            }
                          }
                        },
                        child: Text(
                          appointmentDate != null
                              ? DateFormat("dd MMM yyyy hh:mm a").format(appointmentDate!)
                              : "Pick date & time",
                          style: const TextStyle(decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("Location:", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(widget.order['location'] ?? ''),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("Order created on:", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(DateFormat("dd MMM hh:mm a").format(data['createdAt'].toDate())),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("Vendor:", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(widget.order['vendor'] ?? ''),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("No. of Boxes:", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(controller: boxesController, decoration: InputDecoration(border: InputBorder.none),),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),
            widget.order['proofOfDeliveryUrl'] != ""?
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: InkWell(
                onTap: () async {
                  final url = widget.order['proofOfDeliveryUrl'];
                  html.window.open(url, '_blank');
                },
                child: const Text(
                  "View Proof of Delivery",
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ):
            Center(
              child: SizedBox(
                width: 300,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                  icon: const Icon(Icons.attach_file),
                  label: const Text("Upload Proof of Delivery"),
                  onPressed: uploadProofOfDelivery,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Products", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              child: LayoutBuilder(
                  builder: (context, constraints) {
                  return IntrinsicWidth(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        columnSpacing: 20,
                        dataRowMinHeight: 50,
                        dataRowMaxHeight: 100,
                        columns: const [
                          DataColumn(label: Text('')),
                          DataColumn(label: Text('Product')),
                          DataColumn(label: Text('Requested')),
                          DataColumn(label: Text('Confirmed')),
                          DataColumn(label: Text('Total')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: products.asMap().entries.map((entry) {
                          final index = entry.key;
                          final product = entry.value;
                          final boxCount = product['boxCount'] ?? 0;
                          final unitCost = product['unitCost'] ?? 0.0;
                          int confirmed = product['confirmed'] ?? 0;

                          final controller = TextEditingController(text: confirmed.toString());

                          return DataRow(cells: [
                            DataCell(
                              CircleAvatar(
                                  radius: 25,
                                  child: Image.network(product['imageUrl'] ?? '', width: 50, height: 50, fit: BoxFit.cover)),
                            ),
                            DataCell(
                              Text(
                                insertLineBreaks(product['title'] ?? '', 40),
                                softWrap: true,
                              ),
                            ),
                            DataCell(Text(boxCount.toString())),

                            // Confirmed with increment/decrement
                            DataCell(
                              SizedBox(
                                width: 140,
                                child: Card(
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        onPressed: confirmed > 0
                                            ? () {
                                          setState(() {
                                            confirmed--;
                                            controller.text = confirmed.toString();
                                            products[index]['confirmed'] = confirmed;
                                            products[index]['total'] = confirmed * unitCost;
                                          });
                                        }
                                            : null,
                                      ),
                                      SizedBox(
                                        width: 50,
                                        child: TextField(
                                          controller: controller,
                                          textAlign: TextAlign.center,
                                          keyboardType: TextInputType.number,
                                          onChanged: (value) {
                                            int current = int.tryParse(value) ?? 0;
                                            if (current > boxCount) {
                                              current = boxCount;
                                              controller.text = current.toString();
                                            } else if (current < 0) {
                                              current = 0;
                                              controller.text = "0";
                                            }
                                            setState(() {
                                              products[index]['confirmed'] = current;
                                              products[index]['total'] = current * unitCost;
                                            });
                                          },
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        onPressed: confirmed < boxCount
                                            ? () {
                                          setState(() {
                                            confirmed++;
                                            controller.text = confirmed.toString();
                                            products[index]['confirmed'] = confirmed;
                                            products[index]['total'] = confirmed * unitCost;
                                          });
                                        }
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            DataCell(Text((product['total'] ?? 0.0).toStringAsFixed(2))),

                            DataCell(
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection('orders')
                                      .doc(widget.order.id)
                                      .update({'products': products});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Confirmed count updated")),
                                  );
                                },
                                child: const Text('Save'),
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  );
                }
              ),
            ),
            const SizedBox(
              height: 30,
            ),
            Center(
              child: SizedBox(
                width: 300,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({
                      'appointmentId': appointmentIdController.text.trim(),
                      'asn': asnController.text.trim(),
                      'appointmentDate': appointmentDate != null ? Timestamp.fromDate(appointmentDate!) : null,
                      'boxCount': int.tryParse(boxesController.text.trim()) ?? 0,
                      'status': 'Units Confirmed',
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Order details updated")),
                    );
                  },
                  child: const Text("Save Order Info"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
