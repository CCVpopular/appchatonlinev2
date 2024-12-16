import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../services/call_service.dart';

class CallScreen extends StatefulWidget {
  final String channelName;
  final String token; 
  final bool isOutgoing;

  const CallScreen({
    required this.channelName,
    required this.token,
    this.isOutgoing = true,
  });

  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallService _callService = CallService();
  bool _isInCall = false;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    await _callService.initializeAgora();
    await _callService.joinCall(widget.channelName, widget.token);
    setState(() => _isInCall = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_isInCall)
            AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _callService.engine!,
                canvas: const VideoCanvas(uid: 0),
              ),
            ),
          Positioned(
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
                  onPressed: () async {
                    await _callService.leaveCall();
                    Navigator.pop(context);
                  },
                ),
                _buildControlButton(
                  icon: _callService.isCameraOn
                      ? Icons.videocam
                      : Icons.videocam_off,
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
              ],
            ),
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
}
