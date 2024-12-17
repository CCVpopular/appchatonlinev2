const express = require('express');
const User = require('../models/User');

const router = express.Router();

const multer = require('multer');
const { google } = require('googleapis');
const fs = require('fs');
const path = require('path');

// Configure Google Drive
const auth = new google.auth.GoogleAuth({
  keyFile: './key/app-chat-push-notification.json',
  scopes: ['https://www.googleapis.com/auth/drive.file'],
});
const drive = google.drive({ version: 'v3', auth });

const upload = multer({ dest: 'temp/' });

// Tìm kiếm người dùng theo tên
router.get('/search/:username', async (req, res) => {
  const { username } = req.params;
  try {
    // Tìm kiếm người dùng có tên chứa đoạn text (không phân biệt hoa thường)
    const users = await User.find({
      username: { $regex: username, $options: 'i' }, // $regex cho phép tìm kiếm gần đúng
    }).select('_id username'); // Chỉ lấy _id và username

    res.send(users);
  } catch (err) {
    console.error('Error searching users:', err);
    res.status(500).send({ error: 'Failed to search users' });
  }
});

// API để lưu FCM Token
router.post('/save-fcm-token', async (req, res) => {
  const { userId, fcmToken } = req.body;

  try {
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).send({ error: 'User not found' });
    }

    user.fcmToken = fcmToken; // Cập nhật token
    await user.save();

    res.send({ message: 'FCM Token saved successfully' });
  } catch (err) {
    console.error('Error saving FCM Token:', err);
    res.status(500).send({ error: 'Failed to save FCM Token' });
  }
});

// Upload avatar endpoint
router.post('/upload-avatar', upload.single('avatar'), async (req, res) => {
  try {
    const { userId } = req.body;
    const file = req.file;

    const fileMetadata = {
      name: `avatar_${userId}_${Date.now()}.jpg`,
      parents: ['1uoKXq4MXKEpEMT3_Fwdtttm84AIpq-h0'] // Your Google Drive folder ID
    };

    const media = {
      mimeType: 'image/jpeg',
      body: fs.createReadStream(file.path)
    };

    const driveResponse = await drive.files.create({
      resource: fileMetadata,
      media: media,
      fields: 'id'
    });

    const avatarUrl = `https://drive.google.com/uc?export=view&id=${driveResponse.data.id}`;
    
    // Update user's avatar URL
    await User.findByIdAndUpdate(userId, { avatar: avatarUrl });

    // Cleanup temp file
    fs.unlinkSync(file.path);

    res.json({ avatarUrl });
  } catch (err) {
    console.error('Error uploading avatar:', err);
    res.status(500).send({ error: 'Failed to upload avatar' });
  }
});

// Get user profile endpoint
router.get('/profile/:userId', async (req, res) => {
  try {
    const user = await User.findById(req.params.userId).select('username avatar');
    if (!user) {
      return res.status(404).send({ error: 'User not found' });
    }
    res.json(user);
  } catch (err) {
        res.status(500).send({ error: 'Failed to get user profile' });
      }
    });
// Get all users
router.get('/', async (req, res) => {
  try {
    const users = await User.find().select('-password');
    res.json(users);
  } catch (err) {
    res.status(500).send({ error: 'Failed to fetch users' });
  }
});

// Create new user
router.post('/', async (req, res) => {
  try {
    const { username, password, role } = req.body;
    const hashedPassword = await bcrypt.hash(password, 10);
    const user = new User({ username, password: hashedPassword, role });
    await user.save();
    res.status(201).json({ message: 'User created successfully', user: { ...user.toJSON(), password: undefined } });
  } catch (err) {
    res.status(500).send({ error: 'Failed to create user' });
  }
});

// Update user
router.put('/:id', async (req, res) => {
  try {
    const { username, role, status } = req.body;
    const user = await User.findByIdAndUpdate(
      req.params.id,
      { username, role, status },
      { new: true }
    ).select('-password');
    res.json(user);
  } catch (err) {
    res.status(500).send({ error: 'Failed to update user' });
  }
});

module.exports = router;