import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class ImageUploadWidget extends StatefulWidget {
  final Function(List<String>)? onImagesUploaded;

  ImageUploadWidget({super.key, this.onImagesUploaded});

  @override
  State<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  List<String> imageUrls = [];
  final int maxImages = 5;
  final ImagePicker _picker = ImagePicker();

  Future<void> pickAndUploadImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final Uint8List bytes = await pickedFile.readAsBytes();

        final fileName = const Uuid().v4(); // Unique file name
        final storageRef = FirebaseStorage.instance.ref().child("uploads/$fileName.jpg");

        final uploadTask = await storageRef.putData(bytes);
        final downloadUrl = await uploadTask.ref.getDownloadURL();

        setState(() {
          imageUrls.add(downloadUrl);
        });

        debugPrint("Uploaded image URL: $downloadUrl");
      }
    } catch (e) {
      debugPrint("Error picking/uploading image: $e");
    }
  }

  void removeImage(int index) {
    setState(() {
      imageUrls.removeAt(index);
    });
    widget.onImagesUploaded?.call(imageUrls);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      children: [
        ...imageUrls.map((url) => Image.network(url, width: 100, height: 100)),
        if (imageUrls.length < maxImages)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: pickAndUploadImage,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                child: const Center(child: Icon(Icons.add_a_photo)),
              ),
            ),
          )
      ],
    );
  }
}