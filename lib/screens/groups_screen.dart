import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/config.dart';
import '../services/groups_service.dart';
import 'creategroup_screen.dart';
import 'groupchat_screen.dart';

class GroupsScreen extends StatefulWidget {
  final String userId;

  const GroupsScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _GroupsScreenState createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late GroupsService groupsService;
  Map<String, Map<String, dynamic>> latestMessages = {};

  @override
  void initState() {
    super.initState();
    groupsService = GroupsService(widget.userId);
    _loadLatestMessages();

    // Refresh periodically
    Timer.periodic(Duration(seconds: 30), (_) {
      if (mounted) {
        groupsService.refreshGroups();
        _loadLatestMessages();
      }
    });
  }

  Future<void> _loadLatestMessages() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/api/groups/latest-messages/${widget.userId}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> messages = json.decode(response.body);
        setState(() {
          latestMessages.clear();
          for (var message in messages) {
            latestMessages[message['groupId']] = {
              'message': message['message'] ?? '',
              'type': message['type'] ?? 'text',
              'isRecalled': message['isRecalled'] ?? false,
              'timestamp': DateTime.parse(message['timestamp']),
            };
          }
        });
      }
    } catch (e) {
      print('Error loading latest group messages: $e');
    }
  }

  Widget _buildLatestMessage(String groupId) {
    final messageData = latestMessages[groupId];
    if (messageData == null) return const SizedBox.shrink();

    String messageText;
    if (messageData['isRecalled'] == true) {
      messageText = 'Message recalled';
    } else {
      switch (messageData['type']) {
        case 'image':
          messageText = '🖼️ Image';
          break;
        case 'file':
          if (messageData['message'].startsWith('{')) {
            try {
              final fileData = json.decode(messageData['message']);
              messageText = '📎 ${fileData['fileName']}';
            } catch (e) {
              messageText = '📎 File';
            }
          } else {
            messageText = '📎 File';
          }
          break;
        default:
          messageText = messageData['message'] ?? '';
          if (messageText.length > 30) {
            messageText = messageText.substring(0, 27) + '...';
          }
      }
    }

    return Text(
      messageText,
      style: const TextStyle(
        fontSize: 13,
        height: 1.5,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  void dispose() {
    groupsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        backgroundColor: Colors.transparent,
        elevation: 4.0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromARGB(207, 70, 131, 180),
                Color.fromARGB(41, 130, 190, 197),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CreateGroupScreen(userId: widget.userId),
                ),
              ).then((result) {
                if (result == true) {
                  groupsService.refreshGroups();
                }
              });
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: groupsService.groupsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading groups'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No groups found'));
          }

          final groups = snapshot.data!;
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.fromARGB(207, 70, 131, 180),
                      Color.fromARGB(129, 130, 190, 197),
                    ],
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10.0),
                  title: Text(
                    group['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (latestMessages.containsKey(group['id']))
                        _buildLatestMessage(group['id'])
                      else
                        Text(
                          'No messages yet',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      SizedBox(height: 4),
                      Text(
                        '${group['members']?.length ?? 0} members',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupChatScreen(
                          groupId: group['id'],
                          userId: widget.userId,
                          groupNameReal: group['name'],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
