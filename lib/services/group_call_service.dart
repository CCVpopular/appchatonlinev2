import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/config.dart';

class GroupCallService {
  RtcEngine? engine;
  bool isMicOn = true;
  bool isCameraOn = true;
  
  // Agora configuration
  final String appId = Config.agoraAppId;
  
  Future<void> initializeAgora() async {
    engine = createAgoraRtcEngine();
    await engine!.initialize(RtcEngineContext(appId: appId));
    
    await engine!.enableVideo();
    await engine!.startPreview();
    await engine!.setChannelProfile(
      ChannelProfileType.channelProfileCommunication
    );
  }

  Future<void> joinCall(String channelName, String token) async {
    if (engine == null) return;

    await engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
  }

  Future<void> leaveCall(String groupId) async {
    if (engine == null) return;

    await engine!.leaveChannel();
    await engine!.stopPreview();
    
    // Send call ended message to group
    await _sendCallEndedMessage(groupId);
  }

  Future<void> notifyGroupMembers(String groupId, String initiatorId) async {
    try {
      final response = await http.post(
        Uri.parse('${Config.apiBaseUrl}/api/groups/notify-call'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'groupId': groupId,
          'initiatorId': initiatorId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to notify group members');
      }
    } catch (e) {
      print('Error notifying group members: $e');
    }
  }

  Future<void> _sendCallEndedMessage(String groupId) async {
    try {
      await http.post(
        Uri.parse('${Config.apiBaseUrl}/api/groups/call-ended'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'groupId': groupId,
          'message': 'Group call ended',
        }),
      );
    } catch (e) {
      print('Error sending call ended message: $e');
    }
  }

  void toggleMicrophone() {
    if (engine == null) return;
    isMicOn = !isMicOn;
    engine!.enableLocalAudio(isMicOn);
  }

  void toggleCamera() {
    if (engine == null) return;
    isCameraOn = !isCameraOn;
    engine!.enableLocalVideo(isCameraOn);
  }

  void switchCamera() {
    if (engine == null) return;
    engine!.switchCamera();
  }

  void dispose() {
    engine?.release();
    engine = null;
  }
}
