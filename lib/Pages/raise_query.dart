import 'package:admin/Pages/chat_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
                  SizedBox(
                    width: 400,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          hint: Text("Select Vendor"),
                          value: selectedVendorId,
                          items: vendorsList.map((vendor) {
                            return DropdownMenuItem<String>(
                              value: vendor['id'],
                              child: Text(vendor['name'] ?? ''),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedVendorId = value;
                              selectedVendorName =
                              vendorsList.firstWhere((v) => v['id'] == value)['name'];
                            });
                          },
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _titleController,
                          decoration: InputDecoration(labelText: 'Ticket Title'),
                        ),
                        TextField(
                          controller: _descController,
                          decoration: InputDecoration(labelText: 'Description'),
                          maxLines: 3,
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: submitTicket,
                          child: Text(editingTicketId != null ? 'Update Ticket' : 'Submit Ticket'),
                        ),
                      ],
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
                        SizedBox(
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

    return ListView(
      children: tickets.map((doc) {
        return Card(
          elevation: 2,
          color: Colors.white,
          child: ListTile(
            title: Text(doc['title']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    text: 'Ticket ID:\n',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                    children: [
                      TextSpan(
                        text: doc.id,
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontFamily: GoogleFonts.poppins().fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    text: 'Description:\n',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                    children: [
                      TextSpan(
                        text: doc['description'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontFamily: GoogleFonts.poppins().fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    text: 'Created at:\n',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                    children: [
                      TextSpan(
                        text: DateFormat('dd MMM yyyy, hh:mm a')
                            .format(doc['createdAt'].toDate()),
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontFamily: GoogleFonts.poppins().fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    text: 'Status:\n',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                    children: [
                      TextSpan(
                        text: "${doc['status']}",
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontFamily: GoogleFonts.poppins().fontFamily,
                          color: doc['status'] == "open"
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
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
            onTap: () {
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
          ),
        );
      }).toList(),
    );
  }
}
