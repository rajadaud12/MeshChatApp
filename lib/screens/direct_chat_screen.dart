import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mesh_network_service.dart';

class DirectChatScreen extends StatefulWidget {
  final String targetId;
  final String targetName;

  const DirectChatScreen({super.key, required this.targetId, required this.targetName});

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final meshService = context.watch<MeshNetworkService>();
    final messages = meshService.directMessages[widget.targetId] ?? [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.targetName, style: const TextStyle(fontSize: 16)),
            Text(
              'Direct P2P Encrypted',
              style: TextStyle(fontSize: 12, color: Theme.of(context).primaryColor),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg.senderId == meshService.userId;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8, top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isMe ? Theme.of(context).primaryColor.withOpacity(0.2) : Colors.white12,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isMe ? Theme.of(context).primaryColor.withOpacity(0.5) : Colors.white24,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}",
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type message...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  onPressed: () {
                    if (_textController.text.isNotEmpty) {
                      meshService.sendDirectMessage(widget.targetId, _textController.text);
                      _textController.clear();
                    }
                  },
                  backgroundColor: Theme.of(context).primaryColor,
                  elevation: 0,
                  child: const Icon(Icons.send, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
