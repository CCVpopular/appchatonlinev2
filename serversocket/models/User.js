const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
  username: { type: String, unique: true, required: true, trim: true },
  password: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
  fcmToken: { type: String },
  status: { 
    type: String, 
    enum: ['online', 'offline', 'away'], 
    default: 'offline',
    required: true
  },
  lastSeen: { 
    type: Date,
    default: Date.now
  },
  avatar: { type: String, default: '' }, // URL to avatar image
  role: { type: String, enum: ['user', 'admin'], default: 'user' },
});

// Add pre-save middleware to validate status
UserSchema.pre('save', function(next) {
  if (this.status && !['online', 'offline', 'away'].includes(this.status)) {
    next(new Error('Invalid status value'));
  }
  next();
});

module.exports = mongoose.model('User', UserSchema);
