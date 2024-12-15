const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
  username: { type: String, unique: true, required: true, trim: true },
  password: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
  fcmToken: { type: String },
  status: { type: String, enum: ['active', 'inactive'], default: 'active' },
  avatar: { type: String, default: '' }, // URL to avatar image
});

module.exports = mongoose.model('User', UserSchema);
