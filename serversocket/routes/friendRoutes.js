const express = require('express');
const Friendship = require('../models/Friendship');

const router = express.Router();

router.get('/friend-requests/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    const requests = await Friendship.find({
      receiver: userId,
      status: 'pending',
    }).populate('requester', 'username'); // Lấy tên của người gửi yêu cầu

    res.send(requests);
  } catch (err) {
    console.error('Error fetching friend requests:', err);
    res.status(500).send({ error: 'Failed to fetch friend requests' });
  }
});


// Kết bạn
router.post('/add-friend', async (req, res) => {
  const { requesterId, receiverId } = req.body;
  const existingRequest = await Friendship.findOne({
    $or: [
      { requester: requesterId, receiver: receiverId },
      { requester: receiverId, receiver: requesterId }
    ],
    status: 'pending'
  });
  
  if (existingRequest) {
    return res.status(400).send({ error: 'Friend request already sent' });
  }

  const friendship = new Friendship({ requester: requesterId, receiver: receiverId });
  try {
    await friendship.save();
    res.status(201).send('Friend request sent');
  } catch (err) {
    res.status(400).send({ error: err.message });
  }
});

// Danh sách bạn bè
router.get('/friends/:userId', async (req, res) => {
  const userId = req.params.userId;
  try {
    const friends = await Friendship.find({
      $or: [{ requester: userId }, { receiver: userId }],
      status: 'accepted',
    })      .populate('requester', 'username') // Lấy thông tin `username` từ bảng User
    .populate('receiver', 'username');
    res.send(friends);
  } catch (err) {
    res.status(500).send({ error: 'Failed to fetch friends' });
  }
});


// Lấy danh sách bạn bè
router.get('/invitefriends/:userId', async (req, res) => {
  const { userId } = req.params;

  try {
    const friends = await Friendship.find({
      $or: [{ requester: userId }, { receiver: userId }],
      status: 'accepted',
    }).populate('requester receiver', 'username');

    const friendList = friends.map((friend) => {
      const isRequester = friend.requester._id.toString() === userId;
      const friendData = isRequester ? friend.receiver : friend.requester;
      return {
        id: friendData._id,
        username: friendData.username,
      };
    });

    res.send(friendList);
  } catch (err) {
    console.error('Error fetching friends:', err);
    res.status(500).send({ error: 'Failed to fetch friends' });
  }
});



router.post('/accept-friend', async (req, res) => {
  const { friendshipId } = req.body;
  try {
    const friendship = await Friendship.findById(friendshipId).populate('requester', 'username') // Lấy thông tin `username` từ bảng User
    .populate('receiver', 'username');;

    if (!friendship || friendship.status !== 'pending') {
      return res.status(400).send({ error: 'Friendship is not pending' });
    }

    friendship.status = 'accepted';
    await friendship.save();

    // Phát sự kiện qua socket.io để cập nhật danh sách bạn bè
    const io = req.app.get('socketio');
    io.emit('friendshipUpdated', friendship);

    res.send('Friend request accepted'+ friendship);
  } catch (err) {
    console.error('Error accepting friend request:', err);
    res.status(500).send({ error: 'Failed to accept friend request' });
  }
});

router.post('/reject-friend', async (req, res) => {
  const { friendshipId } = req.body;
  try {
    const friendship = await Friendship.findById(friendshipId);

    if (!friendship || friendship.status !== 'pending') {
      return res.status(400).send({ error: 'Friendship is not pending' });
    }

    friendship.status = 'declined';
    await friendship.save();

    // Notify through socket.io
    const io = req.app.get('socketio');
    io.emit('friendshipUpdated', friendship);

    res.send('Friend request rejected');
  } catch (err) {
    console.error('Error rejecting friend request:', err);
    res.status(500).send({ error: 'Failed to reject friend request' });
  }
});

module.exports = router;
