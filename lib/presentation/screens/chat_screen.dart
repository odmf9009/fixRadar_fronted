import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/service_request.dart';
import '../../core/models/chat_message_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/upload_service.dart';

class ChatScreen extends StatefulWidget {
  final ServiceRequest request;
  const ChatScreen({super.key, required this.request});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  final UploadService _uploadService = UploadService();
  final ImagePicker _picker = ImagePicker();
  
  final TextEditingController _messageController = TextEditingController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _currentUserName = 'Usuario';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    await _firestoreService.updateChatLastRead(widget.request.id, _currentUserId);
  }

  Future<void> _loadUserName() async {
    final user = await _firestoreService.getUser(_currentUserId);
    if (mounted && user != null) {
      setState(() {
        _currentUserName = (user.username.isNotEmpty) ? user.username : user.name;
      });
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = ChatMessage(
      id: '',
      requestId: widget.request.id,
      senderId: _currentUserId,
      senderName: _currentUserName,
      text: _messageController.text.trim(),
      type: MessageType.text,
      createdAt: DateTime.now(),
    );

    _messageController.clear();
    await _firestoreService.sendChatMessage(widget.request.id, message);
  }

  Future<void> _sendLocation() async {
    setState(() => _isSending = true);
    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null) {
        final message = ChatMessage(
          id: '',
          requestId: widget.request.id,
          senderId: _currentUserId,
          senderName: _currentUserName,
          text: '📍 Mi ubicación actual',
          latitude: pos.latitude,
          longitude: pos.longitude,
          type: MessageType.location,
          createdAt: DateTime.now(),
        );
        await _firestoreService.sendChatMessage(widget.request.id, message);
      }
    } catch (e) {
      print('Error sending location: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 60);
    if (pickedFile == null) return;

    setState(() => _isSending = true);
    try {
      final url = await _uploadService.uploadObjectImage(File(pickedFile.path));
      final message = ChatMessage(
        id: '',
        requestId: widget.request.id,
        senderId: _currentUserId,
        senderName: _currentUserName,
        text: '📷 Foto del trabajo',
        imageUrl: url,
        type: MessageType.image,
        createdAt: DateTime.now(),
      );
      await _firestoreService.sendChatMessage(widget.request.id, message);
    } catch (e) {
      print('Error sending image: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.request.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            Text(
              widget.request.technicianName != null ? 'Con ${widget.request.technicianName}' : 'Chat de servicio',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.grey),
            onPressed: () => Navigator.pushNamed(context, '/object-detail', arguments: widget.request),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusBar(),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _firestoreService.getChatMessages(widget.request.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final bool isMe = msg.senderId == _currentUserId;
                    return _buildMessageBubble(msg, isMe);
                  },
                );
              },
            ),
          ),
          if (_isSending) const LinearProgressIndicator(minHeight: 2),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.blue[50],
      child: Row(
        children: [
          const Icon(Icons.security, size: 14, color: Colors.blue),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Por tu seguridad, no compartas datos bancarios fuera de la plataforma.',
              style: TextStyle(fontSize: 11, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    Widget content;
    switch (msg.type) {
      case MessageType.image:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(msg.imageUrl!, width: 200, height: 200, fit: BoxFit.cover),
            ),
            if (msg.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(msg.text, style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
            ]
          ],
        );
        break;
      case MessageType.location:
        content = InkWell(
          onTap: () => _openMap(msg.latitude!, msg.longitude!),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on, color: isMe ? Colors.white : const Color(0xFFFF8A00), size: 20),
                  const SizedBox(width: 8),
                  Text('Ubicación compartida', style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Toca para ver en el mapa', style: TextStyle(color: isMe ? Colors.white70 : Colors.grey, fontSize: 12)),
            ],
          ),
        );
        break;
      default:
        content = Text(msg.text, style: TextStyle(color: isMe ? Colors.white : Colors.black87));
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFFF8A00) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
          ),
        ),
        child: content,
      ),
    );
  }

  Future<void> _openMap(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFF8A00)),
                  onPressed: () => _showQuickActions(),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                CircleAvatar(
                  backgroundColor: const Color(0xFFFF8A00),
                  radius: 20,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Acciones Rápidas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionItem(
                  Icons.location_on_outlined, 
                  'Ubicación', 
                  Colors.green, 
                  () {
                    Navigator.pop(context);
                    _sendLocation();
                  }
                ),
                _buildActionItem(
                  Icons.camera_alt_outlined, 
                  'Cámara', 
                  Colors.blue, 
                  () {
                    Navigator.pop(context);
                    _sendImage();
                  }
                ),
                _buildActionItem(
                  Icons.receipt_long_outlined, 
                  'Presupuesto', 
                  Colors.orange, 
                  () {
                    Navigator.pop(context);
                    // Podría abrir el diálogo de quote nuevamente si fuera necesario
                  }
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
