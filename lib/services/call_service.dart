import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class CallService {
  static const String appId = "a4071bedee5f48ea91a1bed0a3bb7486";
  late RtcEngine _engine;
  RtcEngine? get engine => _engine;
  bool _isCameraOn = true;
  bool _isMicOn = true;
  bool _isFrontCamera = true;

  Future<void> initializeAgora() async {
    await [Permission.microphone, Permission.camera].request();
    
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(appId: appId));
    
    await _engine.enableVideo();
    await _engine.startPreview();
  }

  Future<void> joinCall(String channelName, String token) async {
    try {
      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine.enableVideo();
      await _engine.startPreview();
      
      ChannelMediaOptions options = const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      );

      await _engine.joinChannel(
        token: token,
        channelId: channelName,
        uid: 0,
        options: options,
      );
    } catch (e) {
      print('Error joining call: $e');
      throw e;
    }
  }

  Future<void> leaveCall() async {
    try {
      await _engine.leaveChannel();
      await _engine.stopPreview();
      await _engine.release();
    } catch (e) {
      print('Error leaving call: $e');
    }
  }

  Future<void> toggleCamera() async {
    _isCameraOn = !_isCameraOn;
    await _engine.enableLocalVideo(_isCameraOn);
  }

  Future<void> toggleMicrophone() async {
    _isMicOn = !_isMicOn;
    await _engine.enableLocalAudio(_isMicOn);
  }

  Future<void> switchCamera() async {
    await _engine.switchCamera();
    _isFrontCamera = !_isFrontCamera;
  }

  bool get isCameraOn => _isCameraOn;
  bool get isMicOn => _isMicOn;
  bool get isFrontCamera => _isFrontCamera;
}
