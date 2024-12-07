const express = require('express');
const bcrypt = require('bcryptjs');
const User = require('../models/User');

const router = express.Router();

// Đăng ký
router.post('/register', async (req, res) => {
  const { username, password } = req.body;
  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    const user = new User({ username, password: hashedPassword });
    await user.save();
    res.status(201).send('User registered');
  } catch (err) {
    if (err.code === 11000) {
      res.status(400).send({ error: 'Username already exists' });
    } else {
      res.status(400).send({ error: err.message });
    }
  }
});


// Đăng nhập
router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  const user = await User.findOne({ username });
  if (user && (await bcrypt.compare(password, user.password))) {
    res.send({ userId: user._id, username: user.username });
  } else {
    res.status(401).send({ error: 'Invalid credentials' });
  }
});



router.post('/a', async (req, res) => {
  res.send('server run')
});

module.exports = router;
