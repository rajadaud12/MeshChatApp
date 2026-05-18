import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mesh_network_service.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final meshService = context.watch<MeshNetworkService>();
    final connectedCount = meshService.connectedEndpoints.length;
    final messages = meshService.groupMessages;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mesh Group Chat',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$connectedCount Nodes',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Chat List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: messages.isEmpty ? 1 : messages.length,
            itemBuilder: (context, index) {
              if (messages.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No messages yet.\nConnect to mesh to receive broadcasts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                );
              }

              final msg = messages[index];
              return _buildChatTile(
                context,
                name: msg.senderName,
                lastMessage: msg.text,
                time: "${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}",
                isMe: msg.senderId == meshService.userId,
              );
            },
          ),
        ),
        
        // New Chat FAB area
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Align(
            alignment: Alignment.bottomRight,
            child: FloatingActionButton(
              onPressed: () {
                _showSendMessageDialog(context, meshService);
              },
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: const Icon(Icons.add_comment, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  void _showSendMessageDialog(BuildContext context, MeshNetworkService meshService) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Send Group Broadcast', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: textController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter message...',
              hintStyle: TextStyle(color: Colors.white54),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                if (textController.text.isNotEmpty) {
                  meshService.sendGroupMessage(textController.text);
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.black,
              ),
              child: const Text('Broadcast'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChatTile(BuildContext context, {
    required String name,
    required String lastMessage,
    required String time,
    required bool isMe,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isMe ? Theme.of(context).primaryColor.withOpacity(0.05) : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isMe ? Theme.of(context).primaryColor.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isMe ? Theme.of(context).primaryColor.withOpacity(0.2) : Theme.of(context).colorScheme.secondary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person,
            color: isMe ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.secondary,
          ),
        ),
        title: Text(
          isMe ? "You" : name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              if (!isMe) ...[
                const Icon(Icons.route, size: 12, color: Colors.white54),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  lastMessage,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        trailing: Text(
          time,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ),
    );
  }
}
