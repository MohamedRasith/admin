import 'package:admin/Pages/chat_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 30),
                      Text("Your Queries", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 10),
                      for (var doc in userTickets)
                        Card(
                          elevation: 2,
                          color: Colors.white,
                          child: ListTile(
                            title: Text(doc['title']),
                            subtitle: Text(doc['description']),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => populateTicketForEdit(doc),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => deleteTicket(doc.id),
                                ),
                              ],
                            ),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (context) => ChatPage(
                                    ticketId: doc.id,
                                    vendorName: doc['vendorName'],
                                  ),
                                ));
                              }

                          ),
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
