const express = require('express');
const Message = require('../models/Message');
const router = express.Router();

// Update the messages route to support pagination
router.get('/messages/:sender/:receiver', async (req, res) => {
  const { sender, receiver } = req.params;
  const { page = 1, limit = 20 } = req.query;
  
  try {
    if (!sender || !receiver) {
      return res.status(400).send({ error: 'Sender and receiver are required' });
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const messages = await Message.find({
      $or: [
        { sender, receiver },
        { sender: receiver, receiver: sender },
      ],
    })
    .select('sender receiver message timestamp isRecalled type')
    .sort({ timestamp: -1 }) // Sort by newest first
    .skip(skip)
    .limit(parseInt(limit));

    const total = await Message.countDocuments({
      $or: [
        { sender, receiver },
        { sender: receiver, receiver: sender },
      ],
    });

    res.status(200).send({
      messages: messages.reverse(), // Reverse to show oldest first
      total,
      hasMore: skip + messages.length < total
    });
  } catch (err) {
    console.error('Failed to fetch messages:', err);
    res.status(500).send({ error: 'Failed to fetch messages' });
  }
});

module.exports = router;
