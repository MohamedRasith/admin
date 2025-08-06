import 'dart:html' as html;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({Key? key}) : super(key: key);

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final TextEditingController amountController = TextEditingController();
  String? selectedVendor;
  String? selectedReportType;
  String? attachmentUrl;
  String? selectedFileName;

  bool isUploadingFile = false;
  bool isGeneratingReport = false;
  bool showForm = false;

  final List<String> reportTypes = ['Advertisement', 'Sales', 'Promotion'];

  Future<List<String>> fetchVendors() async {
    final snapshot = await FirebaseFirestore.instance.collection('vendors').get();
    return snapshot.docs.map((doc) => doc['vendorName'].toString()).toList();
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
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: fetchVendors(),
      builder: (context, snapshot) {
        final vendors = snapshot.data ?? [];

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
              backgroundColor: Colors.black,
              title: const Text('Reports', style: TextStyle(color: Colors.white),)),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ListView(
              children: [
                // Toggle Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white
                  ),
                  onPressed: () {
                    setState(() => showForm = !showForm);
                  },
                  icon: Icon(showForm ? Icons.close : Icons.add),
                  label: Text(showForm ? 'Close Form' : 'Add Report'),
                ),
                const SizedBox(height: 20),

                // Report Form
                if (showForm)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedVendor,
                        hint: const Text('Select Vendor'),
                        items: vendors.map((vendor) {
                          return DropdownMenuItem(value: vendor, child: Text(vendor));
                        }).toList(),
                        onChanged: (value) => setState(() => selectedVendor = value),
                        decoration: const InputDecoration(labelText: 'Vendor'),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedReportType,
                        hint: const Text('Select Report Type'),
                        items: reportTypes.map((type) {
                          return DropdownMenuItem(value: type, child: Text(type));
                        }).toList(),
                        onChanged: (value) => setState(() => selectedReportType = value),
                        decoration: const InputDecoration(labelText: 'Report Type'),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white
                        ),
                        onPressed: isUploadingFile ? null : pickAndUploadFile,
                        icon: isUploadingFile
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.attach_file),
                        label: Text(
                          isUploadingFile
                              ? 'Uploading...'
                              : (selectedFileName ?? 'Select Attachment'),
                        ),
                      ),
                      if (attachmentUrl != null)
                        const Text('File uploaded ✅', style: TextStyle(color: Colors.green)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white
                          ),
                          onPressed: isGeneratingReport ? null : generateReport,
                          child: isGeneratingReport
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Text('Generate Report'),
                        ),
                      ),
                      const Divider(height: 32),
                    ],
                  ),

                // Report List
                const Text('Submitted Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
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

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final report = snapshot.data!.docs[index];
                        final vendor = report['vendor'] ?? '';
                        final type = report['reportType'] ?? '';
                        final amount = report['amount'] ?? '';
                        final url = report['attachment'] ?? '';
                        final Timestamp timestamp = report['timestamp'];
                        final DateTime dateTime = timestamp.toDate();
                        final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);

                        return Card(
                          color: Colors.white,
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text('$vendor - $type'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Amount: AED $amount'),
                                Text('Date & Time: $formattedDate'),
                                if (url.isNotEmpty)
                                  RawMaterialButton(
                                    onPressed: () {
                                      html.window.open(url, '_blank');
                                    },
                                    fillColor: Colors.blue,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    elevation: 0,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.attach_file, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text(
                                          'View Attachment',
                                          style: TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
