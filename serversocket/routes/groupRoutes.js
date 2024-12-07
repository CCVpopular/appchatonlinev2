const express = require('express');
const Group = require('../models/Group');
const GroupMessage = require('../models/GroupMessage');

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
      .sort({ timestamp: 1 }); // Sắp xếp tin nhắn theo thời gian

    res.send(messages);
  } catch (err) {
    console.error('Error fetching group messages:', err);
    res.status(500).send({ error: 'Failed to fetch group messages' });
  }
});
  

module.exports = router;
