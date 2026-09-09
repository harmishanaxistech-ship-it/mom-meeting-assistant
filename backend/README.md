# NoteAX — Backend API Service

AI-Powered Executive Meeting Assistant Backend (Node.js + Express + MongoDB).

## Features
- **Speech-to-Text Transcription**: Whisper STT via Groq & OpenAI.
- **AI MOM Extraction**: Agenda, Discussions, Decisions, Action Items with deadlines & priorities.
- **Corporate Excel (.xlsx) Export**: Pre-formatted multi-sheet workbook generation with live tracking formulas.
- **Master Excel Sync**: Automatically tracks all meetings in `MOM_Master_Tracker.xlsx`.
- **Multilingual Support**: English, Hindi, and Gujarati translations & short audio summaries.
- **Dual Database Toggle**: Seamless switching between Local MongoDB and MongoDB Atlas Cloud.

## Quick Start
```bash
# 1. Install dependencies
npm install

# 2. Configure Environment
cp .env.example .env
# Set USE_LOCAL_DB=true (Local) or USE_LOCAL_DB=false (Live Atlas)

# 3. Start Development Server
npm run dev
```
