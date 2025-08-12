import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatPage extends StatefulWidget {
  final String ticketId;
  final String vendorName;

  ChatPage({required this.ticketId, required this.vendorName});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  String? _status;

  Uint8List? _selectedFileBytes;
  String? _selectedFileName;

  Future<void> pickDocument() async {
    final result = await  FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'png'],
      withData: true, // important for web to get bytes
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _selectedFileBytes = result.files.single.bytes;
        _selectedFileName = result.files.single.name;
        _messageController.text = result.files.single.name;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final doc = await FirebaseFirestore.instance
        .collection('tickets')
        .doc(widget.ticketId)
        .get();

    if (doc.exists && doc.data()!.containsKey('status')) {
      setState(() {
        _status = doc['status'];
      });
    }
  }

  Future<void> updateStatus(String newStatus) async {
    await FirebaseFirestore.instance
        .collection('tickets')
        .doc(widget.ticketId)
        .update({'status': newStatus});

    setState(() {
      _status = newStatus;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Status updated to '$newStatus'")));
  }

  Stream<QuerySnapshot> getMessagesStream() {
    return FirebaseFirestore.instance
        .collection('tickets')
        .doc(widget.ticketId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  Future<void> sendMessage(String messageText, String sender) async {
    if (messageText.trim().isEmpty && _selectedFileBytes == null) return;

    setState(() => _isSending = true);
    String? fileUrl;
    try {

      if (_selectedFileBytes != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('ticket_attachments/${widget.ticketId}/${DateTime.now().millisecondsSinceEpoch}_$_selectedFileName');

        await storageRef.putData(_selectedFileBytes!);
        fileUrl = await storageRef.getDownloadURL();
      }
      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .collection('messages')
          .add({
        'message': messageText.trim(),
        'sender': sender,
        'timestamp': FieldValue.serverTimestamp(),
        'isSeen': false,
      });

      _messageController.clear();
      _selectedFileBytes = null;
      _selectedFileName = null;

      Future.delayed(Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 60,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Error sending message: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_status == null) {
      // Wait for status to load
      return Scaffold(
        appBar: AppBar(
          title: Text('Chat with ${widget.vendorName}'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Chat with ${widget.vendorName}'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                "Status: ${_status}",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getMessagesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final messageText = msg['message'];
                    final sender = msg['sender'];
                    final isUser = sender == 'user';

                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (msg['message'] != null && msg['message'].isNotEmpty)
                              Text(msg['message'], style: TextStyle(color: isUser?Colors.white:Colors.black),),
                            if (msg['fileUrl'] != null && (msg['fileUrl'] as String).isNotEmpty)
                              InkWell(
                                onTap: () => launchUrl(Uri.parse(msg['fileUrl'])),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.insert_drive_file, color: Colors.blue),
                                    SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        msg['fileName'] ?? 'Attachment',
                                        style: TextStyle(color: Colors.blue),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Divider(height: 1),
          if (_status != "closed")
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.attach_file),
                    onPressed: pickDocument,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onSubmitted: (val) => sendMessage(val, 'admin'),
                    ),
                  ),
                  SizedBox(width: 8),
                  _isSending
                      ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                      : IconButton(
                    icon: Icon(Icons.send),
                    onPressed: () => sendMessage(_messageController.text, 'admin'),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: _status == "closed"
          ? null
          : Align(
        alignment: Alignment.bottomRight,
        child: Container(
          margin: const EdgeInsets.only(right: 16, bottom: 50),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => updateStatus('closed'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.close, color: Colors.white),
                Text(
                  "Mark as Closed",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
