const mongoose = require('mongoose');

const MessageSchema = new mongoose.Schema({
  sender: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  receiver: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  message: { type: String, required: true, trim: true },
  timestamp: { type: Date, default: Date.now },
  status: { type: String, enum: ['sent', 'delivered', 'read'], default: 'sent' },
  isRecalled: { type: Boolean, default: false },
  type: { type: String, enum: ['text', 'image', 'file'], default: 'text' }, // Added 'file' to enum
  readStatus: { type: String, enum: ['unread', 'read'], default: 'unread' } // Added readStatus field
});

module.exports = mongoose.model('Message', MessageSchema);
