const fs = require('fs');
const path = require('path');
const env = require('../config/env');

/**
 * Clean up uploaded audio recordings and temporary chunk files from uploads directory
 */
const cleanupUploadedAudioFiles = () => {
  const uploadDir = env.upload.dir;
  if (!fs.existsSync(uploadDir)) {
    console.log(`[Cleanup] Upload directory does not exist: ${uploadDir}`);
    return { freedBytes: 0, deletedCount: 0 };
  }

  const files = fs.readdirSync(uploadDir);
  let freedBytes = 0;
  let deletedCount = 0;

  // Patterns for temporary audio files that should not be permanently stored
  const audioPatterns = [
    /^meeting-.*(\.m4a|\.mp3|\.wav|\.ogg|\.opus|\.flac|\.aac|\.caf)$/i,
    /.*_chunk_\d+.*$/i,
    /.*_compressed.*$/i,
    /.*_enhanced.*$/i,
  ];

  for (const file of files) {
    const isAudioFile = audioPatterns.some((pattern) => pattern.test(file));
    if (isAudioFile) {
      const fullPath = path.join(uploadDir, file);
      try {
        const stats = fs.statSync(fullPath);
        freedBytes += stats.size;
        fs.unlinkSync(fullPath);
        deletedCount++;
      } catch (err) {
        console.warn(`[Cleanup] Failed to delete ${file}:`, err.message);
      }
    }
  }

  const freedMB = (freedBytes / (1024 * 1024)).toFixed(2);
  console.log(`[Cleanup] Successfully deleted ${deletedCount} audio files. Freed ${freedMB} MB of disk space.`);
  return { freedBytes, deletedCount, freedMB };
};

if (require.main === module) {
  cleanupUploadedAudioFiles();
}

module.exports = { cleanupUploadedAudioFiles };
