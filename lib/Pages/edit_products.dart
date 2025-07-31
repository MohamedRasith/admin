import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class EditProductPage extends StatefulWidget {
  final DocumentSnapshot product;

  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController brandController;
  late TextEditingController titleController;
  late TextEditingController categoryController;
  late TextEditingController subCategoryController;
  late TextEditingController originController;
  late TextEditingController priceController;
  late TextEditingController asinController;
  late TextEditingController ninController;
  late TextEditingController vendorController;
  late TextEditingController barcodeController;
  late TextEditingController descriptionController;
  late TextEditingController feature1Controller;
  late TextEditingController feature2Controller;
  late TextEditingController feature3Controller;
  late TextEditingController feature4Controller;
  late TextEditingController purchaseController;
  late TextEditingController weightController;
  late TextEditingController heightController;
  late TextEditingController lengthController;
  late TextEditingController widthController;
  Map<String, bool> isUploadingImage = {
    'Image 1': false,
    'Image 2': false,
    'Image 3': false,
    'Image 4': false,
    'Image 5': false,
  };
  Map<String, String?> imageUrls = {};
  final CarouselController _carouselController = CarouselController();
  int _currentImageIndex = 0;
  Map<String, String?> originalImageUrls = {};

  String getVendorName(DocumentSnapshot product) {
    final data = product.data() as Map<String, dynamic>;

    if (data.containsKey('Vendor') && data['Vendor'] != null) {
      return data['Vendor'].toString();
    } else if (data.containsKey('Vendor ') && data['Vendor '] != null) {
      return data['Vendor '].toString();
    } else {
      return 'No Vendor';
    }
  }

  @override
  void initState() {
    super.initState();
    final data = widget.product.data() as Map<String, dynamic>;
    for (int i = 1; i <= 12; i++) {
      final key = 'Image $i';
      final url = data[key] as String? ?? '';
      imageUrls[key] = url;
      originalImageUrls[key] = url;
    }
    brandController = TextEditingController(text: widget.product['Brand'] ?? '');
    titleController = TextEditingController(text: widget.product['Product Title'] ?? '');
    categoryController = TextEditingController(text: widget.product['Category'] ?? '');
    subCategoryController = TextEditingController(text: widget.product['Sub Category'] ?? '');
    originController = TextEditingController(text: widget.product['Country of Origin'] ?? '');
    priceController = TextEditingController(text: widget.product['RSP']?.toString() ?? '');
    asinController = TextEditingController(text: widget.product['ASIN'] ?? '');
    ninController = TextEditingController(text: widget.product['NIN'] ?? '');
    vendorController = TextEditingController(text: getVendorName(widget.product));
    barcodeController = TextEditingController(text: widget.product['Barcode'] ?? '');
    descriptionController = TextEditingController(text: widget.product['Description'] ?? '');
    feature1Controller = TextEditingController(text: widget.product['Feature 1'] ?? '');
    feature2Controller = TextEditingController(text: widget.product['Feature 2'] ?? '');
    feature3Controller = TextEditingController(text: widget.product['Feature 3'] ?? '');
    feature4Controller = TextEditingController(text: widget.product['Feature 4'] ?? '');
    purchaseController = TextEditingController(text: widget.product['Purchase Price']?.toString() ?? '');
    weightController = TextEditingController(text: widget.product['Weight KG']?.toString() ?? '');
    heightController = TextEditingController(text: widget.product['Height CM']?.toString() ?? '');
    lengthController = TextEditingController(text: widget.product['Length CM']?.toString() ?? '');
    widthController = TextEditingController(text: widget.product['Width CM']?.toString() ?? '');
  }

  Future<void> deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Product"),
        content: const Text("Are you sure you want to delete this product?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product.id)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully')),
      );
      Navigator.pop(context);
    }
  }


  Future<void> _pickAndUploadImage(String key) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);

    if (result == null || result.files.isEmpty) return;

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
      final ref = FirebaseStorage.instance.ref('product_images/$fileName');

      // 🔴 Delete previous image from storage (if any)
      final oldUrl = imageUrls[key];
      if (oldUrl != null && oldUrl.isNotEmpty) {
        try {
          final oldRef = FirebaseStorage.instance.refFromURL(oldUrl);
          await oldRef.delete();
        } catch (e) {
          debugPrint('Failed to delete old image: $e');
        }
      }

      // ✅ Upload new image
      UploadTask uploadTask;
      if (kIsWeb) {
        // For Web
        final Uint8List fileBytes = result.files.single.bytes!;
        uploadTask = ref.putData(fileBytes);
      } else {
        // For Mobile/Desktop
        final filePath = result.files.single.path!;
        final file = File(filePath);
        uploadTask = ref.putFile(file);
      }

      final snap = await uploadTask;
      final newUrl = await snap.ref.getDownloadURL();

      setState(() {
        imageUrls[key] = '$newUrl?ts=${DateTime.now().millisecondsSinceEpoch}'; // cache bust
      });

      // ✅ Update Firestore (save clean URL without timestamp)
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product.id)
          .update({key: newUrl});

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$key updated')));
    } catch (e) {
      debugPrint('Image update failed for $key: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update $key')));
    }
  }




  Future<void> updateProduct() async {
    if (_formKey.currentState?.validate() != true) return;

    Map<String, dynamic> updateData = {
      'Brand': brandController.text.trim(),
      'Product Title': titleController.text.trim(),
      'Category': categoryController.text.trim(),
      'Sub Category': subCategoryController.text.trim(),
      'Country of Origin': originController.text.trim(),
      'RSP': double.tryParse(priceController.text.trim()) ?? 0.0,
      'ASIN': asinController.text.trim(),
      'NIN': ninController.text.trim(),
      'Vendor ': vendorController.text.trim(),
      'Barcode': barcodeController.text.trim(),
      'Description': descriptionController.text.trim(),
      'Feature 1': feature1Controller.text.trim(),
      'Feature 2': feature2Controller.text.trim(),
      'Feature 3': feature3Controller.text.trim(),
      'Feature 4': feature4Controller.text.trim(),
      'Purchase Price': double.tryParse(purchaseController.text.trim()) ?? 0.0,
      'Weight KG': double.tryParse(weightController.text.trim()) ?? 0.0,
      'Height CM': double.tryParse(heightController.text.trim()) ?? 0.0,
      'Length CM': double.tryParse(lengthController.text.trim()) ?? 0.0,
      'Width CM': double.tryParse(widthController.text.trim()) ?? 0.0,
    };

    // Only add changed image URLs
    for (int i = 1; i <= 12; i++) {
      final key = 'Image $i';
      final currentUrl = imageUrls[key] ?? '';
      final originalUrl = originalImageUrls[key] ?? '';
      if (currentUrl != originalUrl) {
        updateData[key] = currentUrl;
      }
    }

    await FirebaseFirestore.instance
        .collection('products')
        .doc(widget.product.id)
        .update(updateData);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product updated successfully')),
    );
    Navigator.pop(context);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text("Product Details", style: TextStyle(color: Colors.white),)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              runSpacing: 12,
              children: [
                TextFormField(controller: brandController, decoration: const InputDecoration(labelText: 'Brand'), validator: (val) => val!.isEmpty ? 'Required' : null),
                TextFormField(controller: titleController, decoration: const InputDecoration(labelText: 'Product Title'), validator: (val) => val!.isEmpty ? 'Required' : null),
                TextFormField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category')),
                TextFormField(controller: subCategoryController, decoration: const InputDecoration(labelText: 'Sub Category')),
                TextFormField(controller: originController, decoration: const InputDecoration(labelText: 'Country of Origin')),
                TextFormField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (RSP)')),
                TextFormField(controller: asinController, decoration: const InputDecoration(labelText: 'ASIN')),
                TextFormField(controller: ninController, decoration: const InputDecoration(labelText: 'NIN')),
                TextFormField(controller: vendorController, decoration: const InputDecoration(labelText: 'Vendor')),
                TextFormField(controller: barcodeController, decoration: const InputDecoration(labelText: 'Barcode')),
                TextFormField(controller: descriptionController, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
                TextFormField(controller: feature1Controller, decoration: const InputDecoration(labelText: 'Feature 1')),
                TextFormField(controller: feature2Controller, decoration: const InputDecoration(labelText: 'Feature 2')),
                TextFormField(controller: feature3Controller, decoration: const InputDecoration(labelText: 'Feature 3')),
                TextFormField(controller: feature4Controller, decoration: const InputDecoration(labelText: 'Feature 4')),
                TextFormField(controller: purchaseController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Purchase Price')),
                TextFormField(controller: weightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weight (KG)')),
                TextFormField(controller: heightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height (CM)')),
                TextFormField(controller: lengthController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Length (CM)')),
                TextFormField(controller: widthController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Width (CM)')),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: List.generate(12, (i) {
                    final key = 'Image ${i + 1}';
                    final url = imageUrls[key];
                    final hasImage = url != null && url.isNotEmpty;
                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('Preview $key'),
                            backgroundColor: Colors.white,
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (url != null && url.isNotEmpty)
                                  Image.network(url, height: 200, fit: BoxFit.cover)
                                else
                                  Container(
                                    height: 200,
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.image_not_supported, size: 50),
                                  ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  label: Text( hasImage ? 'Change Image' : 'Add Image', style: TextStyle(color: Colors.white),),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                  onPressed: () async {
                                    Navigator.pop(context); // Close dialog first
                                    setState(() => isUploadingImage[key] = true);
                                    await _pickAndUploadImage(key);
                                    setState(() => isUploadingImage[key] = false);
                                  },
                                ),
                                const SizedBox(height: 10),
                                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close))
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12), // curved corners
                          border: Border.all(color: Colors.grey.shade600, width: 1.5), // border
                          image: (url != null && url.isNotEmpty)
                              ? DecorationImage(
                            image: NetworkImage(url),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: isUploadingImage[key] == true
                            ? const Center(child: CircularProgressIndicator())
                            : (url == null || url.isEmpty)
                            ? const Center(child: Icon(Icons.add_a_photo, color: Colors.grey))
                            : null,
                      ),

                    );
                  }),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: updateProduct,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                      child: const Text("Update Product", style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(
                      width: 20,
                    ),
                    ElevatedButton(
                      onPressed: deleteProduct,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("Delete Product", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
