import 'package:admin/Pages/update_vendor.dart';
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

  void _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Vendor"),
        content: const Text("Are you sure you want to delete this vendor?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes, Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('vendors')
          .doc(widget.vendor.id)
          .delete();

      if (mounted) {
        Navigator.pop(context); // Go back after deletion
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vendor deleted successfully")),
        );
      }
    }
  }

  void _navigateToUpdatePage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UpdateVendorPage(vendor: widget.vendor),
      ),
    );
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
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: Personal Details
                  Expanded(
                    child: ListView(
                      children: [
                        const Text("Personal Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                        _buildDetailTile("Company Name", widget.vendor['companyName']),
                        _buildDetailTile("Contact Person", widget.vendor['contactPersonName']),
                        _buildDetailTile("Contact Number", widget.vendor['contactPersonNumber']),
                        _buildDetailTile("Email", widget.vendor['contactPersonEmail']),
                        _buildDetailTile("Trade License No.", widget.vendor['tradeLicenseNumber']),
                        _buildDetailTile("VAT No.", widget.vendor['vatNumber']),
                        _buildDetailTile("Address", "${widget.vendor['addressLine1']} | ${widget.vendor['addressLine2']} | ${widget.vendor['city']} | ${widget.vendor['country']}"),
                        _buildDetailTile("Password", widget.vendor['password']),
                      ],
                    ),
                  ),

                  // Section 2: Bank Details
                  Expanded(
                    child: ListView(
                      children: [
                        const Text("Bank Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                        _buildDetailTile("Bank Name", widget.vendor['bankName']),
                        _buildDetailTile("Bank Account Name", widget.vendor['bankAccountName']),
                        _buildDetailTile("Bank Account Number", widget.vendor['bankAccountNumber']),
                        _buildDetailTile("IBAN", widget.vendor['ibanNumber']),
                      ],
                    ),
                  ),

                  // Section 3: Uploaded Files
                  Expanded(
                    child: ListView(
                      children: [
                        const Text("Uploaded Files", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                        _buildFileLink(context, "Trade License", widget.vendor['tradeLicenseUrl']),
                        _buildFileLink(context, "VAT Certificate", widget.vendor['vatCertificateUrl']),
                        _buildFileLink(context, "Bank Letter", widget.vendor['bankLetterUrl']),
                        _buildFileLink(context, "Authorization Letter", widget.vendor['authorizationLetterUrl']),
                        _buildFileLink(context, "Agreement", widget.vendor['agreementUrl']),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ✅ Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _navigateToUpdatePage,
                  icon: const Icon(Icons.edit),
                  label: const Text("Update"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete),
                  label: const Text("Delete"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile(String label, String? value) {
    return ListTile(
      title: SelectableText(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: SelectableText(value ?? '-'),
    );
  }

  Widget _buildFileLink(BuildContext context, String label, String? url) {
    return url != null
        ? ListTile(
      title: SelectableText(label),
      trailing: const Icon(Icons.picture_as_pdf),
      onTap: () => openUrlFallback(url),
    )
        : ListTile(title: Text("$label: Not Uploaded"));
  }
}
