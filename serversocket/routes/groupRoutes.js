const express = require('express');
const Group = require('../models/Group');
const GroupMessage = require('../models/GroupMessage');
const multer = require('multer');
const upload = multer({ dest: 'temp/' });
const User = require('../models/User');
const router = express.Router();

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

  try {
    const messages = await GroupMessage.find({ groupId })
      .populate('sender', 'username') // Lấy tên người gửi
      .sort({ timestamp: 1 }) // Sắp xếp tin nhắn theo thời gian
      .select('message sender timestamp isRecalled type'); // Add type to selection

    res.send(messages);
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

module.exports = router;
