const express = require('express');
const Group = require('../models/Group');
const GroupMessage = require('../models/GroupMessage');
const multer = require('multer');
const upload = multer({ dest: 'temp/' });
const User = require('../models/User');
const router = express.Router();

const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

// Tạo nhóm
router.post('/create', async (req, res) => {
  const { name, ownerId } = req.body;

  try {

    console.log(name);
    console.log(ownerId);
    const group = new Group({
      name,
      owner: ownerId,
      members: [ownerId], // Người tạo tự động là thành viên
    });



    await group.save();
    res.status(201).send(group);
  } catch (err) {
    console.error('Error creating group:', err);
    res.status(500).send({ error: 'Failed to create group' });
  }
  
});

router.post('/add-member', async (req, res) => {
  const { groupId, userId } = req.body;

  try {
    const group = await Group.findById(groupId);

    if (!group) {
      return res.status(404).send({ error: 'Group not found' });
    }

    if (group.members.includes(userId)) {
      return res.status(400).send({ error: 'User is already a member of the group' });
    }

    group.members.push(userId);
    await group.save();

    // Phát sự kiện socket để cập nhật danh sách nhóm
    const io = req.app.get('socketio');
    io.to(userId).emit('updateGroups'); // Phát sự kiện tới người dùng được thêm vào nhóm
    io.to(group.owner.toString()).emit('updateGroups'); // Thông báo tới chủ sở hữu nhóm (nếu cần)

    res.send('Member added successfully');
  } catch (err) {
    console.error('Error adding member:', err);
    res.status(500).send({ error: 'Failed to add member' });
  }
});

// Add new endpoint for updating group avatar
router.post('/update-avatar/:groupId', upload.single('avatar'), async (req, res) => {
  try {
    const { groupId } = req.params;
    const file = req.file;

    if (!file) {
      return res.status(400).send({ error: 'No file uploaded' });
    }

    const drive = req.app.get('googleDrive');
    const fileMetadata = {
      name: `group_${groupId}_avatar.jpg`,
      parents: ['1uoKXq4MXKEpEMT3_Fwdtttm84AIpq-h0'] // Your base folder ID
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
    
    await Group.findByIdAndUpdate(groupId, { avatar: avatarUrl });

    // Cleanup temp file
    fs.unlinkSync(file.path);

    res.json({ avatarUrl });
  } catch (err) {
    console.error('Error updating group avatar:', err);
    res.status(500).send({ error: 'Failed to update avatar' });
  }
});

// Lấy danh sách nhóm của người dùng
router.get('/user-groups/:userId', async (req, res) => {
    const { userId } = req.params;
  
    try {
      const groups = await Group.find({
        members: userId,
      });
  
      res.send(groups);
    } catch (err) {
      console.error('Error fetching groups:', err);
      res.status(500).send({ error: 'Failed to fetch groups' });
    }
  });

  // Lấy tin nhắn của nhóm
router.get('/group-messages/:groupId', async (req, res) => {
  const { groupId } = req.params;
  const { page = 1, limit = 20 } = req.query;

  try {
    const messages = await GroupMessage.find({ groupId })
      .populate('sender', 'username')
      .sort({ timestamp: -1 }) // Sort in descending order (newest first)
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .select('message sender timestamp isRecalled type');

    const totalMessages = await GroupMessage.countDocuments({ groupId });

    res.send({
      messages: messages.reverse(), // Reverse back to ascending order
      totalMessages,
      currentPage: parseInt(page),
      totalPages: Math.ceil(totalMessages / limit)
    });
  } catch (err) {
    console.error('Error fetching group messages:', err);
    res.status(500).send({ error: 'Failed to fetch group messages' });
  }
});

// Add this route handler
router.get('/members/:groupId', async (req, res) => {
  try {
    const group = await Group.findById(req.params.groupId);
    if (!group) {
      return res.status(404).json({ message: 'Group not found' });
    }

    // Fetch member details including avatars
    const members = await User.find(
      { _id: { $in: group.members } },
      { _id: 1, username: 1, avatar: 1 }
    );

    res.json(members);
  } catch (error) {
    console.error('Error fetching group members:', error);
    res.status(500).json({ message: 'Error fetching group members', error: error.message });
  }
});

router.post('/initialize-call', async (req, res) => {
  try {
    console.log('Initializing call for group:', req.body.groupId);
    
    const { groupId } = req.body;
    if (!groupId) {
      return res.status(400).json({ error: 'Group ID is required' });
    }

    // Your Agora app credentials
    const appID = 'a4071bedee5f48ea91a1bed0a3bb7486';
    const appCertificate = 'a6f0c1accdab4aca9ca9a4c7d341d2e3';
    const channelName = groupId;
    const uid = 0;
    const role = RtcRole.PUBLISHER;
    
    const expirationTimeInSeconds = 3600;
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

    // Generate token
    const token = RtcTokenBuilder.buildTokenWithUid(
      appID,
      appCertificate,
      channelName,
      uid,
      role,
      privilegeExpiredTs
    );

    console.log('Token generated successfully for group:', groupId);
    res.json({ token });
  } catch (error) {
    console.error('Error initializing call:', error);
    res.status(500).json({ error: 'Failed to initialize call' });
  }
});

router.post('/notify-call', async (req, res) => {
  try {
    const { groupId, initiatorId } = req.body;
    const group = await Group.findById(groupId);
    
    if (!group) {
      return res.status(404).json({ error: 'Group not found' });
    }

    // Get initiator details
    const initiator = await User.findById(initiatorId);
    if (!initiator) {
      return res.status(404).json({ error: 'Initiator not found' });
    }

    // Notify all group members except initiator
    const io = req.app.get('socketio');
    group.members.forEach(memberId => {
      if (memberId.toString() !== initiatorId) {
        io.to(memberId.toString()).emit('groupCallStarted', {
          groupId,
          initiatorName: initiator.username,
          groupName: group.name
        });
      }
    });

    res.json({ success: true });
  } catch (error) {
    console.error('Error notifying members:', error);
    res.status(500).json({ error: 'Failed to notify members' });
  }
});

router.post('/call-ended', async (req, res) => {
  try {
    const { groupId, message } = req.body;
    
    // Create a system message for call ended
    const systemMessage = new GroupMessage({
      groupId,
      message,
      type: 'system',
      sender: null,
      timestamp: new Date()
    });

    await systemMessage.save();

    // Notify group members that call has ended
    const io = req.app.get('socketio');
    io.to(groupId).emit('receiveGroupMessage', {
      message,
      type: 'system',
      timestamp: systemMessage.timestamp,
      sender: 'System'
    });

    res.json({ success: true });
  } catch (error) {
    console.error('Error handling call end:', error);
    res.status(500).json({ error: 'Failed to handle call end' });
  }
});

module.exports = router;
