const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const mongoose = require('mongoose');
const Message = require('./models/Message');
const GroupMessage = require('./models/GroupMessage');
const User = require('./models/User');
const Group = require('./models/Group');
const notificationRoutes = require('./routes/notificationRoutes')
const authRoutes = require('./routes/authRoutes');
const friendRoutes = require('./routes/friendRoutes');
const messageRoutes = require('./routes/messageRoutes');
const groupRoutes = require('./routes/groupRoutes');
const userRoutes = require('./routes/userRoutes');
const { google } = require('googleapis');

const multer = require('multer');
const path = require('path');
const fs = require('fs');

const { encrypt, decrypt } = require('./utils/encryption');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  maxHttpBufferSize: 500 * 1024 * 1024,
});

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

// Add after the getGroupImageFolderId function
async function getFileFolderId(baseFolder, roomName) {
  try {
    const chatFolder = await findOrCreateFolder('chat', baseFolder);
    const privateChatFolder = await findOrCreateFolder('private_chat', chatFolder);
    const roomFolder = await findOrCreateFolder(roomName, privateChatFolder);
    const fileChatFolder = await findOrCreateFolder('filechat', roomFolder);
    
    return fileChatFolder;
  } catch (error) {
    console.error('Error in getFileFolderId:', error);
    throw error;
  }
}

// Add after the getFileFolderId function
async function getGroupFileFolderId(baseFolder, groupId) {
  try {
    const chatFolder = await findOrCreateFolder('chat', baseFolder);
    const groupChatFolder = await findOrCreateFolder('group_chat', chatFolder);
    const roomFolder = await findOrCreateFolder(groupId, groupChatFolder);
    const fileChatFolder = await findOrCreateFolder('filechat', roomFolder);
    
    return fileChatFolder;
  } catch (error) {
    console.error('Error in getGroupFileFolderId:', error);
    throw error;
  }
}

