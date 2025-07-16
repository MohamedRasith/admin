import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:universal_html/html.dart' as html;

class OrderDetailsPage extends StatefulWidget {
  final QueryDocumentSnapshot order;

  const OrderDetailsPage({super.key, required this.order});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  List<dynamic> products = [];
  late List<TextEditingController> boxCountControllers;
  late List<TextEditingController> titleControllers;
  OverlayEntry? _overlayEntry;
  Map<int, LayerLink> _layerLinks = {};
  int? _activeIndex; // to know which field is focused
  List<String> allProductTitles = [];
  PlatformFile? appointmentFile;
  PlatformFile? bnbInvoiceFile;

  void openPdfInNewTab(String url) {
    html.window.open(url, '_blank');
  }


  @override
  void initState() {
    super.initState();

    products = widget.order['products'] ?? [];

    for (int i = 0; i < products.length; i++) {
      _layerLinks[i] = LayerLink();
    }


    boxCountControllers = List.generate(
      products.length,
          (index) => TextEditingController(
        text: products[index]['boxCount']?.toString() ?? '',
      ),
    );

    titleControllers = List.generate(
      products.length,
          (index) => TextEditingController(
        text: products[index]['title'] ?? '',
      ),
    );

    fetchProductTitles().then((titles) {
      setState(() {
        allProductTitles = titles;
      });
    });
  }

