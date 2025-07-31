import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:admin/widget/category_drop_down.dart';
import 'package:admin/widget/sub_category_drop_down.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  bool isLoading = false;
  bool isImageLoading = false;
  final _formKey = GlobalKey<FormState>();
  final List<String> categories = ['Electronics', 'Fashion', 'Home', 'Books'];
  final Map<String, List<String>> subcategories = {
    'Electronics': ['Mobiles', 'Laptops', 'Cameras'],
    'Fashion': ['Men', 'Women', 'Kids'],
    'Home': ['Furniture', 'Decor', 'Kitchen'],
    'Books': ['Fiction', 'Non-fiction', 'Academic'],
  };

  String? selectedCategory;
  String? selectedSubCategory;
  final Map<String, TextEditingController> controllers = {
    'brand': TextEditingController(),
    'title': TextEditingController(),
    'barcode': TextEditingController(),
    'asin': TextEditingController(),
    'nin': TextEditingController(),
    'description': TextEditingController(),
    'category': TextEditingController(),
    'subcategory': TextEditingController(),
    'feature1': TextEditingController(),
    'feature2': TextEditingController(),
    'feature3': TextEditingController(),
    'feature4': TextEditingController(),
    'weight': TextEditingController(),
    'length': TextEditingController(),
    'width': TextEditingController(),
    'height': TextEditingController(),
    'origin': TextEditingController(),
    'hsn': TextEditingController(),
    'vendor': TextEditingController(),
    'purchasePrice': TextEditingController(),
    'rsp': TextEditingController(),
  };

  List<String> uploadedImages = [];
  List<String> imageUrls = [];
  final int maxImages = 12;
  final ImagePicker _picker = ImagePicker();
  Future<void> pickAndUploadImage() async {
    try {
      setState(() {
        isImageLoading = true;
      });

      // Pick multiple images
      final List<XFile>? pickedFiles = await _picker.pickMultiImage();

      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        for (final file in pickedFiles) {
          if (imageUrls.length >= maxImages) break; // Limit to maxImages
          final Uint8List bytes = await file.readAsBytes();

          final fileName = const Uuid().v4(); // Unique name
          final storageRef =
          FirebaseStorage.instance.ref().child("uploads/$fileName.jpg");

          final uploadTask = await storageRef.putData(bytes);
          final downloadUrl = await uploadTask.ref.getDownloadURL();

          imageUrls.add(downloadUrl);
        }

        setState(() {
          isImageLoading = false;
        });
      } else {
        setState(() {
          isImageLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error picking/uploading images: $e");
      setState(() {
        isImageLoading = false;
      });
    }
  }


  void removeImage(int index) {
    setState(() {
      imageUrls.removeAt(index);
    });
  }

  void submitProduct() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all mandatory fields")),
      );
      return;
    }

    if (imageUrls.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("At least 2 images are required.")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    Map<String, dynamic> data = {
      'Brand': controllers['brand']!.text,
      'Product Title': controllers['title']!.text,
      'Barcode': controllers['barcode']!.text,
      'ASIN': controllers['asin']!.text,
      'NIN': controllers['nin']!.text,
      'Description': controllers['description']!.text,
      'Category': controllers['category']!.text,
      'Sub Category': controllers['subcategory']!.text,
      'Feature 1': controllers['feature1']!.text,
      'Feature 2':controllers['feature2']!.text,
      'Feature 3': controllers['feature3']!.text,
      'Feature 4': controllers['feature4']!.text,
      'Image 1': imageUrls.length > 0 ? imageUrls[0] : "",
      'Image 2': imageUrls.length > 1 ? imageUrls[1] : "",
      'Image 3': imageUrls.length > 2 ? imageUrls[2] : "",
      'Image 4': imageUrls.length > 3 ? imageUrls[3] : "",
      'Image 5': imageUrls.length > 4 ? imageUrls[4] : "",
      'Image 6': imageUrls.length > 5 ? imageUrls[5] : "",
      'Image 7': imageUrls.length > 6 ? imageUrls[6] : "",
      'Image 8': imageUrls.length > 7 ? imageUrls[7] : "",
      'Image 9': imageUrls.length > 8 ? imageUrls[8] : "",
      'Image 10': imageUrls.length > 9 ? imageUrls[9] : "",
      'Image 11': imageUrls.length > 10 ? imageUrls[10] : "",
      'Image 12': imageUrls.length > 11 ? imageUrls[11] : "",
      'Weight KG': controllers['weight']!.text,
      'Length CM': controllers['length']!.text,
      'Width CM': controllers['width']!.text,
      'Height CM': controllers['height']!.text,
      'Country of Origin': controllers['origin']!.text,
      'HSN Code': controllers['hsn']!.text,
      'Vendor ': controllers['vendor']!.text,
      'Purchase Price': double.tryParse(controllers['purchasePrice']!.text),
      'RSP': double.tryParse(controllers['rsp']!.text),
    };

    await FirebaseFirestore.instance.collection('products').add(data);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Product added successfully")),
    );
    Navigator.pop(context);
    setState(() {
      isLoading = false;
    });
  }

  Widget buildTextField(String label, String key,
      {bool required = false, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120, // fixed width for label
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controllers[key],
              keyboardType: keyboardType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true, // reduces height a bit
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              validator: (value) {
                if (required && (value == null || value.trim().isEmpty)) {
                  return '$label is required';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text("Add Product", style: TextStyle(color: Colors.white),)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left labels
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildTextField("Brand", "brand", required: true),
                    buildTextField("Product Title", "title", required: true),
                    buildTextField("Barcode", "barcode", required: true),
                    buildTextField("ASIN", "asin"),
                    buildTextField("NIN", "nin"),
                    buildTextField("Description", "description", required: true),
                    CategoryDropdown(controller: controllers['category']!),
                    const SizedBox(height: 16),
                    SubCategoryDropDown(controller: controllers['subcategory']!),
                    buildTextField("Feature 1", "feature1", required: true),
                    buildTextField("Feature 2", "feature2", required: true),
                    buildTextField("Feature 3", "feature3", required: true),
                    buildTextField("Feature 4", "feature4", required: true),
                    buildTextField("Country of Origin", "origin"),
                    buildTextField("HSN Code", "hsn"),
                    buildTextField("Vendor", "vendor", required: true),
                    buildTextField("Purchase Price", "purchasePrice", required: true, keyboardType: TextInputType.number),
                    buildTextField("RSP", "rsp", required: true, keyboardType: TextInputType.number),
                  ],
                ),
              ),

              const SizedBox(width: 40),

              // Right inputs
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildTextField("Weight (KG)", "weight", keyboardType: TextInputType.number),
                    buildTextField("Length (CM)", "length", keyboardType: TextInputType.number),
                    buildTextField("Width (CM)", "width", keyboardType: TextInputType.number),
                    buildTextField("Height (CM)", "height", keyboardType: TextInputType.number),

                    const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    children: [
                      ...imageUrls.map((url) {
                        return Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Image.network(
                                url,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    imageUrls.remove(url);
                                  });
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),

                      if (imageUrls.length < maxImages)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: pickAndUploadImage,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                              child: isImageLoading?
                                  const CircularProgressIndicator()
                                  :const Center(child: Icon(Icons.add_a_photo)),
                            ),
                          ),
                        )
                    ],
                  ),
                    const SizedBox(height: 8),
                    Text("Uploaded Images: ${imageUrls.length}"),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: submitProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      child: isLoading?
                          const Center(child: CircularProgressIndicator(color: Colors.white,),)
                          :const Text("Submit Product", style: TextStyle(color: Colors.white),),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
