import 'package:admin/Pages/chat_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CreateTicketWithVendor extends StatefulWidget {
  @override
  _CreateTicketWithVendorState createState() => _CreateTicketWithVendorState();
}

class _CreateTicketWithVendorState extends State<CreateTicketWithVendor> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String? selectedVendorId;
  String? selectedVendorName;

  List<Map<String, String>> vendorsList = [];
  bool showForm = false; // Add this at class level
  List<DocumentSnapshot> userTickets = [];
  String? editingTicketId;
  bool? loadingTickets;

  @override
  void initState() {
    super.initState();
    fetchVendors();
    fetchTickets();
  }

  Future<void> fetchVendors() async {
    final snapshot = await FirebaseFirestore.instance.collection('vendors').get();
    final List<Map<String, String>> temp = snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'name': doc['vendorName'].toString(),
      };
    }).toList();


    setState(() {
      vendorsList = temp;
    });
  }

  Future<void> fetchTickets() async {
    setState(() {
      loadingTickets = true;
    });
    final snapshot = await FirebaseFirestore.instance
        .collection('tickets')
        .orderBy('createdAt', descending: true)
        .get();

    setState(() {
      userTickets = snapshot.docs;
      loadingTickets = false;
    });
  }

  void populateTicketForEdit(DocumentSnapshot doc) {
    setState(() {
      showForm = true;
      editingTicketId = doc.id;
      selectedVendorId = doc['vendorId'];
      selectedVendorName = doc['vendorName'];
      _titleController.text = doc['title'];
      _descController.text = doc['description'];
    });
  }

  Future<void> deleteTicket(String id) async {
    await FirebaseFirestore.instance.collection('tickets').doc(id).delete();
    fetchTickets();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ticket deleted")));
  }

  Future<void> submitTicket() async {
    if (selectedVendorId == null || _titleController.text.isEmpty || _descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please fill all fields")));
      return;
    }

    final data = {
      'title': _titleController.text,
      'description': _descController.text,
      'vendorId': selectedVendorId,
      'vendorName': selectedVendorName,
      'createdAt': Timestamp.now(),
      'status': 'open',
      'createdBy': 'Admin'
    };

    if (editingTicketId != null) {
      await FirebaseFirestore.instance.collection('tickets').doc(editingTicketId).update(data);
    } else {
      await FirebaseFirestore.instance.collection('tickets').add(data);
    }

    _titleController.clear();
    _descController.clear();
    editingTicketId = null;
    fetchTickets();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ticket submitted')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: IconThemeData(color: Colors.white),
          title: Text('Send Query to Vendor', style: TextStyle(color: Colors.white),)),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 400,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black
                    ),
                    onPressed: () {
                      setState(() {
                        showForm = !showForm;
                        if (!showForm) {
                          _titleController.clear();
                          _descController.clear();
                          editingTicketId = null;
                        }
                      });
                    },
                    child: Text(showForm ? "Close Ticket Form" : "Raise a Ticket"),
                  ),
                ),
                if (showForm)
                  Padding(
                    padding: const EdgeInsets.only(top: 18.0),
                    child: SingleChildScrollView(
                      child: DataTable(
                        columnSpacing: 20,
                        headingRowColor: MaterialStateColor.resolveWith(
                              (states) => Colors.grey.shade200,
                        ),
                        columns: const [
                          DataColumn(label: Text('Vendor', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Title', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: [
                          DataRow(
                            cells: [
                              DataCell(
                                DropdownButton<String>(
                                  value: selectedVendorId,
                                  hint: const Text('Select Vendor'),
                                  items: vendorsList.map((vendor) {
                                    return DropdownMenuItem<String>(
                                      value: vendor['id'],
                                      child: Text(vendor['name'] ?? ''),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedVendorId = value;
                                      selectedVendorName = vendorsList.firstWhere((v) => v['id'] == value)['name'];
                                    });
                                  },
                                  isExpanded: true,
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 150,
                                  child: TextField(
                                    controller: _titleController,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 300,
                                  child: TextField(
                                    controller: _descController,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                ElevatedButton(
                                  onPressed: submitTicket,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(100, 40),
                                  ),
                                  child: Text(editingTicketId != null ? 'Update' : 'Submit'),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),

                SizedBox(height: 30),
                if(loadingTickets == true)
                  Column(
                    children: [
                      SizedBox(height: 30),
                      Text("Your Queries", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 10),
                      CircularProgressIndicator(color: Colors.black,)
                    ],
                  )

                else if (userTickets.isEmpty)
                  Column(
                    children: [
                      SizedBox(height: 30),
                      Text("Your Queries", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 10),
                      Text("There are no queries yet.", style: TextStyle(color: Colors.grey)),
                    ],
                  )
                else
                  DefaultTabController(
                    length: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 30),
                        const Text(
                          "Your Queries",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),

                        // TabBar
                        const TabBar(
                          indicatorColor: Colors.black,
                          labelColor: Colors.black,
                          tabs: [
                            Tab(text: "Open Tickets"),
                            Tab(text: "Closed Tickets"),
                          ],
                        ),

                        // TabBarView
                        Padding(
                          padding: const EdgeInsets.only(top: 18.0),
                          child: SizedBox(
                            height: 500, // Adjust height to fit your layout
                            child: TabBarView(
                              children: [
                                // Open tickets
                                _buildTicketList(
                                  context,
                                  userTickets.where((doc) => doc['status'] == 'open').toList(),
                                ),

                                // Closed tickets
                                _buildTicketList(
                                  context,
                                  userTickets.where((doc) => doc['status'] == 'closed').toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildTicketList(BuildContext context, List<DocumentSnapshot> tickets) {
    if (tickets.isEmpty) {
      return const Center(
        child: Text(
          "No tickets found",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      child: DataTable(
        columnSpacing: 20,
        headingRowColor: MaterialStateColor.resolveWith((states) => Colors.grey.shade200),
        columns: const [
          DataColumn(label: Text("Ticket ID", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Title", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Description", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Created At", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: tickets.map((doc) {
          return DataRow(
            cells: [
              DataCell(
                Text(doc.id),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: doc.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ticket ID copied')),
                  );
                },
              ),
              DataCell(
                Text(doc['title'] ?? ''),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: doc['title'] ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Title copied')),
                  );
                },
              ),
              DataCell(
                Text(doc['description'] ?? ''),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: doc['description'] ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Description copied')),
                  );
                },
              ),
              DataCell(
                Text(DateFormat('dd MMM yyyy, hh:mm a').format(doc['createdAt'].toDate())),
                onTap: () {
                  final dateStr = DateFormat('dd MMM yyyy, hh:mm a')
                      .format(doc['createdAt'].toDate());
                  Clipboard.setData(ClipboardData(text: dateStr));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Date & Time copied')),
                  );
                },
              ),
              DataCell(
                Text(
                  "${doc['status']}",
                  style: TextStyle(
                    color: doc['status'] == "open" ? Colors.green : Colors.red,
                  ),
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: "${doc['status']}"));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Status copied')),
                  );
                },
              ),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => populateTicketForEdit(doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => deleteTicket(doc.id),
                    ),
                  ],
                ),
              ),
            ],
            onSelectChanged: (_) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatPage(
                    ticketId: doc.id,
                    vendorName: doc['vendorName'],
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}
