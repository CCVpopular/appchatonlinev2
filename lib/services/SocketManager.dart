import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketManager {
  static SocketManager? _instance;
  late IO.Socket _socket;

  // Private constructor
  SocketManager._internal(String baseUrl) {
    _socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });
    _socket.connect();
  }

  // Factory constructor to return singleton instance
  factory SocketManager(String baseUrl) {
    _instance ??= SocketManager._internal(baseUrl);
    return _instance!;
  }

  // Get socket instance
  IO.Socket getSocket() {
    if (!_socket.connected) {
      _socket.connect();
    }
    return _socket;
  }

  // Properly dispose socket
  void dispose() {
    _socket.disconnect();
    _instance = null;
  }
}
