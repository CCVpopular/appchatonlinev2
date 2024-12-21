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
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: Container(
          margin: EdgeInsets.only(top: 0, left: 10, right: 10, bottom: 10),
          child: AppBar(
            title: Padding(
              padding: EdgeInsets.only(left: 15, bottom: 15),
              child: const Text(
                'Groups',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: Stack(
              children: [
                Positioned(
                  top: 20,
                  left: 20,
                  right: 0,
                  bottom: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Color.fromARGB(255, 57, 51, 66)
                          : Color.fromARGB(77, 83, 32, 120),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 5,
                  left: 5,
                  right: 8,
                  bottom: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Color.fromARGB(255, 77, 68, 89)
                          : Color.fromARGB(255, 255, 255, 255),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              Transform.translate(
                offset: Offset(-10, -5), // Di chuyển 10px sang phải
                child: IconButton(
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
              ),
            ],
          ),
        ),
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
          return Container(
            margin: const EdgeInsets.all(10.0),
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? LinearGradient(
                      colors: [
                        Color.fromARGB(255, 37, 3, 55),
                        Color.fromARGB(255, 53, 11, 75),
                        Color.fromARGB(255, 61, 22, 82),
                        Color.fromARGB(255, 161, 110, 188)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        Color.fromARGB(255, 255, 255, 255),
                        Color.fromARGB(255, 144, 90, 169)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                width: 2,
              ),
            ),
            child: ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return Container(
                  margin: const EdgeInsets.symmetric(
                      vertical: 5.0, horizontal: 10.0),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 11,
                        left: 11,
                        child: Container(
                          width: screenWidth * 0.8,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Color.fromARGB(77, 175, 112, 221),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                spreadRadius: 2,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 5,
                        left: -0.5,
                        child: Container(
                          width: screenWidth * 0.8,
                          height: 70,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Color.fromARGB(255, 77, 68, 89)
                                    : Color.fromARGB(255, 255, 255, 255),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            child: Icon(Icons.group),
                            radius: 20,
                          ),
                        ),
                        title: Text(
                          group['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
                                style:
                                    const TextStyle(fontSize: 13, height: 1.5),
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
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
