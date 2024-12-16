import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../services/call_service.dart';

class CallScreen extends StatefulWidget {
  final String channelName;
  final String token;
  final bool isOutgoing;
  final VoidCallback? onCallEnded; // Add callback
  final VoidCallback? onCallRejected; // Add rejection callback

  const CallScreen({
    required this.channelName,
    required this.token,
    this.isOutgoing = true,
    this.onCallEnded,
    this.onCallRejected,
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

  Future<void> _endCall() async {
    await _callService.leaveCall();
    if (widget.onCallEnded != null) {
      widget.onCallEnded!();
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _handleCallRejected() {
    if (widget.onCallRejected != null) {
      widget.onCallRejected!();
    }
    if (mounted) {
      Navigator.pop(context);
    }
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
                  onPressed: _endCall, // Use the new method
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
