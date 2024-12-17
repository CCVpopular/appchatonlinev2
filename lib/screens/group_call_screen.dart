import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../services/group_call_service.dart';

class GroupCallScreen extends StatefulWidget {
  final String groupId;
  final String channelName;
  final String token;
  final String userId;
  final bool isInitiator;

  const GroupCallScreen({
    required this.groupId,
    required this.channelName,
    required this.token,
    required this.userId,
    this.isInitiator = false,
  });

  @override
  _GroupCallScreenState createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  final GroupCallService _callService = GroupCallService();
  Map<int, bool> _remoteUsers = {};
  bool _isInCall = false;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    try {
      await _callService.initializeAgora();
      _setupEventHandlers();
      await _callService.joinCall(widget.channelName, widget.token);

      if (widget.isInitiator) {
        await _callService.notifyGroupMembers(widget.groupId, widget.userId);
      }
    } catch (e) {
      print("Error initializing group call: $e");
      _handleError();
    }
  }

  void _setupEventHandlers() {
    _callService.engine?.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        setState(() => _isInCall = true);
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        setState(() => _remoteUsers[remoteUid] = true);
      },
      onUserOffline: (connection, remoteUid, reason) {
        setState(() => _remoteUsers.remove(remoteUid));
        if (_remoteUsers.isEmpty && !widget.isInitiator) {
          _endCall();
        }
      },
    ));
  }

  void _handleError() {
    _endCall();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to join group call')),
    );
  }

  Future<void> _endCall() async {
    await _callService.leaveCall(widget.groupId);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> renderUsers = [];

    // Add local user view
    renderUsers.add(_buildUserView(0));

    // Add remote users
    _remoteUsers.forEach((uid, _) {
      renderUsers.add(_buildUserView(uid));
    });

    return WillPopScope(
      onWillPop: () async {
        await _endCall();
        return true;
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // Main video grid
              _isGridView
                  ? GridView.count(
                      crossAxisCount: _calculateGridCrossAxisCount(),
                      children: renderUsers,
                    )
                  : Stack(children: _buildStackedLayout(renderUsers)),

              // Controls overlay
              _buildControls(),
            ],
          ),
        ),
      ),
    );
  }

  int _calculateGridCrossAxisCount() {
    int totalUsers = _remoteUsers.length + 1;
    if (totalUsers <= 1) return 1;
    if (totalUsers <= 4) return 2;
    return 3;
  }

  List<Widget> _buildStackedLayout(List<Widget> users) {
    if (users.isEmpty) return [];

    List<Widget> stackedUsers = [];
    Widget mainView = users[0];
    stackedUsers.add(mainView);

    // Add small previews for other users
    for (int i = 1; i < users.length; i++) {
      stackedUsers.add(
        Positioned(
          top: 10 + (i - 1) * 140,
          right: 10,
          width: 120,
          height: 160,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: users[i],
          ),
        ),
      );
    }

    return stackedUsers;
  }

  Widget _buildUserView(int uid) {
    return Container(
      margin: EdgeInsets.all(2),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
      child: uid == 0
          ? AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _callService.engine!,
                canvas: const VideoCanvas(uid: 0),
              ),
            )
          : AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _callService.engine!,
                canvas: VideoCanvas(uid: uid),
                connection: RtcConnection(channelId: widget.channelName),
              ),
            ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _callService.isMicOn ? Icons.mic : Icons.mic_off,
            onPressed: () {
              _callService.toggleMicrophone();
              setState(() {});
            },
          ),
          _buildControlButton(
            icon: Icons.call_end,
            color: Colors.red,
            onPressed: _endCall,
          ),
          _buildControlButton(
            icon: _callService.isCameraOn ? Icons.videocam : Icons.videocam_off,
            onPressed: () {
              _callService.toggleCamera();
              setState(() {});
            },
          ),
          _buildControlButton(
            icon: Icons.switch_camera,
            onPressed: () {
              _callService.switchCamera();
              setState(() {});
            },
          ),
          _buildControlButton(
            icon: _isGridView ? Icons.grid_view : Icons.view_agenda,
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color color = Colors.white,
  }) {
    return CircleAvatar(
      backgroundColor: Colors.black54,
      radius: 25,
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
      ),
    );
  }

  @override
  void dispose() {
    _callService.dispose();
    super.dispose();
  }
}
