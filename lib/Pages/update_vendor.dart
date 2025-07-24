import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class UpdateVendorPage extends StatefulWidget {
  final DocumentSnapshot vendor;
  const UpdateVendorPage({super.key, required this.vendor});

  @override
  State<UpdateVendorPage> createState() => _UpdateVendorPageState();
}

class _UpdateVendorPageState extends State<UpdateVendorPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController vendorNameController;
  late TextEditingController companyNameController;
  late TextEditingController tradeLicenseController;
  late TextEditingController vatNumberController;
  late TextEditingController addressLine1Controller;
  late TextEditingController addressLine2Controller;
  late TextEditingController contactNameController;
  late TextEditingController contactNumberController;
  late TextEditingController contactEmailController;
  late TextEditingController passwordController;
  late TextEditingController confirmPasswordController;
  late TextEditingController bankNameController;
  late TextEditingController bankAccountNameController;
  late TextEditingController bankNumberController;
  late TextEditingController ibanNumberController;

  String? selectedCity;
  String? selectedCountry;

  PlatformFile? tradeLicenseFile;
  PlatformFile? vatCertificateFile;
  PlatformFile? bankLetterFile;
  PlatformFile? authorizationLetterFile;
  PlatformFile? agreementFile;

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  @override
  void initState() {
    final data = widget.vendor.data() as Map<String, dynamic>;

    vendorNameController = TextEditingController(text: data['vendorName']);
    companyNameController = TextEditingController(text: data['companyName']);
    tradeLicenseController = TextEditingController(text: data['tradeLicenseNumber']);
    vatNumberController = TextEditingController(text: data['vatNumber']);
    addressLine1Controller = TextEditingController(text: data['addressLine1']);
    addressLine2Controller = TextEditingController(text: data['addressLine2']);
    contactNameController = TextEditingController(text: data['contactPersonName']);
    contactNumberController = TextEditingController(text: data['contactPersonNumber']);
    contactEmailController = TextEditingController(text: data['contactPersonEmail']);
    passwordController = TextEditingController(text: data['password']);
    confirmPasswordController = TextEditingController(text: data['password']);
    bankNameController = TextEditingController(text: data['bankName']);
    bankAccountNameController = TextEditingController(text: data['bankAccountName']);
    bankNumberController = TextEditingController(text: data['bankAccountNumber']);
    ibanNumberController = TextEditingController(text: data['ibanNumber']);
    selectedCity = data['city'];
    selectedCountry = data['country'];
    super.initState();
  }

  Future<String?> uploadFileToStorage(PlatformFile? file, String folder) async {
    if (file == null) return null;
    final ref = FirebaseStorage.instance.ref().child('$folder/${file.name}');
    await ref.putData(file.bytes!);
    return await ref.getDownloadURL();
  }

  Future<void> pickFile(String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        switch (type) {
          case 'tradeLicense':
            tradeLicenseFile = file;
            break;
          case 'vatCertificate':
            vatCertificateFile = file;
            break;
          case 'bankLetter':
            bankLetterFile = file;
            break;
          case 'authorizationLetter':
            authorizationLetterFile = file;
            break;
          case 'agreement':
            agreementFile = file;
            break;
        }
      });
    }
  }

  Future<void> updateVendor() async {
    if (_formKey.currentState!.validate()) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Updating vendor...")),
        );

        final updatedData = {
          'vendorName': vendorNameController.text,
          'companyName': companyNameController.text,
          'tradeLicenseNumber': tradeLicenseController.text,
          'vatNumber': vatNumberController.text,
          'addressLine1': addressLine1Controller.text,
          'addressLine2': addressLine2Controller.text,
          'city': selectedCity,
          'country': selectedCountry,
          'contactPersonName': contactNameController.text,
          'contactPersonNumber': contactNumberController.text,
          'contactPersonEmail': contactEmailController.text,
          'bankName': bankNameController.text,
          'bankAccountName': bankAccountNameController.text,
          'bankAccountNumber': bankNumberController.text,
          'ibanNumber': ibanNumberController.text,
          'password': passwordController.text,
          'updatedAt': Timestamp.now(),
        };

        // Upload files if new ones selected
        if (tradeLicenseFile != null) {
          updatedData['tradeLicenseUrl'] = await uploadFileToStorage(tradeLicenseFile, 'trade_licenses');
        }
        if (vatCertificateFile != null) {
          updatedData['vatCertificateUrl'] = await uploadFileToStorage(vatCertificateFile, 'vat_certificates');
        }
        if (bankLetterFile != null) {
          updatedData['bankLetterUrl'] = await uploadFileToStorage(bankLetterFile, 'bank_letters');
        }
        if (authorizationLetterFile != null) {
          updatedData['authorizationLetterUrl'] = await uploadFileToStorage(authorizationLetterFile, 'authorization_letters');
        }
        if (agreementFile != null) {
          updatedData['agreementUrl'] = await uploadFileToStorage(agreementFile, 'agreements');
        }

        await FirebaseFirestore.instance.collection('vendors').doc(widget.vendor.id).update(updatedData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vendor updated successfully!")),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Update Vendor ${widget.vendor['vendorName']}", style: TextStyle(color: Colors.white),),
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField("Vendor Name", vendorNameController),
              _buildTextField("Company Name", companyNameController),
              _buildTextField("Trade License Number", tradeLicenseController),
              _buildTextField("VAT Number", vatNumberController),
              _buildTextField("Address Line 1", addressLine1Controller),
              _buildTextField("Address Line 2", addressLine2Controller),
              _buildDropdown("City / State", selectedCity, ['Dubai', 'Abu Dhabi', 'Sharjah', 'Ajman'],
                      (val) => setState(() => selectedCity = val)),
              _buildDropdown("Country", selectedCountry, ['United Arab Emirates', 'Saudi Arabia', 'Qatar', 'Kuwait'],
                      (val) => setState(() => selectedCountry = val)),
              _buildTextField("Contact Person Name", contactNameController),
              _buildTextField("Contact Person Number", contactNumberController),
              _buildTextField("Contact Person Email", contactEmailController),
              _buildPasswordField("Password", passwordController, _passwordVisible, () {
                setState(() => _passwordVisible = !_passwordVisible);
              }),
              _buildPasswordField("Confirm Password", confirmPasswordController, _confirmPasswordVisible, () {
                setState(() => _confirmPasswordVisible = !_confirmPasswordVisible);
              }),
              const SizedBox(height: 20),
              _buildFileUpload("Trade License", tradeLicenseFile?.name, () => pickFile('tradeLicense')),
              _buildFileUpload("VAT Certificate", vatCertificateFile?.name, () => pickFile('vatCertificate')),
              _buildFileUpload("Bank Letter", bankLetterFile?.name, () => pickFile('bankLetter')),
              _buildFileUpload("Authorization Letter", authorizationLetterFile?.name, () => pickFile('authorizationLetter')),
              _buildFileUpload("Agreement", agreementFile?.name, () => pickFile('agreement')),
              const SizedBox(height: 20),
              _buildTextField("Bank Name", bankNameController),
              _buildTextField("Bank Account Name", bankAccountNameController),
              _buildTextField("Bank Account Number", bankNumberController),
              _buildTextField("IBAN Number", ibanNumberController),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: updateVendor,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                child: const Text("Update Vendor", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> options, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        onChanged: onChanged,
        items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (val) => val == null ? 'Required' : null,
      ),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller, bool isVisible, VoidCallback toggleVisibility) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: !isVisible,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off),
            onPressed: toggleVisibility,
          ),
        ),
        validator: (val) {
          if (val == null || val.isEmpty) return 'Required';
          if (label == "Confirm Password" && val != passwordController.text) {
            return 'Passwords do not match';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildFileUpload(String label, String? fileName, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(fileName != null ? "$label: $fileName" : "$label: Not selected")),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text("Upload", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
