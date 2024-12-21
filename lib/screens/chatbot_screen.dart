import 'package:flutter/material.dart';
import '../services/chatbot_service.dart';

class ChatBotScreen extends StatefulWidget {
  @override
  _ChatBotScreenState createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ChatBotService _chatBotService = ChatBotService();
  bool _isLoading = false;

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final userMessage = _messageController.text;

    setState(() {
      _messages.add({'sender': 'user', 'message': userMessage});
      _isLoading = true;
    });

    _messageController.clear();

    try {
      final botResponse = await _chatBotService.sendMessage(userMessage);
      setState(() {
        _messages.add({'sender': 'bot', 'message': botResponse});
      });
    } catch (e) {
      setState(() {
        _messages.add({'sender': 'bot', 'message': 'Error: $e'});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70), // Điều chỉnh chiều cao của AppBar
        child: Container(
          margin: EdgeInsets.only(top: 0, left: 10, right: 10, bottom: 10),
          child: AppBar(
            title: Padding(
              padding: EdgeInsets.only(
                  left: 15, bottom: 15), // Thêm padding cho tiêu đề
              child: const Text(
                'Gemini Chat Bot',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            backgroundColor: Colors.transparent, // Nền trong suốt
            elevation: 0, // Xóa bóng đổ mặc định của AppBar
            flexibleSpace: Stack(
              children: [
                // Nền thứ nhất (dưới cùng)
                Positioned(
                  top: 20,
                  left: 20,
                  right: 0,
                  bottom: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Color.fromARGB(255, 57, 51, 66)
                          : Color.fromARGB(77, 83, 32, 120),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                // Nền thứ hai (chồng lên nền thứ nhất)
                Positioned(
                  top: 5,
                  left: 5,
                  right: 8,
                  bottom: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Color.fromARGB(255, 77, 68, 89)
                          : Color.fromARGB(255, 255, 255, 255),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUserMessage = message['sender'] == 'user';
                return Align(
                  alignment: isUserMessage
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Avatar cho người nhận
                        if (!isUserMessage)
                          CircleAvatar(
                            backgroundImage: AssetImage(
                                'assets/avatar.png'), // Đường dẫn đến avatar
                          ),
                        SizedBox(width: 8),
                        // Bong bóng chat
                        Container(
                          padding: EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth:
                                250, // Bạn có thể điều chỉnh kích thước tối đa của bong bóng
                          ),
                          decoration: BoxDecoration(
                            color: isUserMessage
                                ? Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color.fromARGB(255, 76, 65, 86)
                                    : const Color.fromARGB(255, 179, 144, 249)
                                : Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color.fromARGB(255, 250, 250, 250)
                                    : const Color.fromARGB(255, 220, 220, 220),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isUserMessage
                                  ? Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color.fromARGB(255, 186, 144, 249)!
                                      : const Color.fromARGB(255, 116, 30, 229)!
                                  : Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color.fromARGB(255, 255, 255, 255)!
                                      : const Color.fromARGB(255, 0, 0, 0)!,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            message['message'] ?? '',
                            style: TextStyle(
                              color:
                                  isUserMessage ? Colors.white : Colors.black,
                            ),
                            softWrap: true, // Cho phép tự động xuống dòng
                            overflow:
                                TextOverflow.visible, // Không cắt bớt văn bản
                          ),
                        ),
                        SizedBox(width: 8),
                        // Avatar cho người gửi
                        if (isUserMessage)
                          CircleAvatar(
                            backgroundImage: AssetImage('assets/avatar.png'),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Color.fromARGB(255, 33, 33, 33) // Nền tối
                    : Color.fromARGB(255, 255, 255, 255), // Nền sáng
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white // Viền trắng khi chế độ tối
                      : Colors.black, // Viền đen khi chế độ sáng
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Enter your message...',
                            border: InputBorder.none, // Xóa viền của TextField
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Color.fromARGB(107, 128, 83, 180)
                            : Color.fromARGB(255, 255, 255, 255),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          width: 2,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.send),
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color.fromARGB(255, 255, 255, 255)
                            : const Color.fromARGB(255, 103, 48, 129),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
