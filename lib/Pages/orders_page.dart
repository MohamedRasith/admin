
import 'package:admin/Pages/edit_orders.dart';
import 'package:admin/widget/copyable_text_cell.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({Key? key}) : super(key: key);

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final categories = [
    'Pending Order',
    'Units Confirmed',
    'Appointment Confirmed',
    'Delivered',
    'Completed',
  ];

  String selectedCategory = 'Pending Order';
  String searchQuery = '';
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Category Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((category) {
              final isSelected = category == selectedCategory;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ChoiceChip(
                  label: Text(
                    category,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: Colors.black,
                  backgroundColor: Colors.grey.shade200,
                  checkmarkColor: Colors.white,
                  onSelected: (_) {
                    setState(() {
                      selectedCategory = category;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Search',
              border: const OutlineInputBorder(),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    searchQuery = '';
                  });
                },
              )
                  : null,
            ),
            onChanged: (val) {
              setState(() {
                searchQuery = val.trim().toLowerCase();
              });
            },
          ),
        ),

        // Orders List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              var orders = snapshot.data?.docs ?? [];

              // Filter by selected category on 'status' field
              orders = orders.where((doc) {
                final status = (doc['status'] ?? '').toString();
                return status ==
                    selectedCategory;
                // Adjust this if firestore stores status differently
              }).toList();

              // Apply search filter
              if (searchQuery.isNotEmpty) {
                orders = orders.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  // Search in multiple fields
                  final amazonPO = (data['amazonPONumber'] ?? '').toString().toLowerCase();
                  final bnbPO = (data['bnbPONumber'] ?? '').toString().toLowerCase();
                  final vendor = (data['vendor'] ?? '').toString().toLowerCase();
                  final location = (data['location'] ?? '').toString().toLowerCase();

                  return amazonPO.contains(searchQuery) ||
                      bnbPO.contains(searchQuery) ||
                      vendor.contains(searchQuery) ||
                      location.contains(searchQuery);
                }).toList();
              }

              if (orders.isEmpty) {
                return const Center(child: Text('No orders found.'));
              }

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  elevation: 4,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: IntrinsicWidth(
                            child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                                columnSpacing: 20,
                                dataRowMinHeight: 50,
                                dataRowMaxHeight: 60,
                                columns: const [
                                  DataColumn(label: Text('Amazon PO')),
                                  DataColumn(label: Text('Invoice No')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Vendor')),
                                  DataColumn(label: Text('Delivery Location')),
                                  DataColumn(label: Text('ASN')),
                                  DataColumn(label: Text('Appointment ID')),
                                  DataColumn(label: Text('Appointment Date')),
                                  DataColumn(label: Text('Product Details')),
                                ],
                                rows: orders.map((order) {
                                  final data = order.data() as Map<String, dynamic>;

                                  final Timestamp? ts = data['appointmentDate'];
                                  final String formattedDate = ts != null
                                      ? DateFormat('yyyy-MM-dd hh:mm a').format(ts.toDate())
                                      : '';

                                  // You can customize this status display if you want
                                  final status = data['status'] ?? '';

                                  return DataRow(cells: [
                                    DataCell(CopyableTextCell(
                                      text: data['amazonPONumber'] ?? '',
                                      tooltip: "Copy PO Number",
                                    )),
                                    DataCell(CopyableTextCell(
                                      text: data['invoiceNo'] ?? '',
                                      tooltip: "Copy Invoice No",
                                    )),
                                    DataCell(CopyableTextCell(
                                      text: status.toString(),
                                      tooltip: "Copy Status",
                                    )),
                                    DataCell(CopyableTextCell(
                                      text: data['vendor'] ?? '',
                                      tooltip: "Copy Vendor",
                                    )),
                                    DataCell(CopyableTextCell(
                                      text: data['location'] ?? '',
                                      tooltip: "Copy Location",
                                    )),
                                    DataCell(CopyableTextCell(
                                      text: data['asn'] ?? '',
                                      tooltip: "Copy ASN",
                                    )),
                                    DataCell(CopyableTextCell(
                                      text: data['appointmentId'] ?? '',
                                      tooltip: "Copy Appointment ID",
                                    )),
                                    DataCell(CopyableTextCell(
                                      text: formattedDate,
                                      tooltip: "Copy Appointment Date",
                                    )),
                                    DataCell(
                                      TextButton(
                                        child: const Text("See Details"),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => OrderDetailsPage(order: order,),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
