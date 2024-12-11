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

const { google } = require('googleapis');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const app = express();
const server = http.createServer(app);
const io = socketIo(server);

const admin = require('firebase-admin');

const serviceAccount = require('./key/app-chat-push-notification.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// Google Drive Setup
const auth = new google.auth.GoogleAuth({
  keyFile: './key/app-chat-push-notification.json',
  scopes: ['https://www.googleapis.com/auth/drive.file'],
});

const drive = google.drive({ version: 'v3', auth });

// Add these helper functions after drive initialization
async function findOrCreateFolder(folderName, parentId) {
  try {
    // Search for existing folder
    const response = await drive.files.list({
      q: `name='${folderName}' and mimeType='application/vnd.google-apps.folder' and '${parentId}' in parents and trashed=false`,
      fields: 'files(id)',
    });

    if (response.data.files.length > 0) {
      return response.data.files[0].id;
    }

    // Create new folder if not found
    const fileMetadata = {
      name: folderName,
      mimeType: 'application/vnd.google-apps.folder',
      parents: [parentId]
    };

    const folder = await drive.files.create({
      resource: fileMetadata,
      fields: 'id'
    });

    return folder.data.id;
  } catch (error) {
    console.error('Error in findOrCreateFolder:', error);
    throw error;
  }
}

async function getImageFolderId(baseFolder, roomName) {
  try {
    // Create folder hierarchy
    const chatFolder = await findOrCreateFolder('chat', baseFolder);
    const privateChatFolder = await findOrCreateFolder('private_chat', chatFolder);
    const roomFolder = await findOrCreateFolder(roomName, privateChatFolder);
    const imageChatFolder = await findOrCreateFolder('imagechat', roomFolder);
    
    return imageChatFolder;
  } catch (error) {
    console.error('Error in getImageFolderId:', error);
    throw error;
  }
}

async function getGroupImageFolderId(baseFolder, groupId) {
  try {
    const chatFolder = await findOrCreateFolder('chat', baseFolder);
    const groupChatFolder = await findOrCreateFolder('group_chat', chatFolder);
    const roomFolder = await findOrCreateFolder(groupId, groupChatFolder);
    const imageChatFolder = await findOrCreateFolder('imagechat', roomFolder);
    
    return imageChatFolder;
  } catch (error) {
    console.error('Error in getGroupImageFolderId:', error);
    throw error;
  }
}

// Multer setup for temporary file storage
const upload = multer({
  dest: 'temp/',
  limits: { fileSize: 5 * 1024 * 1024 } // 5MB limit
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

  // Replace the existing socket.on('sendImage') with this updated version
  socket.on('sendImage', async (data) => {
    try {
      const { sender, receiver, imageData, fileName } = data;
      const tempPath = path.join(__dirname, 'temp', fileName);
      
      // Save base64 image to temp file
      fs.writeFileSync(tempPath, Buffer.from(imageData, 'base64'));

      // Get room-specific folder ID
      const roomName = [sender, receiver].sort().join('_');
      const baseFolderId = '1uoKXq4MXKEpEMT3_Fwdtttm84AIpq-h0'; // Your base folder ID
      const roomFolderId = await getImageFolderId(baseFolderId, roomName);

      // Upload to Google Drive in room-specific folder
      const fileMetadata = {
        name: fileName,
        parents: [roomFolderId]
      };

      const media = {
        mimeType: 'image/jpeg',
        body: fs.createReadStream(tempPath)
      };

      const driveResponse = await drive.files.create({
        resource: fileMetadata,
        media: media,
        fields: 'id'
      });

      const directViewUrl = `https://drive.google.com/uc?export=view&id=${driveResponse.data.id}`;

      // Save message with direct view URL
      const newMessage = new Message({
        sender,
        receiver,
        message: directViewUrl,
        type: 'image'
      });
      await newMessage.save();

      // Emit to room and cleanup
      io.to(roomName).emit('receiveMessage', {
        _id: newMessage._id,
        sender,
        receiver,
        message: directViewUrl,
        type: 'image',
        timestamp: new Date()
      });

      fs.unlinkSync(tempPath);

    } catch (err) {
      console.error('Error handling image upload:', err);
    }
  });

  socket.on('sendGroupImage', async (data) => {
    try {
      const { groupId, sender, imageData, fileName } = data;
      const tempPath = path.join(__dirname, 'temp', fileName);
      
      // Save base64 image to temp file
      fs.writeFileSync(tempPath, Buffer.from(imageData, 'base64'));

      // Get folder ID for group images
      const baseFolderId = '1uoKXq4MXKEpEMT3_Fwdtttm84AIpq-h0'; // Your base folder ID
      const groupFolderId = await getGroupImageFolderId(baseFolderId, groupId);

      // Upload to Google Drive
      const fileMetadata = {
        name: fileName,
        parents: [groupFolderId]
      };

      const media = {
        mimeType: 'image/jpeg',
        body: fs.createReadStream(tempPath)
      };

      const driveResponse = await drive.files.create({
        resource: fileMetadata,
        media: media,
        fields: 'id'
      });

      const directViewUrl = `https://drive.google.com/uc?export=view&id=${driveResponse.data.id}`;

      // Save message with image URL
      const groupMessage = new GroupMessage({
        groupId,
        sender,
        message: directViewUrl,
        type: 'image'
      });
      await groupMessage.save();

      // Get sender's username
      const senderUser = await User.findById(sender);
      const senderName = senderUser ? senderUser.username : 'Unknown';

      // Emit to group and cleanup
      io.to(groupId).emit('receiveGroupMessage', {
        groupId,
        sender,
        senderName,
        message: directViewUrl,
        type: 'image',
        timestamp: groupMessage.timestamp
      });

      fs.unlinkSync(tempPath);

    } catch (err) {
      console.error('Error handling group image upload:', err);
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
