const express = require('express');
const router = express.Router();
const User = require('../models/User');
const admin = require('firebase-admin');

router.post('/call', async (req, res) => {
  try {
    console.log('Received call notification request:', req.body);
    const { receiverId, callerId, type } = req.body;

    // Validate input
    if (!receiverId || !callerId) {
      return res.status(400).json({ error: 'Missing required parameters' });
    }

    // Get receiver and caller info
    const [receiver, caller] = await Promise.all([
      User.findById(receiverId),
      User.findById(callerId)
    ]);

    if (!receiver || !receiver.fcmToken) {
      return res.status(404).json({ error: 'Receiver not found or has no FCM token' });
    }

    // Create notification payload
    const payload = {
      token: receiver.fcmToken,
      data: {
        type: 'video_call',
        callerId: callerId,
        callerName: caller ? caller.username : 'Unknown',
        channelName: [callerId, receiverId].sort().join('_'),
      },
      notification: {
        title: 'Incoming Video Call',
        body: `${caller ? caller.username : 'Someone'} is calling you`,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'call_channel',
          priority: 'high',
        },
      },
    };

    // Send notification
    const response = await admin.messaging().send(payload);
    console.log('Call notification sent successfully:', response);

    res.json({ success: true, messageId: response });
  } catch (error) {
    console.error('Error sending call notification:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
