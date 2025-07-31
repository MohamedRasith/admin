import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  String _status = 'open';

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
    if (messageText.trim().isEmpty) return;

    setState(() => _isSending = true);

    try {
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
                "Status: ${_status.toUpperCase() == "OPEN"?"Pending":_status}",
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
                        child: Text(
                          messageText,
                          style: TextStyle(
                            color: isUser ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Divider(height: 1),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onSubmitted: (val) => sendMessage(val, 'user'),
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
                  onPressed: () => sendMessage(_messageController.text, 'user'),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Align(
        alignment: Alignment.bottomRight,
        child: Container(
          margin: const EdgeInsets.only(right: 16, bottom: 50),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              popupMenuTheme: PopupMenuThemeData(
                color: Colors.black,
                textStyle: TextStyle(color: Colors.white),
              ),
            ),
            child: PopupMenuButton<String>(
              offset: Offset(0, -100), // show menu upward
              color: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onSelected: (value) => updateStatus(value),
              itemBuilder: (context) => [
                if (_status != 'on process')
                  PopupMenuItem(
                    value: 'on process',
                    child: Text('Mark as On Process', style: TextStyle(color: Colors.white)),
                  ),
                if (_status != 'completed')
                  PopupMenuItem(
                    value: 'completed',
                    child: Text('Mark as Completed', style: TextStyle(color: Colors.white)),
                  ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.settings, color: Colors.white),
                  Text(
                    "Click here\nto update status",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
