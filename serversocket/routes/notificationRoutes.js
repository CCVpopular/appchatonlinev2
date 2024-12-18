const express = require('express');
const router = express.Router();
const User = require('../models/User');
const admin = require('firebase-admin');
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

// Test route to verify the router is working
router.get('/test', (req, res) => {
  res.json({ message: 'Notification routes are working' });
});

const generateAgoraToken = (channelName) => {
  const appId = 'a4071bedee5f48ea91a1bed0a3bb7486';
  const appCertificate = 'a6f0c1accdab4aca9ca9a4c7d341d2e3'; // Get this from Agora Console
  const uid = 0;
  const role = RtcRole.PUBLISHER;
  const expirationTimeInSeconds = 3600;
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

  return RtcTokenBuilder.buildTokenWithUid(
    appId,
    appCertificate,
    channelName,
    uid,
    role,
    privilegeExpiredTs
  );
};

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

    // Generate Agora token
    const agoraToken = generateAgoraToken(channelName);

    // Create notification payload
    const payload = {
      token: receiver.fcmToken,
      data: {
        type: 'video_call',
        callerId: callerId,
        callerName: caller ? caller.username : 'Unknown',
        channelName: channelName,
        token: agoraToken,
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
      token: agoraToken,
      messageId: response 
    });
  } catch (error) {
    console.error('Error sending call notification:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
