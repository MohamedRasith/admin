import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AmazonMarginPage extends StatefulWidget {
  const AmazonMarginPage({super.key});

  @override
  State<AmazonMarginPage> createState() => _AmazonMarginPageState();
}

class _AmazonMarginPageState extends State<AmazonMarginPage> {
  List<Map<String, dynamic>> amazonMargins = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMargins();
  }

  Future<void> fetchMargins() async {
    final snapshot = await FirebaseFirestore.instance.collection('margins').get();
    setState(() {
      amazonMargins = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // For deletion
        return data;
      }).toList();
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return buildMarginTable();
  }

  Widget buildMarginTable() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (amazonMargins.isEmpty) {
      return Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text("Add Margin"),
          onPressed: () => showAddMarginBottomSheet(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("Add Margin"),
              onPressed: () => showAddMarginBottomSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              color: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        columnSpacing: 20,
                        dataRowMinHeight: 50,
                        dataRowMaxHeight: 70,
                        columns: const [
                          DataColumn(label: Text("Region")),
                          DataColumn(label: Text("Platform")),
                          DataColumn(label: Text("Account")),
                          DataColumn(label: Text("Vendor Code")),
                          DataColumn(label: Text("Front Margin (%)")),
                          DataColumn(label: Text("Back Margin (%)")),
                          DataColumn(label: Text("GMM (%)")),
                          DataColumn(label: Text("Actions")),
                        ],
                        rows: amazonMargins.map((item) {
                          final totalMargin = (item['frontMargin'] ?? 0) +
                              (item['backMargin'] ?? 0) +
                              (item['gmm'] ?? 0);

                          return DataRow(
                            cells: [
                              DataCell(Text(item['region'] ?? '')),
                              DataCell(Text(item['platform'] ?? '')),
                              DataCell(Text(item['account'] ?? '')),
                              DataCell(Text(item['vendorCode'] ?? '')),
                              DataCell(Text("${item['frontMargin']}")),
                              DataCell(Text("${item['backMargin']}")),
                              DataCell(Text("${item['gmm']}")),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    final docId = item['id'];
                                    await FirebaseFirestore.instance
                                        .collection('margins')
                                        .doc(docId)
                                        .delete();
                                    fetchMargins(); // Refresh after delete
                                  },
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }


  void showAddMarginBottomSheet(BuildContext context) {
    final accountController = TextEditingController();
    final vendorCodeController = TextEditingController();
    final frontMarginController = TextEditingController();
    final backMarginController = TextEditingController();
    final gmmController = TextEditingController();
    String selectedRegion = 'UAE'; // default
    const String defaultPlatform = 'Amazon';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 16,
            right: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Add Margin", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRegion,
                  decoration: const InputDecoration(
                    labelText: 'Region',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'UAE', child: Text('UAE')),
                    DropdownMenuItem(value: 'KSA', child: Text('KSA')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedRegion = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: defaultPlatform,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Platform',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                buildTextField("Account", accountController),
                buildTextField("Vendor Code", vendorCodeController),
                buildTextField("Front Margin (%)", frontMarginController, isNumber: true),
                buildTextField("Back Margin (%)", backMarginController, isNumber: true),
                buildTextField("GMM (%)", gmmController, isNumber: true),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (accountController.text.isEmpty ||
                        vendorCodeController.text.isEmpty ||
                        frontMarginController.text.isEmpty ||
                        backMarginController.text.isEmpty ||
                        gmmController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("All fields are mandatory")),
                      );
                      return;
                    }

                    final newMargin = {
                      'region': selectedRegion,
                      'platform': defaultPlatform,
                      'account': accountController.text.trim(),
                      'vendorCode': vendorCodeController.text.trim(),
                      'frontMargin': int.tryParse(frontMarginController.text) ?? 0,
                      'backMargin': int.tryParse(backMarginController.text) ?? 0,
                      'gmm': int.tryParse(gmmController.text) ?? 0,
                    };

                    await FirebaseFirestore.instance.collection('margins').add(newMargin);

                    Navigator.pop(context);
                    fetchMargins(); // Refresh list
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text("Add"),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildTextField(String label, TextEditingController controller, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