  Future<void> uploadToAmazon() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result == null || result.files.isEmpty) {
      // User canceled or no file selected
      return;
    }

    final file = result.files.first;
    final fileBytes = file.bytes;
    final fileName = file.name;

    if (fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to read file.")),
      );
      return;
    }

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('upload_to_amazon_files/${widget.order.id}/$fileName');

      // Upload file bytes
      final uploadTask = await storageRef.putData(fileBytes);

      // Get download URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Save download URL to Firestore order document
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id)
          .update({'uploadToAmazon': downloadUrl, 'status': 'Completed'});

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("File uploaded and link saved successfully.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    }
  }


  Future<void> generatePdf(var products, var order) async {
    final pdf = pw.Document();

    final logoBytes = await rootBundle.load('assets/images/buybill.png').then((value) => value.buffer.asUint8List());
    final logoImage = pw.MemoryImage(logoBytes);

    final tableHeaders = ['', 'Product', 'Cost', 'Quantity\nRequested', 'Quantity\nConfirmed', 'Total'];

    final todayDate = DateFormat('dd MMM, yyyy').format(DateTime.now());

    final double subtotal = products.fold(0.0, (sum, item) {
      final value = item['total'];
      if (value is num) return sum + value;
      if (value is String) return sum + double.tryParse(value) ?? 0.0;
      return sum;
    });

    final double vat = subtotal * 0.05;
    final double grandTotal = subtotal + vat;


    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Center(
            child:pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Logo on the left
                pw.Container(
                  height: 100,
                  width: 150,
                  child: pw.Image(
                      logoImage
                  ),
                ),

                // Title on the right
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'BUY AND BILL LLC',
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'PURCHASE ORDER',
                      style: pw.TextStyle(fontSize: 18),
                    ),
                    pw.SizedBox(height: 10),
                    pw.BarcodeWidget(
                      data: widget.order['amazonPONumber'] ?? '',
                      barcode: pw.Barcode.code128(), // Code128 supports alphanumeric
                      width: 200,
                      height: 60,
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('${widget.order['vendor'] ?? 'Not set'},'),
                  pw.Text('Buy and bill LLC,'),
                  pw.Text('Sharjah Media City,'),
                  pw.Text('Sharjah UAE.'),
                  pw.Text('+971 52 603 3484'),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('DATE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(todayDate),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey), // Header border
            children: [
              pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.black),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('P/O NUMBER', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Deliver To', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('TERMS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    ),
                  ]),
              pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(widget.order['amazonPONumber'] ?? ''),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(widget.order['location'] ?? 'Not set'),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('NET 60 Days'),
                ),
              ]),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(30), // Serial No. column
              1: const pw.FixedColumnWidth(180), // Product column
              2: const pw.FixedColumnWidth(50),  // Cost column
              3: const pw.FixedColumnWidth(100),  // Quantity Requested column
              4: const pw.FixedColumnWidth(100),  // Quantity Confirmed column
              5: const pw.FixedColumnWidth(80),  // Total column
            },
            border: pw.TableBorder.all(color: PdfColors.grey), // Body border
            children: [
              // Header row with black background and white borders
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.black),
                children: tableHeaders.map((header) {
                  return pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        left: pw.BorderSide(color: PdfColors.white, width: 1),
                        right: pw.BorderSide(color: PdfColors.white, width: 1),
                      ),
                    ),
                    child: pw.Text(
                      header,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Data rows
              ...products.asMap().entries.map((entry) {
                final index = entry.key;     // Serial number = index + 1
                final p = entry.value;

                final title = p['title'] as String;
                final truncatedTitle = title.length > 20 ? '${title.substring(0, 20)}...' : title;

                final description = '$truncatedTitle\nBARCODE: ${p['barcode']}\nASIN: ${p['asin']}';


                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text((index + 1).toString()),  // S. No.
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(description),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(p['unitCost'].toString()),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(p['requested'].toString()),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(p['confirmed'].toString()),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(p['total'].round().toString()),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),

          pw.SizedBox(height: 30),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 200,
              child: pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Subtotal'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('AED ${subtotal.round()}'),
                    ),
                  ]),
                  pw.TableRow(children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('VAT 5%'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('AED ${vat.round()}'),
                    ),
                  ]),
                  pw.TableRow(children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('AED ${grandTotal.round()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'purchase_order.pdf');
  }

  Future<void> pickFile(String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;

      final storageRef = FirebaseStorage.instance.ref().child(
        'order_uploads/${widget.order.id}/${type}_${DateTime.now().millisecondsSinceEpoch}.${file.extension}',
      );

      try {
        final uploadTask = await storageRef.putData(file.bytes!);
        final downloadUrl = await uploadTask.ref.getDownloadURL();

        await widget.order.reference.update({
          if (type == 'appointment') 'appointmentFileUrl': downloadUrl, 'status': 'Appointment Confirmed',
          if (type == 'bnb') 'bnbInvoiceUrl': downloadUrl,
        });

        setState(() {
          if (type == 'appointment') {
            appointmentFile = file;
          } else if (type == 'bnb') {
            bnbInvoiceFile = file;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$type file uploaded successfully')),
        );
      } catch (e) {
        print("Upload error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload file')),
        );
      }
    }
  }


  void saveSingleProduct(int index) async {
    final updatedProduct = Map<String, dynamic>.from(products[index]);

    if (updatedProduct['confirmed'] == null) {
      updatedProduct['boxCount'] = int.tryParse(boxCountControllers[index].text) ?? 0;
      updatedProduct['title'] = titleControllers[index].text.trim();

      products[index] = updatedProduct;

      await widget.order.reference.update({'products': products});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Product ${index + 1} updated")),
      );

      setState(() {});
    }
  }

  Future<void> exportOrderToExcel(List products, var order) async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Purchase Order';

    final today = DateTime.now();
    final dateStr = '${today.day}/${today.month}/${today.year}';

    // Title
    sheet.getRangeByName('A1').setText('BUY AND BILL LLC');
    sheet.getRangeByName('A2').setText('PURCHASE ORDER');
    sheet.getRangeByName('F1').setText('Date');
    sheet.getRangeByName('G1').setText(dateStr);
    sheet.getRangeByName('A4').setText('Vendor: ${order['vendor'] ?? 'Not set'}');
    sheet.getRangeByName('F4').setText('P/O No: ${order['amazonPONumber'] ?? ''}');
    sheet.getRangeByName('F5').setText('Location: ${order['location'] ?? 'Not set'}');
    sheet.getRangeByName('F6').setText('Terms: NET 60 Days');

    // Table Header
    final headers = ['S.No', 'Product', 'Cost', 'Qty Requested', 'Qty Confirmed', 'Total'];
    for (int i = 0; i < headers.length; i++) {
      sheet.getRangeByIndex(8, i + 1).setText(headers[i]);
      sheet.getRangeByIndex(8, i + 1).cellStyle.bold = true;
    }

    // Table Rows
    double subtotal = 0.0;
    for (int i = 0; i < products.length; i++) {
      final p = products[i];
      final title = p['title'] ?? '';
      final barcode = p['barcode'] ?? '';
      final asin = p['asin'] ?? '';
      final unitCost = p['unitCost']?.toString() ?? '0';
      final requested = p['requested']?.toString() ?? '0';
      final confirmed = p['confirmed']?.toString() ?? '0';
      final total = (p['total'] is String)
          ? double.tryParse(p['total']) ?? 0
          : (p['total'] is num)
          ? p['total'].toDouble()
          : 0.0;

      final desc = '${title.length > 20 ? title.substring(0, 20) + '...' : title}\nBARCODE: $barcode\nASIN: $asin';

      subtotal += total;

      sheet.getRangeByIndex(i + 9, 1).setNumber(i + 1);
      sheet.getRangeByIndex(i + 9, 2).setText(desc);
      sheet.getRangeByIndex(i + 9, 3).setText(unitCost);
      sheet.getRangeByIndex(i + 9, 4).setText(requested);
      sheet.getRangeByIndex(i + 9, 5).setText(confirmed);
      sheet.getRangeByIndex(i + 9, 6).setNumber(total);
    }

    // Totals
    final vat = subtotal * 0.05;
    final grandTotal = subtotal + vat;

    final totalStartRow = products.length + 10;
    sheet.getRangeByIndex(totalStartRow, 5).setText('Subtotal');
    sheet.getRangeByIndex(totalStartRow, 6).setNumber(subtotal);

    sheet.getRangeByIndex(totalStartRow + 1, 5).setText('VAT 5%');
    sheet.getRangeByIndex(totalStartRow + 1, 6).setNumber(vat);

    sheet.getRangeByIndex(totalStartRow + 2, 5).setText('TOTAL');
    sheet.getRangeByIndex(totalStartRow + 2, 6).setNumber(grandTotal);
    sheet.getRangeByIndex(totalStartRow + 2, 5).cellStyle.bold = true;
    sheet.getRangeByIndex(totalStartRow + 2, 6).cellStyle.bold = true;

    // AutoFit columns
    sheet.autoFitColumn(100);

    final List<int> bytes = workbook.saveAsStream();

    final blob = html.Blob([Uint8List.fromList(bytes)], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "PurchaseOrder.xlsx")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void exportOrderProductsToPDFWeb(List<dynamic> products, var order) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text("Order Products", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: [
              'Title',
              'ASIN',
              'Barcode',
              'Requested Qty',
              'Confirmed Qty',
              'Unit Cost',
              'Total Cost',
              'Order ID',
              'Vendor',
            ],
            data: products.map((product) {
              return [
                product['title'] ?? '',
                product['asin'] ?? '',
                product['barcode'] ?? '',
                product['boxCount']?.toString() ?? '',
                product['confirmed']?.toString() ?? '0',
                product['unitCost']?.toString() ?? '',
                product['total']?.toString() ?? '',
                product['orderId']?.toString() ?? '',
                order['vendor'] ?? '',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignments: {
              0: pw.Alignment.topLeft, // wrap title
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(3), // Title - wider
              1: const pw.IntrinsicColumnWidth(), // ASIN
              2: const pw.IntrinsicColumnWidth(), // Barcode
              3: const pw.FixedColumnWidth(50), // Requested Qty
              4: const pw.FixedColumnWidth(50), // Confirmed Qty
              5: const pw.FixedColumnWidth(50), // Unit Cost
              6: const pw.FixedColumnWidth(50), // Total Cost
              7: const pw.FlexColumnWidth(2), // Order ID
              8: const pw.FlexColumnWidth(2), // Vendor
            },
          ),

        ],
      ),
    );

    final bytes = await pdf.save();

    // Trigger download in web
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'order_products.pdf')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<List<String>> fetchProductTitles() async {
    final snapshot = await FirebaseFirestore.instance.collection('products').get();

    final titles = snapshot.docs
        .map((doc) => doc['Product Title'])
        .where((title) => title != null && title.toString().trim().isNotEmpty)
        .map((title) => title.toString())
        .toList();

    return titles;
  }

  void _showOverlay(BuildContext context, int index, TextEditingController controller) {
    _hideOverlay();

    final suggestions = allProductTitles
        .where((title) => title.toLowerCase().contains(controller.text.toLowerCase()))
        .toList();

    if (suggestions.isEmpty) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: 16,
        right: 16,
        child: CompositedTransformFollower(
          link: _layerLinks[index] ?? LayerLink(),
          showWhenUnlinked: false,
          offset: const Offset(0, 48),
          child: Material(
            elevation: 4,
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: suggestions.map((title) {
                return ListTile(
                  title: Text(title),
                  onTap: () {
                    setState(() {
                      titleControllers[index].text = title;
                    });

                    _hideOverlay();
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }



  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }




  @override
  Widget build(BuildContext context) {
    final hasConfirmed = products.any((p) => p['confirmed'] != null);
    final appointmentDate = widget.order['appointmentDate'] != null
        ? DateFormat("dd MMM hh:mm a").format((widget.order['appointmentDate'] as Timestamp).toDate())
        : 'Not set';

    final createdDate = widget.order['createdAt'] != null
        ? DateFormat("dd MMM hh:mm a").format((widget.order['createdAt'] as Timestamp).toDate())
        : 'Not set';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Order Details", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text("PO: ${widget.order['amazonPONumber']}", style: const TextStyle(fontSize: 20),),
          ),
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Table(
                      border: TableBorder.all(color: Colors.grey), // <-- Add this line
                      columnWidths: const {
                        0: IntrinsicColumnWidth(),
                        1: IntrinsicColumnWidth(),
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text("ASN:", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(widget.order['asn'] ?? ''),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text("BNB PO Number:", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(widget.order['bnbPONumber'] ?? ''),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text("Appointment ID:", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(widget.order['appointmentId'] ?? ''),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text("Appointment Date:", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(appointmentDate),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text("Location:", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(widget.order['location'] ?? ''),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text("Order created on:", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(createdDate),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text("Vendor:", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(widget.order['vendor'] ?? ''),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 200,
                child: Column(
                  children: [
                    // Appointment File Box
                    GestureDetector(
                      onTap: () {
                        if (appointmentFile != null) {
                          pickFile('appointment');
                        } else if (widget.order['appointmentFileUrl'] != "") {
                          openPdfInNewTab(widget.order['appointmentFileUrl']);
                        } else {
                          pickFile('appointment');
                        }
                      },
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: appointmentFile != null
                              ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.insert_drive_file, size: 28, color: Colors.green),
                              const SizedBox(height: 4),
                              Text(appointmentFile!.name, overflow: TextOverflow.ellipsis),
                            ],
                          )
                              : widget.order['appointmentFileUrl'] != ""
                              ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.picture_as_pdf, size: 28, color: Colors.red),
                              SizedBox(height: 4),
                              Text("View PDF of Appointment Letter", style: TextStyle(fontSize: 12)),
                            ],
                          )
                              : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, size: 28, color: Colors.blue),
                              SizedBox(height: 4),
                              Text('Appointment Letter'),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),
                    // BNB Invoice Box
                    GestureDetector(
                      onTap: () {
                        if (bnbInvoiceFile != null) {
                          pickFile('bnb');
                        } else if (widget.order['bnbInvoiceUrl'] != "") {
                          html.window.open(widget.order['bnbInvoiceUrl'], '_blank');
                        } else {
                          pickFile('bnb');
                        }
                      },
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: bnbInvoiceFile != null
                              ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.insert_drive_file, size: 28, color: Colors.green),
                              const SizedBox(height: 4),
                              Text(
                                bnbInvoiceFile!.name,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                              : widget.order['bnbInvoiceUrl'] != ""
                              ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.picture_as_pdf, size: 28, color: Colors.red),
                              SizedBox(height: 4),
                              Text(
                                "View PDF of BNB Invoice",
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                              : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, size: 28, color: Colors.blue),
                              SizedBox(height: 4),
                              Text('BNB Invoice'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => exportOrderToExcel(products, widget.order.data()),
                  icon: const Icon(Icons.file_copy, color: Colors.white,),
                  label: const Text("Export Excel", style: TextStyle(color: Colors.white),),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => generatePdf(products, widget.order.data()),
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.white,),
                  label: const Text("Export PDF", style: TextStyle(color: Colors.white),),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                const SizedBox(width: 12),
                widget.order['uploadToAmazon'] != ""?
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: InkWell(
                    onTap: () async {
                      final url = widget.order['uploadToAmazon'];
                      html.window.open(url, '_blank');
                    },
                    child: const Text(
                      "View Proof of Delivery",
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                )
                    :ElevatedButton.icon(
                  onPressed: uploadToAmazon,
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  label: const Text("Upload to Amazon", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                border: TableBorder.all(color: Colors.grey),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: const {
                  0: FixedColumnWidth(80), // Image
                  1: FixedColumnWidth(200), // Title
                  2: IntrinsicColumnWidth(), // ASIN
                  3: IntrinsicColumnWidth(), // Barcode
                  4: IntrinsicColumnWidth(), // Qty/Box
                  5: IntrinsicColumnWidth(), // Order ID
                  6: IntrinsicColumnWidth(), // Vendor
                  7: IntrinsicColumnWidth(),
                },
                children: [
                  // Header row
                  const TableRow(
                    decoration: BoxDecoration(color: Color(0xFFE0E0E0)),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Title', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('ASIN', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Barcode', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Requested quantity', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Confirmed quantity', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Unit Cost', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Total Cost', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  // Data rows
                  for (final product in products)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.network(
                            product['imageUrl'],
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            product['title'] ?? '',
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(product['asin'] ?? ''),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(product['barcode'] ?? ''),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                             '${product['boxCount']}',
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text((product['confirmed'] ?? 0).toString()),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text((product['unitCost'] ?? 0.0).toStringAsFixed(2)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text((product['total'] ?? 0.0).toStringAsFixed(2)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          )

        ],
      ),
    );
  }

}
