import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/config.dart';

class SystemStatsScreen extends StatefulWidget {
  @override
  _SystemStatsScreenState createState() => _SystemStatsScreenState();
}

class _SystemStatsScreenState extends State<SystemStatsScreen> {
  Map<String, dynamic>? statistics;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      print('Fetching statistics...');
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/api/messages/statistics'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        Duration(seconds: 30), // Increased timeout
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            statistics = data;
            isLoading = false;
          });
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['details'] ?? errorData['error'] ?? 'Unknown error occurred');
      }
    } catch (e) {
      print('Error loading statistics: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          statistics = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading statistics: $e'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadStatistics,
            ),
            duration: Duration(seconds: 10),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('System Statistics'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadStatistics,
            tooltip: 'Refresh Statistics',
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : statistics == null
              ? Center(child: Text('No statistics available'))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTotalStats(),
                      SizedBox(height: 24),
                      Text(
                        'Direct Messages by User',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      _buildUserStatsList(statistics!['userStats']),
                      SizedBox(height: 24),
                      Text(
                        'Group Messages by User',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      _buildUserStatsList(statistics!['groupStats']),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTotalStats() {
    final totalStats = statistics!['totalStats'];
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Message Statistics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            _buildStatRow('Direct Messages', totalStats['directMessages']),
            _buildStatRow('Group Messages', totalStats['groupMessages']),
            Divider(),
            _buildStatRow('Total Messages', totalStats['totalMessages']),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toString(),
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildUserStatsList(List<dynamic> stats) {
    if (stats.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('No statistics available'),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: stats.length,
        separatorBuilder: (context, index) => Divider(),
        itemBuilder: (context, index) {
          final stat = stats[index];
          return ListTile(
            title: Text(stat['username'] ?? 'Unknown User'),
            trailing: Text(
              (stat['messageCount'] ?? 0).toString(),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }
}
