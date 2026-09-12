const fs = require('fs');
const path = 'src/models/User.js';
let content = fs.readFileSync(path, 'utf8');

if (!content.includes('companyId')) {
    const injection = `
  companyId: {
    type: mongoose.Schema.ObjectId,
    ref: 'Company',
    required: false, // Set to true later when all users are migrated
  },`;
  
    content = content.replace(
      "email: {",
      injection.trim() + "\n  email: {"
    );
    fs.writeFileSync(path, content);
    console.log('Added companyId to User model');
}
