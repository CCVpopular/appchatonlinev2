const express = require('express');
const router = express.Router();
const User = require('../models/User');
const admin = require('firebase-admin');

// Test route to verify the router is working
router.get('/test', (req, res) => {
  res.json({ message: 'Notification routes are working' });
});

// Video call notification endpoint
router.post('/call', async (req, res) => {
  try {
    console.log('Received call request:', req.body);
    const { receiverId, callerId, type } = req.body;

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

    // Create channel name
    const channelName = [callerId, receiverId].sort().join('_');

    // Create notification payload
    const payload = {
      token: receiver.fcmToken,
      data: {
        type: 'video_call',
        callerId: callerId,
        callerName: caller ? caller.username : 'Unknown',
        channelName: channelName,
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

    // Send FCM notification
    const response = await admin.messaging().send(payload);
    console.log('Call notification sent successfully:', response);

    res.json({ 
      success: true, 
      channelName,
      messageId: response 
    });
  } catch (error) {
    console.error('Error sending call notification:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
