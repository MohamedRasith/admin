import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import 'package:excel/excel.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:vendor/Pages/add_orders.dart';
import 'package:vendor/Pages/add_products.dart';
import 'package:vendor/Pages/edit_products.dart';
import 'package:vendor/Pages/margin_page.dart';
import 'package:vendor/Pages/orders_page.dart';
import 'package:vendor/Pages/vendor_signup_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedIndex = 0;

  bool get hasActiveFilters =>
      selectedBrands.isNotEmpty || selectedVendors.isNotEmpty;

  TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  List<String> selectedVendors = [];
  List<String> selectedBrands = [];
  List<String> selectedProducts = [];
  List<QueryDocumentSnapshot> filterProducts = [];
  bool showFilter = false;
  int vendorCount = 0;
  int productCount = 0;

  final List<String> titles = ['Home', 'Orders', 'Products', 'Vendor', 'Amazon Margin'];
  final List<IconData> icons = [
    Icons.home,
    Icons.shopping_cart,
    Icons.inventory,
    Icons.store,
    Icons.margin
  ];

  String getVendorName(QueryDocumentSnapshot product) {
    final data = product.data() as Map<String, dynamic>;

    if (data.containsKey('Vendor') && data['Vendor'] != null) {
      return data['Vendor'].toString();
    } else if (data.containsKey('Vendor ') && data['Vendor '] != null) {
      return data['Vendor '].toString();
    } else {
      return 'No Vendor';
    }
  }

  bool isLoading = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    fetchCounts();
  }
  Future<void> fetchCounts() async {
    final vendorsSnapshot = await FirebaseFirestore.instance.collection('vendors').get();
    final productsSnapshot = await FirebaseFirestore.instance.collection('products').get();

    setState(() {
      vendorCount = vendorsSnapshot.size;
      productCount = productsSnapshot.size;
    });
  }

  Future<void> pickAndUploadExcel() async {
    setState(() => isLoading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null || result.files.single.bytes == null) {
        setState(() => isLoading = false);
        return;
      }

      final bytes = result.files.single.bytes!;
      Excel excel;

      try {
        excel = Excel.decodeBytes(bytes);
      } catch (e) {
        print('❌ Failed to decode Excel: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid Excel file.')),
        );
        setState(() => isLoading = false);
        return;
      }

      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null || sheet.rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel sheet is empty or not found.')),
        );
        setState(() => isLoading = false);
        return;
      }

      // Extract headers
      final header = sheet.rows[0]
          .map((cell) => (cell != null && cell.value != null) ? cell.value.toString() : '')
          .toList();

      List<Map<String, dynamic>> products = [];

      // Extract each row
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row == null) continue;

        Map<String, dynamic> product = {};
        for (int j = 0; j < header.length; j++) {
          final key = header[j];
          final cell = j < row.length ? row[j] : null;
          final value = cell?.value;

          product[key] = (value is String || value is num || value is bool || value == null)
              ? value
              : value.toString(); // fallback
        }

        products.add(product);
      }

      final collection = FirebaseFirestore.instance.collection('products');

      for (var product in products) {
        final command = (product['Command']?.toString().trim() ?? 'New').toLowerCase();

        try {
          if (command == 'new') {
            await collection.add(product);
          } else if (command == 'update') {
            final asin = product['ASIN']?.toString();
            if (asin != null && asin.isNotEmpty) {
              final query = await collection.where('ASIN', isEqualTo: asin).get();
              for (var doc in query.docs) {
                await doc.reference.update(product);
              }
            } else {
              print('❌ Missing ASIN for update');
            }
          } else if (command == 'delete') {
            final docId = product['ID']?.toString().trim();
            if (docId != null && docId.isNotEmpty) {
              await collection.doc(docId).delete();
              print('✅ Deleted document with ID: $docId');
            } else {
              print('❌ Missing or invalid document ID for delete');
            }
          }
        } catch (e) {
          print('❌ Error processing $command: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully processed ${products.length} products')),
      );
    } catch (e) {
      print('❌ Unexpected error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unexpected error occurred.')),
      );
    }

    setState(() => isLoading = false);
  }

  String _wrapBrandText(String text, [int chunkSize = 40]) {
    if (text.length <= chunkSize) return text;

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i += chunkSize) {
      final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      buffer.writeln(text.substring(i, end));
    }
    return buffer.toString().trim();
  }

  void exportFilteredProductsToExcelWeb(List<QueryDocumentSnapshot> filteredProducts) {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Products';

    // Header row
    final headers = [
      'ID',
      'Brand',
      'Product Title',
      'Barcode',
      'ASIN',
      'NIN',
      'Description',
      'Category',
      'Sub Category',
      'Feature 1',
      'Feature 2',
      'Feature 3',
      'Feature 4',
      'Image 1',
      'Image 2',
      'Image 3',
      'Image 4',
      'Image 5',
      'Weight KG',
      'Length CM',
      'Width CM',
      'Height CM',
      'Country of Origin',
      'HSN Code',
      'Vendor',
      'Purchase Price',
      'RSP',
      'Command', // this will have dropdown
    ];

    for (int i = 0; i < headers.length; i++) {
      sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
    }

    // Product rows
    for (int i = 0; i < filteredProducts.length; i++) {
      final product = filteredProducts[i];
      final rowIndex = i + 2;

      final values = [
        product.id.toString() ?? "",
        product['Brand']?.toString() ?? '',
        product['Product Title']?.toString() ?? '',
        product['Barcode']?.toString() ?? '',
        product['ASIN']?.toString() ?? '',
        product['NIN']?.toString() ?? '',
        product['Description']?.toString() ?? '',
        product['Category']?.toString() ?? '',
        product['Sub Category']?.toString() ?? '',
        product['Feature 1']?.toString() ?? '',
        product['Feature 2']?.toString() ?? '',
        product['Feature 3']?.toString() ?? '',
        product['Feature 4']?.toString() ?? '',
        product['Image 1']?.toString() ?? '',
        product['Image 2']?.toString() ?? '',
        product['Image 3']?.toString() ?? '',
        product['Image 4']?.toString() ?? '',
        product['Image 5']?.toString() ?? '',
        product['Weight KG']?.toString() ?? '',
        product['Length CM']?.toString() ?? '',
        product['Width CM']?.toString() ?? '',
        product['Height CM']?.toString() ?? '',
        product['Country of Origin']?.toString() ?? '',
        product['HSN Code']?.toString() ?? '',
        getVendorName(product),
        product['Purchase Price']?.toString() ?? '',
        product['RSP']?.toString() ?? '',
        'New', // Default value for dropdown
      ];

      for (int j = 0; j < values.length; j++) {
        sheet.getRangeByIndex(rowIndex, j + 1).setText(values[j]);
      }
    }

    // ✅ Apply dropdown (data validation) to "Command" column
    final commandColumn = headers.indexOf('Command') + 1;
    final range = sheet.getRangeByName('AB2:AB${filteredProducts.length + 1}');
    final dropdown = range.dataValidation;
    dropdown.listOfValues = ['New', 'Update', 'Delete'];

    // Save and trigger download (web)
    final bytes = workbook.saveAsStream();
    if (!kIsWeb) {
      workbook.dispose(); // Safe to dispose on mobile or desktop
    }

    final blob = html.Blob([Uint8List.fromList(bytes)], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'products_export.xlsx')
      ..click();
    html.Url.revokeObjectUrl(url);
  }


  Widget getOrdersPageContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('Error: \${snapshot.error}'));
        }

        final orders = snapshot.data?.docs ?? [];

        if (orders.isEmpty) {
          return Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddOrderPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              child: const Text("Add Orders"),
            ),
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AddOrderPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      child: const Text("Add Orders"),
                    ),
                  ),
                  Center(
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton.icon(
                            onPressed: pickAndUploadExcel,
                            // Implement excel import logic
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Import Excel File'),
                          ),
                  ),
                ],
              ),
              Expanded(
                child: OrdersPage()
              )
            ],
          );
        }
      },
    );
  }

  Widget getProductsPageContent() {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AddProductPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  child: const Text("Add Products"),
                ),
              ),
              Center(
                child: isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        onPressed: pickAndUploadExcel,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Import Excel File'),
                      ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  if (filterProducts.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No products to export.')),
                    );
                  } else {
                    exportFilteredProductsToExcelWeb(filterProducts);
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text("Export Excel"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Search Products (min 3 chars)',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery =
                          value.length >= 3 ? value.toLowerCase() : '';
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
            ])),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('products').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final products = snapshot.data?.docs ?? [];

              if (products.isEmpty) {
                // No products: Show button centered
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AddProductPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    child: const Text("Add Products"),
                  ),
                );
              } else {
                // Products exist: show button on top + list below
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                                color: Colors.grey.shade300, width: 1),
                          ),
                          elevation: 4,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final filteredProducts =
                                  products.where((product) {
                                final brand = (product['Brand'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final productTitle = (product['Product Title'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final asin = (product['ASIN'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final barcode = (product['Barcode'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final vendor =
                                    getVendorName(product);

                                final matchesSearch = searchQuery.isEmpty ||
                                    productTitle.contains(searchQuery.toLowerCase()) ||
                                    brand.contains(searchQuery.toLowerCase()) ||
                                    asin.contains(searchQuery.toLowerCase()) ||
                                    barcode
                                        .contains(searchQuery.toLowerCase()) ||
                                    vendor.contains(searchQuery.toLowerCase());

                                final matchesBrandFilter = selectedBrands
                                        .isEmpty ||
                                    selectedBrands.contains(product['Brand']);
                                final matchesVendorFilter =
                                    selectedVendors.isEmpty ||
                                        selectedVendors.contains(vendor);

                                return matchesSearch &&
                                    matchesBrandFilter &&
                                    matchesVendorFilter;
                              }).toList();
                              filterProducts = filteredProducts;
                              return filteredProducts.isEmpty
                                  ? const Center(
                                      child: Text("No Products Found"),
                                    )
                                  : SingleChildScrollView(
                                      child: IntrinsicWidth(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                              minWidth: constraints.maxWidth),
                                          child: DataTable(
                                            columnSpacing: 20,
                                            dataRowMinHeight: 50,
                                            dataRowMaxHeight: 100,
                                            columns: const [
                                              DataColumn(
                                                  label: Text('Product Name')),
                                              DataColumn(label: Text('ASIN')),
                                              DataColumn(
                                                  label: Text('Barcode')),
                                              DataColumn(
                                                  label: Text('Cost(exc.VAT)')),
                                              DataColumn(
                                                  label: Text('RSP(exc.VAT)')),
                                              DataColumn(
                                                label: Text("VAT(5%)")
                                              ),
                                              DataColumn(
                                                  label: Text('Vendor Name')),
                                            ],
                                            rows:
                                                filteredProducts.map((product) {
                                                  final imageCount = List.generate(5, (i) {
                                                    final key = 'Image ${i + 1}';
                                                    final value = product[key];
                                                    return value != null && value is String && value.isNotEmpty;
                                                  }).where((isValid) => isValid).length;
                                              return DataRow(cells: [
                                                DataCell(Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Stack(
                                                      alignment: Alignment.topRight,
                                                      children: [
                                                        ClipRRect(
                                                          borderRadius: BorderRadius.circular(8),
                                                          child: product['Image 1'] != null && product['Image 1'] is String && product['Image 1'].isNotEmpty
                                                              ? Image.network(
                                                            product['Image 1'],
                                                            width: 50,
                                                            height: 50,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (context, error, stackTrace) {
                                                              return Container(
                                                                width: 50,
                                                                height: 50,
                                                                color: Colors.grey[200],
                                                                alignment: Alignment.center,
                                                                child: const Icon(Icons.broken_image, size: 24),
                                                              );
                                                            },
                                                          )
                                                              : Container(
                                                            width: 50,
                                                            height: 50,
                                                            color: Colors.grey[200],
                                                            alignment: Alignment.center,
                                                            child: const Icon(Icons.image_not_supported, size: 24),
                                                          ),
                                                        ),
                                                        // Badge
                                                        Positioned(
                                                          top: 2,
                                                          right: 2,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: Colors.red,
                                                              borderRadius: BorderRadius.circular(10),
                                                            ),
                                                            child: Text(
                                                              imageCount > 0 ? '$imageCount' : '0',
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: MouseRegion(
                                                        cursor: SystemMouseCursors.click,
                                                        child: Row(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            // Brand Text (Navigates to EditProductPage)
                                                            Expanded(
                                                              child: GestureDetector(
                                                                onTap: () {
                                                                  Navigator.push(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                      builder: (_) => EditProductPage(product: product),
                                                                    ),
                                                                  );
                                                                },
                                                                child: Text(
                                                                  _wrapBrandText(product['Product Title'] ?? 'No Name'),
                                                                  maxLines: 5,
                                                                  softWrap: true,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: const TextStyle(
                                                                    color: Colors.blue,
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),

                                                            const SizedBox(width: 4),

                                                            // Copy Icon with Tooltip
                                                            Tooltip(
                                                              message: 'Copy Product Title',
                                                              child: InkWell(
                                                                onTap: () {
                                                                  Clipboard.setData(
                                                                    ClipboardData(text: product['Product Title'] ?? ''),
                                                                  );
                                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                                    const SnackBar(content: Text('Product Title copied')),
                                                                  );
                                                                },
                                                                child: const Icon(Icons.copy, size: 16, color: Colors.grey),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                )),
                                                DataCell(Tooltip(
                                                  message: 'Click to copy ASIN',
                                                  child: InkWell(
                                                    onTap: () {
                                                      Clipboard.setData(ClipboardData(text: product['ASIN'] ?? ''));
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text('ASIN copied')),
                                                      );
                                                    },
                                                    child: Text(product['ASIN'] ?? ''),
                                                  ),
                                                ),),
                                                DataCell(Tooltip(
                                                  message: 'Click to copy Barcode',
                                                  child: InkWell(
                                                    onTap: () {
                                                      Clipboard.setData(ClipboardData(text: product['Barcode'] ?? ''));
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text('Barcode copied')),
                                                      );
                                                    },
                                                    child: Text(product['Barcode'] ?? ''),
                                                  ),
                                                ),),
                                                DataCell(
                                                  Tooltip(
                                                    message: 'Click to copy Purchase Price',
                                                    child: InkWell(
                                                      onTap: () {
                                                        Clipboard.setData(
                                                          ClipboardData(text: 'AED ${product['Purchase Price'] ?? '0.00'}'),
                                                        );
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Purchase Price copied')),
                                                        );
                                                      },
                                                      child: Text('AED ${product['Purchase Price'] ?? '0.00'}'),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Tooltip(
                                                    message: 'Click to copy RSP',
                                                    child: InkWell(
                                                      onTap: () {
                                                        Clipboard.setData(
                                                          ClipboardData(text: 'AED ${product['RSP'] ?? '0.00'}'),
                                                        );
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('RSP copied')),
                                                        );
                                                      },
                                                      child: Text('AED ${product['RSP'] ?? '0.00'}'),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Builder(
                                                    builder: (context) {
                                                      final rawRSP = product['RSP'];
                                                      final rsp = double.tryParse(rawRSP?.toString() ?? '0') ?? 0.0;
                                                      final vat = rsp * 0.05;
                                                      return Text('AED ${vat.toStringAsFixed(2)}');
                                                    },
                                                  ),
                                                ),
                                                DataCell(
                                                  Tooltip(
                                                    message: 'Click to copy Vendor',
                                                    child: InkWell(
                                                      onTap: () {
                                                        final vendorName = getVendorName(product);
                                                        Clipboard.setData(ClipboardData(text: vendorName));
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Vendor copied')),
                                                        );
                                                      },
                                                      child: Text(getVendorName(product)),
                                                    ),
                                                  ),
                                                ),
                                              ]);
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    );
                            },
                          ),
                        ),
                      ),
                    )
                  ],
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget getSelectedPageContent() {
    switch (selectedIndex) {
      case 0:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text("Total Products: $productCount", style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 10),
                      Text("Total Vendors: $vendorCount", style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      case 1:
        return getOrdersPageContent();
      case 2:
        return getProductsPageContent();
      case 3:
        return VendorSignupPage();
      case 4:
        return AmazonMarginPage();
      default:
        return const Center(child: Text("Unknown Page"));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              backgroundColor: Colors.blueGrey[900],
              title: Text(titles[selectedIndex],
                  style: const TextStyle(color: Colors.white)),
              iconTheme: const IconThemeData(color: Colors.white),
            )
          : null,
      drawer: isMobile
          ? Drawer(
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  ...List.generate(titles.length, (index) {
                    return ListTile(
                      leading: Icon(
                        icons[index],
                        color:
                            selectedIndex == index ? Colors.black : Colors.grey,
                      ),
                      title: Text(
                        titles[index],
                        style: TextStyle(
                          fontWeight: selectedIndex == index
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          selectedIndex = index;
                        });
                        Navigator.pop(context); // Close drawer
                      },
                    );
                  }),
                ],
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            Container(
              width: 200,
              color: Colors.black,
              child: Column(
                children: [
                  const SizedBox(
                    height: 10,
                  ),
                  SvgPicture.asset(
                    'assets/images/buybill_black.svg',
                    width: 80,
                    height: 80,
                  ),
                  const SizedBox(height: 50),
                  ...List.generate(titles.length, (index) {
                    return ListTile(
                      leading: Icon(
                        icons[index],
                        color:
                            selectedIndex == index ? Colors.white : Colors.grey,
                      ),
                      title: Text(
                        titles[index],
                        style: TextStyle(
                          color: selectedIndex == index
                              ? Colors.white
                              : Colors.grey,
                          fontWeight: selectedIndex == index
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: selectedIndex == index,
                      selectedTileColor: Colors.blueGrey[700],
                      onTap: () {
                        setState(() {
                          selectedIndex = index;
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
          Expanded(
            child: Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(16),
              child: getSelectedPageContent(),
            ),
          ),
        ],
      ),
    );
  }
}
