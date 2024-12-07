const express = require('express');
const User = require('../models/User');

const router = express.Router();

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

module.exports = router;
