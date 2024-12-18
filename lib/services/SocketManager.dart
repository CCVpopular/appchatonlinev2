import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketManager {
  static SocketManager? _instance;
  static IO.Socket? _socket;

  factory SocketManager(String serverUrl) {
    _instance ??= SocketManager._internal(serverUrl);
    return _instance!;
  }

  SocketManager._internal(String serverUrl) {
    _socket ??= IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    // Add status change listener
    _socket!.on('userStatusChanged', (data) {
      print('Status changed: $data');
      // You can add a callback here or use a stream controller
      if (onStatusChange != null) {
        onStatusChange!(data);
      }
    });
  }

  // Callback for status changes
  Function(dynamic)? onStatusChange;

  void setStatusChangeCallback(Function(dynamic) callback) {
    onStatusChange = callback;
  }

  IO.Socket getSocket() {
    return _socket!;
  }

  Future<void> disconnect() async {
    if (_socket != null) {
      try {
        print('=== Socket Disconnection Start ===');
        print('Current socket status: ${_socket!.connected ? 'connected' : 'disconnected'}');
        
        // Force disconnect
        print('Step 1: Disconnecting socket');
        _socket!.disconnect();
        
        print('Step 2: Waiting for disconnect to complete');
        await Future.delayed(Duration(milliseconds: 500));
        
        print('Step 3: Cleaning up socket');
        _socket!.dispose();
        _socket!.destroy();
        _socket!.close();
        
        print('Step 4: Clearing socket references');
        _socket = null;
        _instance = null;
        
        print('=== Socket Disconnection Complete ===');
      } catch (e) {
        print('!!! Error during socket disconnection:');
        print(e.toString());
        print('Forcing socket cleanup');
        _socket = null;
        _instance = null;
      }
    } else {
      print('No active socket to disconnect');
    }
  }
}
