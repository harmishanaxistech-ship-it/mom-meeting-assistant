const fs = require('fs');
const app = require('./app');
const env = require('./config/env');
const { connectDB } = require('./config/db');
const { loadConfigFromFirebase } = require('./services/firebaseConfigLoader');

// Ensure upload directory exists
if (!fs.existsSync(env.upload.dir)) {
  fs.mkdirSync(env.upload.dir, { recursive: true });
}

// Start Server
const startServer = async () => {
  // Load remote API keys from Firebase Firestore before starting
  await loadConfigFromFirebase();

  await connectDB().then(() => require('./utils/seedTeam')());

  const server = app.listen(env.port, () => {
    console.log(
      `🚀 NoteAX Server running in ${env.nodeEnv} mode on port ${env.port}`
    );
  });

  // Handle unhandled promise rejections
  process.on('unhandledRejection', (err) => {
    console.error(`[UnhandledRejection Error]: ${err.message}`);
  });

  return server;
};

if (process.env.NODE_ENV !== 'test') {
  startServer();
}

module.exports = { startServer };
