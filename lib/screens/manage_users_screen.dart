
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/config.dart';

class ManageUsersScreen extends StatefulWidget {
  @override
  _ManageUsersScreenState createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  List<dynamic> users = [];

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    try {
      final response = await http.get(Uri.parse('${Config.apiBaseUrl}/api/users'));
      if (response.statusCode == 200) {
        setState(() {
          users = json.decode(response.body);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load users: $e')),
      );
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final result = await showDialog(
      context: context,
      builder: (context) => EditUserDialog(user: user),
    );
    if (result == true) {
      loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Manage Users')),
      body: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return ListTile(
            title: Text(user['username']),
            subtitle: Text('Role: ${user['role']} - Status: ${user['status']}'),
            trailing: IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => _editUser(user),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog(
            context: context,
            builder: (context) => CreateUserDialog(),
          );
          if (result == true) {
            loadUsers();
          }
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class EditUserDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  EditUserDialog({required this.user});

  @override
  _EditUserDialogState createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  late TextEditingController _usernameController;
  late String _role;
  late String _status;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user['username']);
    _role = widget.user['role'];
    _status = widget.user['status'];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit User'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(labelText: 'Username'),
          ),
          DropdownButtonFormField<String>(
            value: _role,
            items: ['user', 'admin'].map((role) {
              return DropdownMenuItem(value: role, child: Text(role));
            }).toList(),
            onChanged: (value) => setState(() => _role = value!),
            decoration: InputDecoration(labelText: 'Role'),
          ),
          DropdownButtonFormField<String>(
            value: _status,
            items: ['active', 'inactive'].map((status) {
              return DropdownMenuItem(value: status, child: Text(status));
            }).toList(),
            onChanged: (value) => setState(() => _status = value!),
            decoration: InputDecoration(labelText: 'Status'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            try {
              final response = await http.put(
                Uri.parse('${Config.apiBaseUrl}/api/users/${widget.user['_id']}'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode({
                  'username': _usernameController.text,
                  'role': _role,
                  'status': _status,
                }),
              );
              if (response.statusCode == 200) {
                Navigator.pop(context, true);
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update user: $e')),
              );
            }
          },
          child: Text('Save'),
        ),
      ],
    );
  }
}

class CreateUserDialog extends StatefulWidget {
  @override
  _CreateUserDialogState createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'user';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create User'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(labelText: 'Username'),
          ),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          DropdownButtonFormField<String>(
            value: _role,
            items: ['user', 'admin'].map((role) {
              return DropdownMenuItem(value: role, child: Text(role));
            }).toList(),
            onChanged: (value) => setState(() => _role = value!),
            decoration: InputDecoration(labelText: 'Role'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            try {
              final response = await http.post(
                Uri.parse('${Config.apiBaseUrl}/api/users'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode({
                  'username': _usernameController.text,
                  'password': _passwordController.text,
                  'role': _role,
                }),
              );
              if (response.statusCode == 201) {
                Navigator.pop(context, true);
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to create user: $e')),
              );
            }
          },
          child: Text('Create'),
        ),
      ],
    );
  }
}