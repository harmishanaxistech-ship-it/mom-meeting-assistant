const fs = require('fs');
const app = require('./app');
const env = require('./config/env');
const { connectDB } = require('./config/db');

// Ensure upload directory exists
if (!fs.existsSync(env.upload.dir)) {
  fs.mkdirSync(env.upload.dir, { recursive: true });
}

// Start Server
const startServer = async () => {
  await connectDB();

  const server = app.listen(env.port, () => {
    console.log(
      `🚀 MOM Meeting Assistant Server running in ${env.nodeEnv} mode on port ${env.port}`
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
