const express = require('express');
const Message = require('../models/Message');

const router = express.Router();

// Lấy tin nhắn cũ giữa hai người
router.get('/messages/:sender/:receiver', async (req, res) => {
  const { sender, receiver } = req.params;
  try {
    // Kiểm tra các tham số có hợp lệ không
    if (!sender || !receiver) {
      return res.status(400).send({ error: 'Sender and receiver are required' });
    }

    const messages = await Message.find({
      $or: [
        { sender, receiver },
        { sender: receiver, receiver: sender },
      ],
    }).select('sender receiver message timestamp isRecalled').sort({ timestamp: 1 }); // Sắp xếp tin nhắn theo thời gian tăng dần

    res.status(200).send(messages);
  } catch (err) {
    console.error('Failed to fetch messages:', err);
    res.status(500).send({ error: 'Failed to fetch messages' });
  }
});

module.exports = router;
