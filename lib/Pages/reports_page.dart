import 'dart:html' as html;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({Key? key}) : super(key: key);

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final TextEditingController amountController = TextEditingController();
  List<String> vendors = [];
  bool isVendorsLoading = true;
  String? selectedVendor;
  String? selectedReportType;
  String? attachmentUrl;
  String? selectedFileName;

  bool isUploadingFile = false;
  bool isGeneratingReport = false;
  bool showForm = false;

  final List<String> reportTypes = ['Advertisement', 'Sales', 'Promotion'];

  Future<void> fetchVendors() async {
    setState(() => isVendorsLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('vendors').get();
      vendors = snapshot.docs.map((doc) => doc['vendorName'].toString()).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load vendors: $e')),
      );
    } finally {
      setState(() => isVendorsLoading = false);
    }
  }

  Future<void> pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        isUploadingFile = true;
      });

      final fileBytes = result.files.single.bytes!;
      final fileName = result.files.single.name;

      try {
        final ref = FirebaseStorage.instance.ref('reports/$fileName');
        await ref.putData(fileBytes);

        final url = await ref.getDownloadURL();

        setState(() {
          attachmentUrl = url;
          selectedFileName = fileName;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      } finally {
        setState(() {
          isUploadingFile = false;
        });
      }
    }
  }

  Future<void> generateReport() async {
    if (selectedVendor == null || selectedReportType == null || attachmentUrl == null || amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() {
      isGeneratingReport = true;
    });

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'vendor': selectedVendor,
        'reportType': selectedReportType,
        'attachment': attachmentUrl,
        'amount': amountController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report generated successfully')),
      );

      setState(() {
        selectedVendor = null;
        selectedReportType = null;
        attachmentUrl = null;
        selectedFileName = null;
        amountController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e')),
      );
    } finally {
      setState(() {
        isGeneratingReport = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchVendors();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Reports', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Toggle Button
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 200),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() => showForm = !showForm);
                  },
                  icon: Icon(showForm ? Icons.close : Icons.add),
                  label: Text(showForm ? 'Close Form' : 'Add Report'),
                ),
              ),
              const SizedBox(height: 20),

              // Report Form (only show when toggled)
              if (showForm)
                isVendorsLoading
                    ? Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 20,
                    headingRowColor: MaterialStateColor.resolveWith((states) => Colors.grey.shade200),
                    columns: const [
                      DataColumn(label: Text('Vendor', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Report Type', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Attachment', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: [
                      DataRow(
                        cells: [
                          DataCell(
                            DropdownButton<String>(
                              value: selectedVendor,
                              hint: const Text('Select Vendor'),
                              items: vendors.map((vendor) {
                                return DropdownMenuItem<String>(
                                  value: vendor,
                                  child: Text(vendor),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedVendor = value;
                                });
                              },
                              isExpanded: true,
                            ),
                          ),
                          DataCell(
                            DropdownButton<String>(
                              value: selectedReportType,
                              hint: const Text('Select Report Type'),
                              items: reportTypes.map((type) {
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedReportType = value;
                                });
                              },
                              isExpanded: true,
                            ),
                          ),
                          DataCell(
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                              onPressed: isUploadingFile ? null : pickAndUploadFile,
                              icon: isUploadingFile
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                                  : const Icon(Icons.attach_file),
                              label: Text(
                                isUploadingFile ? 'Uploading...' : (selectedFileName ?? 'Select Attachment'),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: amountController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  hintText: 'Amount',
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(100, 40),
                              ),
                              onPressed: isGeneratingReport ? null : generateReport,
                              child: isGeneratingReport
                                  ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                                  : const Text('Generate'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 50),

              // Submitted Reports title
              const Text('Submitted Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // Reports list with StreamBuilder
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reports')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text('No reports found.');
                  }

                  final reports = snapshot.data!.docs;

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      headingRowColor: MaterialStateColor.resolveWith((states) => Colors.grey.shade200),
                      columns: const [
                        DataColumn(label: Text("Vendor", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("Type", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("Amount", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("Date & Time", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("Attachment", style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: reports.map((report) {
                        final vendor = report['vendor'] ?? '';
                        final type = report['reportType'] ?? '';
                        final amount = report['amount']?.toString() ?? '';
                        final url = report['attachment'] ?? '';
                        final Timestamp? timestamp = report['timestamp'] as Timestamp?;
                        final formattedDate = timestamp != null
                            ? DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate())
                            : 'No Date';
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(vendor),
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: vendor));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Vendor copied to clipboard')),
                                );
                              },
                            ),
                            DataCell(
                              Text(type),
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: type));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Type copied to clipboard')),
                                );
                              },
                            ),
                            DataCell(
                              Text("AED $amount"),
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: "AED $amount"));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Amount copied to clipboard')),
                                );
                              },
                            ),
                            DataCell(
                              Text(formattedDate),
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: formattedDate));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Date & Time copied to clipboard')),
                                );
                              },
                            ),
                            DataCell(
                              url.isNotEmpty
                                  ? ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  html.window.open(url, '_blank');
                                },
                                icon: const Icon(Icons.attach_file, color: Colors.white),
                                label: const Text(
                                  "View Attachment",
                                  style: TextStyle(color: Colors.white),
                                ),
                              )
                                  : const Text("-"),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
