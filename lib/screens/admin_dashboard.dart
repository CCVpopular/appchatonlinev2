import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'system_stats_screen.dart';

class AdminDashboard extends StatefulWidget {
  final String userId;

  const AdminDashboard({Key? key, required this.userId}) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Future<void> _handleLogout() async {
    try {
      await AuthService().logout();
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: GridView.count(
        padding: EdgeInsets.all(16),
        crossAxisCount: 2,
        children: [
          _buildDashboardCard(
            'Manage Users',
            Icons.people,
            () => Navigator.pushNamed(context, '/manage-users'),
          ),
          _buildDashboardCard(
            'System Stats',
            Icons.analytics,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SystemStatsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(String title, IconData icon, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48),
            SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}