import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubCategoryDropDown extends StatefulWidget {
  final TextEditingController controller;

  const SubCategoryDropDown({super.key, required this.controller});

  @override
  State<SubCategoryDropDown> createState() => _SubCategoryDropDownState();
}

class _SubCategoryDropDownState extends State<SubCategoryDropDown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? overlayEntry;
  List<String> allCategories = [];
  List<String> filteredCategories = [];
  bool showAddButton = false;

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    final snapshot = await FirebaseFirestore.instance.collection('sub_categories').get();
    setState(() {
      allCategories = snapshot.docs.map((doc) => doc['name'].toString()).toList();
    });
  }

  void showOverlay() {
    hideOverlay(); // remove existing overlay if any

    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? const Size(300, 200);

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0.0, 48.0),
          child: Material(
            elevation: 4.0,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filteredCategories.length,
              itemBuilder: (context, index) {
                final item = filteredCategories[index];
                return ListTile(
                  title: Text(item),
                  onTap: () {
                    widget.controller.text = item;
                    hideOverlay();
                    FocusScope.of(context).unfocus();
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(overlayEntry!);
  }

  void hideOverlay() {
    overlayEntry?.remove();
    overlayEntry = null;
  }

  void onTextChanged(String value) {
    final query = value.trim().toLowerCase();
    if (query.length >= 3) {
      filteredCategories = allCategories
          .where((cat) => cat.toLowerCase().contains(query))
          .toList();

      showAddButton = !allCategories.any((cat) => cat.toLowerCase() == query);

      if (filteredCategories.isNotEmpty) {
        showOverlay();
      } else {
        hideOverlay();
      }
    } else {
      filteredCategories = [];
      showAddButton = false;
      hideOverlay();
    }

    setState(() {});
  }

  Future<void> addCategory(String name) async {
    final categoryName = name.trim();
    if (categoryName.isEmpty || allCategories.contains(categoryName)) return;

    await FirebaseFirestore.instance.collection('sub_categories').add({'name': categoryName});
    setState(() {
      allCategories.add(categoryName);
      widget.controller.text = categoryName;
      showAddButton = false;
      hideOverlay();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sub Category "$categoryName" added.')));
  }

  @override
  void dispose() {
    hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        decoration: InputDecoration(
          labelText: 'Sub Category',
          border: const OutlineInputBorder(),
          suffixIcon: showAddButton
              ? IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => addCategory(widget.controller.text),
          )
              : null,
        ),
        onChanged: onTextChanged,
        validator: (value) => value == null || value.trim().isEmpty ? 'Sub Category is required' : null,
      ),
    );
  }
}