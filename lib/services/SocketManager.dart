import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketManager {
  static final SocketManager _instance = SocketManager._internal();
  IO.Socket? _socket;

  factory SocketManager(String baseUrl) {
    _instance._initializeSocket(baseUrl);
    return _instance;
  }

  SocketManager._internal();

  void _initializeSocket(String baseUrl) {
    if (_socket == null || !(_socket!.connected)) {
      _socket = IO.io(
        baseUrl,
        IO.OptionBuilder().setTransports(['websocket']).build(),
      );

      _socket?.onConnect((_) => print('Socket connected'));
      _socket?.onDisconnect((_) => print('Socket disconnected'));
    }
  }

  IO.Socket getSocket() {
    if (_socket == null) {
      throw Exception('Socket has not been initialized. Call SocketManager(baseUrl) first.');
    }
    return _socket!;
  }
}
