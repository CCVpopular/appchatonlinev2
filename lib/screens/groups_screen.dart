import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    groupsService = GroupsService(widget.userId);
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
                  subtitle: Text(
                    'Owner: ${group['owner']}',
                    style: const TextStyle(
                      color: Color.fromARGB(255, 51, 51, 51),
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupChatScreen(
                          groupId: group['id'],
                          userId: widget.userId,
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
