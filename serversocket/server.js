const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const mongoose = require('mongoose');
const authRoutes = require('./routes/authRoutes');
const friendRoutes = require('./routes/friendRoutes');
const messageRoutes = require('./routes/messageRoutes');
const Message = require('./models/Message');
const GroupMessage = require('./models/GroupMessage');
const User = require('./models/User');
const GroupRoutes = require('./routes/groupRoutes')
const Group = require('./models/Group');
const userRoutes = require('./routes/userRoutes')

const app = express();
const server = http.createServer(app);
const io = socketIo(server);

const admin = require('firebase-admin');

const serviceAccount = require('./key/app-chat-push-notification.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});


// Kết nối MongoDB
mongoose.connect('mongodb://localhost:27017/chatApp', {
  useNewUrlParser: true,
  useUnifiedTopology: true,
});
mongoose.connection.on('connected', () => console.log('MongoDB connected'));
mongoose.connection.on('error', (err) => console.error('MongoDB connection error:', err));

app.set('socketio', io);

// Middleware
app.use(express.json());

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/friends', friendRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/users', userRoutes);
app.use('/api/groups', GroupRoutes);

io.on('connection', (socket) => {
  console.log('New client connected');

    // Khi người dùng tham gia kết nối
    socket.on('joinUser', (userId) => {
      console.log(`${userId} joined`);
      socket.join(userId); // Tham gia phòng riêng cho mỗi người dùng
    });
  
    // Khi có thay đổi về nhóm (tạo nhóm hoặc mời thành viên mới)
    socket.on('groupUpdated', (userId) => {
      io.to(userId).emit('updateGroups'); // Gửi thông báo cập nhật nhóm tới userId
    });

  socket.on('joinRoom', ({ userId, friendId }) => {
    // Tạo tên phòng duy nhất cho hai người dùng
    const roomName = [userId, friendId].sort().join('_');
    // socket.leaveAll(); 
    console.log(`Current rooms for socket ${socket.id}:`, Array.from(socket.rooms));
    socket.join(roomName);
    console.log(`${userId} joined room ${roomName}`);

    // const room = io.sockets.adapter.rooms.get(roomName);
    // console.log(`Users in room ${roomName}:`, room ? room.size : 0);
  });

  socket.on('sendMessage', async (data) => {
    try {
      const { sender, receiver, message } = data;
      
      // Save message and get the MongoDB generated _id
      const newMessage = new Message({ sender, receiver, message });
      await newMessage.save();

      // Create room name
      const roomName = [sender, receiver].sort().join('_');

      // Include the MongoDB _id in the response
      io.to(roomName).emit('receiveMessage', {
        _id: newMessage._id,
        sender,
        receiver,
        message
      });

      // Tìm FCM token của người nhận
      const user = await User.findById(receiver);
  
      if (user && user.fcmToken) {
        // Gửi thông báo FCM
        const payload = {
          token: user.fcmToken,
          notification: {
            title: `New message from ${user.username}`,
            body: message,
          },
          android: {


            collapseKey: `chat_${receiver}`, // Hợp nhất thông báo theo người nhận
            notification: {
              tag: `user_${sender}`, // Gộp theo người gửi
            },
          },
        };
        
  
        // Sử dụng admin.messaging().send
        const response = await admin.messaging().send(payload);
        console.log('Notification sent successfully:', response);
      }
    } catch (err) {
      console.error('Error handling sendMessage:', err);
    }
  });

  socket.on('leaveRoom', ({ userId, friendId }) => {
    const roomName = [userId, friendId].sort().join('_');
    socket.leave(roomName);
    console.log(`${userId} left room ${roomName}`);
  });

  // Tham gia phòng nhóm
  socket.on('joinGroup', ({ groupId }) => {
    console.log(`User joined group ${groupId}`);
    socket.join(groupId);
  });

    // Tham gia phòng nhóm
    socket.on('leaveGroup', ({ groupId }) => {
      console.log(`User leave group ${groupId}`);
      socket.leave(groupId);
    });

  // Xử lý gửi tin nhắn nhóm
  socket.on('sendGroupMessage', async ({ groupId, sender, message }) => {
    try {
      // Lưu tin nhắn vào cơ sở dữ liệu
      const groupMessage = new GroupMessage({ groupId, sender, message });
      await groupMessage.save();

      // Get sender's username and group details
      const senderUser = await User.findById(sender);
      const senderName = senderUser ? senderUser.username : 'Unknown';
      const group = await Group.findById(groupId);
      // Phát tin nhắn tới tất cả thành viên trong nhóm
      io.to(groupId).emit('receiveGroupMessage', {
        groupId,
        sender,
        senderName,
        message,
        timestamp: groupMessage.timestamp,
      });

      // Send push notification to all group members
      if (group && group.members) {
        const members = await User.find({ _id: { $in: group.members, $ne: sender } });
        
        for (const member of members) {
          if (member.fcmToken) {
            const payload = {
              token: member.fcmToken,
              notification: {
                title: `${group.name}`,
                body: `${senderName}: ${message}`,
              },
              android: {
                collapseKey: `group_${groupId}`,
                notification: {
                  tag: `group_${groupId}`,
                },
              },
            };
            try {
              await admin.messaging().send(payload);
            } catch (err) {
              console.error('Error sending notification to member:', err);
            }
          }
        }
      }
    } catch (err) {
      console.error('Error sending group message:', err);
    }
  });
  
  socket.on('recallMessage', async (data) => {
    try {
      const { messageId, sender, receiver } = data;
      const message = await Message.findById(messageId);
      
      if (!message) {
        console.error('Message not found:', messageId);
        return;
      }

      // Update message in database
      await Message.findByIdAndUpdate(messageId, { isRecalled: true });
      
      // Send recall event to both sender and receiver
      const roomName = [sender, receiver].sort().join('_');
      io.to(roomName).emit('messageRecalled', { 
        messageId,
        isRecalled: true,
        timestamp: new Date()
      });

    } catch (err) {
      console.error('Error recalling message:', err);
    }
  });

  socket.on('recallGroupMessage', async (data) => {
    try {
      const { messageId, groupId } = data;
      const message = await GroupMessage.findById(messageId);
      
      if (!message) {
        console.error('Group message not found:', messageId);
        return;
      }

      // Update message in database
      await GroupMessage.findByIdAndUpdate(messageId, { isRecalled: true });
      
      // Send recall event to group
      io.to(groupId).emit('groupMessageRecalled', { 
        messageId,
        isRecalled: true,
        timestamp: new Date()
      });

    } catch (err) {
      console.error('Error recalling group message:', err);
    }
  });

  socket.on('disconnect', () => {
    console.log('Client disconnected');
  });

  
});

// Start server
server.listen(3000, '0.0.0.0', () => console.log('Server is running on :3000'));
