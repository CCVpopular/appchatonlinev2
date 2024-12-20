const express = require('express');
const mongoose = require('mongoose');
const Message = require('../models/Message');
const { decrypt } = require('../utils/encryption');
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

    // Decrypt messages before sending
    const decryptedMessages = messages.map(msg => ({
      ...msg._doc,
      message: msg.isRecalled ? msg.message : decrypt(msg.message)
    }));

    res.status(200).send({
      messages: decryptedMessages.reverse(), // Reverse to show oldest first
      total,
      hasMore: skip + messages.length < total
    });
  } catch (err) {
    console.error('Failed to fetch messages:', err);
    res.status(500).send({ error: 'Failed to fetch messages' });
  }
});

router.get('/group-messages/:groupId', async (req, res) => {
  const { groupId } = req.params;
  const { page = 1, limit = 20 } = req.query;

  try {
    const messages = await GroupMessage.find({ groupId })
      .populate('sender', 'username')
      .sort({ timestamp: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .select('message sender timestamp isRecalled type');

    // Decrypt group messages
    const decryptedMessages = messages.map(msg => ({
      ...msg._doc,
      message: msg.isRecalled ? msg.message : decrypt(msg.message)
    }));

    res.send({
      messages: decryptedMessages.reverse(),
      totalMessages: await GroupMessage.countDocuments({ groupId }),
      currentPage: parseInt(page),
      totalPages: Math.ceil(totalMessages / limit)
    });
  } catch (err) {
    console.error('Error fetching group messages:', err);
    res.status(500).send({ error: 'Failed to fetch group messages' });
  }
});

// Update the route path to match the frontend request
router.get('/latest-messages/:userId', async (req, res) => {
  const { userId } = req.params;
  
  try {
    const latestMessages = await Message.aggregate([
      {
        $match: {
          $or: [
            { sender: new mongoose.Types.ObjectId(userId) },
            { receiver: new mongoose.Types.ObjectId(userId) }
          ]
        }
      },
      {
        $sort: { timestamp: -1 }
      },
      {
        $group: {
          _id: {
            $cond: {
              if: { $eq: ["$sender", new mongoose.Types.ObjectId(userId)] },
              then: "$receiver",
              else: "$sender"
            }
          },
          message: { $first: "$message" },
          timestamp: { $first: "$timestamp" },
          type: { $first: "$type" },
          isRecalled: { $first: "$isRecalled" }
        }
      },
      {
        $project: {
          friendId: { $toString: "$_id" },
          message: 1,
          timestamp: 1,
          type: 1,
          isRecalled: 1,
          _id: 0
        }
      }
    ]);

    // Decrypt messages before sending
    const decryptedMessages = latestMessages.map(msg => ({
      ...msg,
      message: msg.isRecalled ? msg.message : decrypt(msg.message)
    }));

    console.log('Latest messages:', decryptedMessages);
    res.status(200).send(decryptedMessages);
  } catch (err) {
    console.error('Failed to fetch latest messages:', err);
    res.status(500).send({ error: 'Failed to fetch latest messages' });
  }
});

module.exports = router;
