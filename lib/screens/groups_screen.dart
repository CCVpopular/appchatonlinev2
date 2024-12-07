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
        title: Text('Groups'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CreateGroupScreen(userId: widget.userId),
                ),
              ).then((result) {
                if (result == true) {
                  groupsService.refreshGroups(); // Gọi hàm làm mới danh sách
                }
              });
            },

            child: Text('Create Group'),
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
              return ListTile(
                title: Text(group['name']),
                subtitle: Text('Owner: ${group['owner']}'),
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
              );
            },
          );
        },
      ),
    );
  }
}
