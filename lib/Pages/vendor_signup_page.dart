import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class VendorSignupPage extends StatefulWidget {
  const VendorSignupPage({super.key});

  @override
  State<VendorSignupPage> createState() => _VendorSignupPageState();
}

class _VendorSignupPageState extends State<VendorSignupPage> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers
  final vendorNameController = TextEditingController();
  final companyNameController = TextEditingController();
  final tradeLicenseController = TextEditingController();
  final vatNumberController = TextEditingController();
  final addressLine1Controller = TextEditingController();
  final addressLine2Controller = TextEditingController();

  String? selectedCity;
  String? selectedCountry;

  final List<String> cityOptions = ['Dubai', 'Abu Dhabi', 'Sharjah', 'Ajman'];
  final List<String> countryOptions = ['United Arab Emirates', 'Saudi Arabia', 'Qatar', 'Kuwait'];
  final contactNameController = TextEditingController();
  final contactNumberController = TextEditingController();
  final contactEmailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  final bankNameController = TextEditingController();
  final bankAccountNameController = TextEditingController();
  final bankNumberController = TextEditingController();
  final ibanNumberController = TextEditingController();

  // Dummy file paths
  PlatformFile? tradeLicenseFile;
  PlatformFile? vatCertificateFile;
  PlatformFile? bankLetterFile;

  Future<String?> uploadFileToStorage(PlatformFile? file, String folder) async {
    if (file == null) return null;

    final storageRef = FirebaseStorage.instance.ref().child('$folder/${file.name}');
    final uploadTask = await storageRef.putData(file.bytes!);
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    return downloadUrl;
  }


  Future<void> pickFile(String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        final file = result.files.first;
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
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Vendor Signup"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // SECTION 1: Basic Vendor Info
              const Text("Vendor Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              _buildTextField("Vendor Name", vendorNameController),
              _buildTextField("Company Name", companyNameController),
              _buildTextField("Trade License Number", tradeLicenseController),
              _buildTextField("VAT No.", vatNumberController),
              const Text("Billing Address", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildTextField("Address Line 1", addressLine1Controller),
              _buildTextField("Address Line 2", addressLine2Controller),

              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: 400,
                  child: DropdownButtonFormField<String>(
                    value: selectedCity,
                    items: cityOptions
                        .map((city) => DropdownMenuItem(value: city, child: Text(city)))
                        .toList(),
                    onChanged: (value) => setState(() => selectedCity = value),
                    validator: (value) => value == null ? "Select City/State" : null,
                    decoration: const InputDecoration(
                      labelText: 'City / State',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: 400,
                  child: DropdownButtonFormField<String>(
                    value: selectedCountry,
                    items: countryOptions
                        .map((country) => DropdownMenuItem(value: country, child: Text(country)))
                        .toList(),
                    onChanged: (value) => setState(() => selectedCountry = value),
                    validator: (value) => value == null ? "Select Country" : null,
                    decoration: const InputDecoration(
                      labelText: 'Country',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),


              const SizedBox(height: 24),

              // SECTION 2: Contact Info
              const Text("Contact Person", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              _buildTextField("Contact Person Name", contactNameController),
              _buildTextField("Contact Person Number", contactNumberController, keyboardType: TextInputType.phone),
              _buildTextField("Contact Person Email", contactEmailController, keyboardType: TextInputType.emailAddress),
              _buildPasswordField(
                "Password",
                passwordController,
                _passwordVisible,
                    () => setState(() => _passwordVisible = !_passwordVisible),
              ),
              _buildPasswordField(
                "Confirm Password",
                confirmPasswordController,
                _confirmPasswordVisible,
                    () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
              ),


              const SizedBox(height: 24),

              // SECTION 3: Upload Documents
              const Text("File Uploads", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              _buildFileUpload("Trade License", tradeLicenseFile?.name, () => pickFile('tradeLicense')),
              _buildFileUpload("VAT Certificate", vatCertificateFile?.name, () => pickFile('vatCertificate')),
              _buildFileUpload("Bank Letter", bankLetterFile?.name, () => pickFile('bankLetter')),

              const SizedBox(height: 24),

              // SECTION 4: Bank Details
              const Text("Bank Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              _buildTextField("Bank Name", bankNameController),
              _buildTextField("Bank Account Name", bankAccountNameController),
              _buildTextField("Bank Account Number", bankNumberController),
              _buildTextField("IBAN Number", ibanNumberController),

              const SizedBox(height: 32),

              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Uploading...")),
                      );

                      try {
                        // Upload each file and get download URLs
                        String? tradeLicenseUrl = await uploadFileToStorage(tradeLicenseFile, 'trade_licenses');
                        String? vatCertificateUrl = await uploadFileToStorage(vatCertificateFile, 'vat_certificates');
                        String? bankLetterUrl = await uploadFileToStorage(bankLetterFile, 'bank_letters');

                        // Create vendor data map
                        final vendorData = {
                          'vendorName': vendorNameController.text.trim(),
                          'companyName': companyNameController.text.trim(),
                          'tradeLicenseNumber': tradeLicenseController.text.trim(),
                          'vatNumber': vatNumberController.text.trim(),
                          'addressLine1': addressLine1Controller.text.trim(),
                          'addressLine2': addressLine2Controller.text.trim(),
                          'city': selectedCity,
                          'country': selectedCountry,
                          'contactPersonName': contactNameController.text.trim(),
                          'contactPersonNumber': contactNumberController.text.trim(),
                          'contactPersonEmail': contactEmailController.text.trim(),
                          'bankName': bankNameController.text.trim(),
                          'bankAccountName': bankAccountNameController.text.trim(),
                          'bankAccountNumber': bankNumberController.text.trim(),
                          'ibanNumber': ibanNumberController.text.trim(),
                          'tradeLicenseUrl': tradeLicenseUrl,
                          'vatCertificateUrl': vatCertificateUrl,
                          'bankLetterUrl': bankLetterUrl,
                          'password': passwordController.text.trim(),
                          'createdAt': Timestamp.now(),
                        };

                        await FirebaseFirestore.instance.collection('vendors').add(vendorData);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Vendor registered successfully!")),
                        );

                        // Optionally clear form
                        _formKey.currentState!.reset();
                        setState(() {
                          tradeLicenseFile = null;
                          vatCertificateFile = null;
                          bankLetterFile = null;
                        });
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error: $e")),
                        );
                      }
                    }
                  },
                  child: const Text("Submit", style: TextStyle(color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        width: 400,
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: (value) => value == null || value.isEmpty ? "Required field" : null,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _buildFileUpload(String label, String? fileName, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
              width: 300,
              child: Text(fileName != null ? "$label: $fileName" : "$label: Not selected")),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text("Upload", style: TextStyle(color: Colors.white),),
          )
        ],
      ),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller, bool isVisible, VoidCallback toggleVisibility) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        width: 400,
        child: TextFormField(
          controller: controller,
          obscureText: !isVisible,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Required field';
            if (label == "Confirm Password" && value != passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off),
              onPressed: toggleVisibility,
            ),
          ),
        ),
      ),
    );
  }


}
