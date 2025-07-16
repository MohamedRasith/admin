import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:universal_html/html.dart' as html;

class VendorDetailPage extends StatefulWidget {
  final DocumentSnapshot vendor;

  const VendorDetailPage({super.key, required this.vendor});

  @override
  State<VendorDetailPage> createState() => _VendorDetailPageState();
}

class _VendorDetailPageState extends State<VendorDetailPage> {
  void openUrlFallback(String url) {
    html.window.open(url, '_blank');
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.vendor['vendorName'] ?? 'Vendor Details'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: ListView(
                children: [
                  const Text("Personal Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),),
                  _buildDetailTile("Company Name", widget.vendor['companyName']),
                  _buildDetailTile("Contact Person", widget.vendor['contactPersonName']),
                  _buildDetailTile("Contact Number", widget.vendor['contactPersonNumber']),
                  _buildDetailTile("Email", widget.vendor['contactPersonEmail']),
                  _buildDetailTile("Trade License No.", widget.vendor['tradeLicenseNumber']),
                  _buildDetailTile("VAT No.", widget.vendor['vatNumber']),
                  _buildDetailTile("Address", "${widget.vendor['addressLine1']} | ${widget.vendor['addressLine2']} | ${widget.vendor['city']} | ${widget.vendor['country']}"),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  const Text("Bank Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),),
                  _buildDetailTile("Bank Name", widget.vendor['bankName']),
                  _buildDetailTile("Bank Account Name", widget.vendor['bankAccountName']),
                  _buildDetailTile("Bank Account Number", widget.vendor['bankAccountNumber']),
                  _buildDetailTile("IBAN", widget.vendor['ibanNumber']),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  const Text("Uploaded Files", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),),
                  _buildFileLink(context, "Trade License", widget.vendor['tradeLicenseUrl']),
                  _buildFileLink(context, "VAT Certificate", widget.vendor['vatCertificateUrl']),
                  _buildFileLink(context, "Bank Letter", widget.vendor['bankLetterUrl']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile(String label, String? value) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold),),
      subtitle: Text(value ?? '-'),
    );
  }

  Widget _buildFileLink(BuildContext context, String label, String? url) {
    return url != null
        ? ListTile(
      title: Text(label),
      trailing: const Icon(Icons.picture_as_pdf),
      onTap: () {
        openUrlFallback(url);
      },
    )
        : ListTile(title: Text("$label: Not Uploaded"));
  }
}