// Multer setup for temporary file storage
const upload = multer({
  dest: 'temp/',
  limits: { 
    fileSize: 500 * 1024 * 1024, // 500MB limit
    files: 1
  }
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
app.use(express.json({ limit: '500mb' }));
app.use(express.urlencoded({ extended: true, limit: '500mb' }));

// Add console logging middleware to debug requests
app.use((req, res, next) => {
  console.log(`${req.method} ${req.url}`);
  next();
});

// Routes
app.use('/api/messages', messageRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/friends', friendRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/users', userRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/groups', groupRoutes);
// Add error handling middleware

app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({ error: err.message });
});

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
      
      // Encrypt message before saving
      const encryptedMessage = encrypt(message);
      const newMessage = new Message({ sender, receiver, message: encryptedMessage });
      await newMessage.save();

      const roomName = [sender, receiver].sort().join('_');

      // Decrypt message before sending
      io.to(roomName).emit('receiveMessage', {
        _id: newMessage._id,
        sender,
        receiver,
        message: message // Send original message to client
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

      // Emit latest message update to both users
      const latestMessageData = {
        friendId: sender,
        message: message,
        timestamp: new Date(),
        type: 'text',
        isRecalled: false
      };
      
      // Emit to receiver
      io.to(receiver).emit('latestMessage', {
        ...latestMessageData,
        friendId: sender
      });
      
      // Emit to sender
      io.to(sender).emit('latestMessage', {
        ...latestMessageData,
        friendId: receiver
      });

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

      // Emit latest message update for image
      const latestMessageData = {
        friendId: sender,
        message: '[Image]',
        timestamp: new Date(),
        type: 'image',
        isRecalled: false
      };
      
      io.to(receiver).emit('latestMessage', {
        ...latestMessageData,
        friendId: sender
      });
      
      io.to(sender).emit('latestMessage', {
        ...latestMessageData,
        friendId: receiver
      });

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

  socket.on('sendFile', async (data) => {
    try {
      const { sender, receiver, fileData, fileName, fileType } = data;
      const tempPath = path.join(__dirname, 'temp', fileName);
      
      // Save base64 file to temp storage
      fs.writeFileSync(tempPath, Buffer.from(fileData, 'base64'));

      // Get room-specific folder ID
      const roomName = [sender, receiver].sort().join('_');
      const baseFolderId = '1uoKXq4MXKEpEMT3_Fwdtttm84AIpq-h0'; // Your base folder ID
      const roomFolderId = await getFileFolderId(baseFolderId, roomName);

      // Upload to Google Drive
      const fileMetadata = {
        name: fileName,
        parents: [roomFolderId]
      };

      const media = {
        mimeType: fileType,
        body: fs.createReadStream(tempPath)
      };

      const driveResponse = await drive.files.create({
        resource: fileMetadata,
        media: media,
        fields: 'id, webViewLink'
      });

      // Save message with file info
      const newMessage = new Message({
        sender,
        receiver,
        message: JSON.stringify({
          fileName,
          fileId: driveResponse.data.id,
          viewLink: driveResponse.data.webViewLink
        }),
        type: 'file'
      });
      await newMessage.save();

      // Emit to room
      io.to(roomName).emit('receiveMessage', {
        _id: newMessage._id,
        sender,
        receiver,
        message: newMessage.message,
        type: 'file',
        timestamp: newMessage.timestamp
      });

      // Cleanup temp file
      fs.unlinkSync(tempPath);

      // Emit latest message update for file
      const latestMessageData = {
        friendId: sender,
        message: `[File: ${fileName}]`,
        timestamp: new Date(),
        type: 'file',
        isRecalled: false
      };
      
      io.to(receiver).emit('latestMessage', {
        ...latestMessageData,
        friendId: sender
      });
      
      io.to(sender).emit('latestMessage', {
        ...latestMessageData,
        friendId: receiver
      });

    } catch (err) {
      console.error('Error handling file upload:', err);
    }
  });

  socket.on('sendGroupFile', async (data) => {
    try {
      const { groupId, sender, fileData, fileName, fileType } = data;
      const tempPath = path.join(__dirname, 'temp', fileName);
      
      // Save base64 file to temp storage
      fs.writeFileSync(tempPath, Buffer.from(fileData, 'base64'));

      // Get folder ID for group files
      const baseFolderId = '1uoKXq4MXKEpEMT3_Fwdtttm84AIpq-h0'; // Your base folder ID
      const groupFolderId = await getGroupFileFolderId(baseFolderId, groupId);

      // Upload to Google Drive
      const fileMetadata = {
        name: fileName,
        parents: [groupFolderId]
      };

      const media = {
        mimeType: fileType,
        body: fs.createReadStream(tempPath)
      };

      const driveResponse = await drive.files.create({
        resource: fileMetadata,
        media: media,
        fields: 'id, webViewLink'
      });

      // Save message with file info
      const groupMessage = new GroupMessage({
        groupId,
        sender,
        message: JSON.stringify({
          fileName,
          fileId: driveResponse.data.id,
          viewLink: driveResponse.data.webViewLink
        }),
        type: 'file'
      });
      await groupMessage.save();

      // Get sender's username
      const senderUser = await User.findById(sender);
      const senderName = senderUser ? senderUser.username : 'Unknown';

      // Emit to group
      io.to(groupId).emit('receiveGroupMessage', {
        groupId,
        sender,
        senderName,
        message: groupMessage.message,
        type: 'file',
        timestamp: groupMessage.timestamp
      });

      // Cleanup temp file
      fs.unlinkSync(tempPath);

    } catch (err) {
      console.error('Error handling group file upload:', err);
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
      // Encrypt group message
      const encryptedMessage = encrypt(message);
      const groupMessage = new GroupMessage({ 
        groupId, 
        sender, 
        message: encryptedMessage 
      });
      await groupMessage.save();

      const senderUser = await User.findById(sender);
      const senderName = senderUser ? senderUser.username : 'Unknown';
      const group = await Group.findById(groupId);

      // Send original (unencrypted) message to clients
      io.to(groupId).emit('receiveGroupMessage', {
        _id: groupMessage._id,
        groupId,
        sender,
        senderName,
        message: message, // Send original message
        timestamp: groupMessage.timestamp
      });

      // Add latest message update for groups
      const latestMessageData = {
        groupId,
        message: message,
        timestamp: new Date(),
        type: 'text',
        isRecalled: false
      };

      // Emit to all group members
      io.to(groupId).emit('latestGroupMessage', latestMessageData);

      // Handle notifications
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

      // Emit latest message update for recalled message
      const latestMessageData = {
        friendId: sender,
        message: 'Message recalled',
        timestamp: new Date(),
        type: 'text',
        isRecalled: true
      };
      
      io.to(receiver).emit('latestMessage', {
        ...latestMessageData,
        friendId: sender
      });
      
      io.to(sender).emit('latestMessage', {
        ...latestMessageData,
        friendId: receiver
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
      
      // Send recall event to group with all necessary data
      io.to(groupId).emit('groupMessageRecalled', { 
        messageId,
        groupId,
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
