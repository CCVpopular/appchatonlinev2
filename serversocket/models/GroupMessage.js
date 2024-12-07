const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const GroupMessageSchema = new Schema({
  groupId: { type: Schema.Types.ObjectId, ref: 'Group', required: true },
  sender: { type: Schema.Types.ObjectId, ref: 'User', required: true },
  senderName: { type: String },
  message: { type: String, required: true },
  timestamp: { type: Date, default: Date.now },
  isRecalled: { type: Boolean, default: false },
});

GroupMessageSchema.pre('save', async function(next) {
  if (!this.senderName) {
    try {
      const User = mongoose.model('User');
      const user = await User.findById(this.sender);
      if (user) {
        this.senderName = user.username;
      }
    } catch (err) {
      console.error('Error populating sender name:', err);
    }
  }
  next();
});

module.exports = mongoose.model('GroupMessage', GroupMessageSchema);
