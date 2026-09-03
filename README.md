# MOM Meeting Assistant

An AI-powered mobile meeting assistant that records meetings, extracts transcripts with speaker timestamps, analyzes discussion items, and generates structured, multilingual Minutes of Meeting (MOM) in PDF and DOCX formats (English, Hindi, Gujarati).

## Project Structure

```text
mom-meeting-assistant/
├── mobile/            # Flutter mobile application
├── backend/           # Node.js + Express + MongoDB backend
├── docs/              # Architecture, API, and setup documentation
├── prompts/           # Specifications and master prompts
└── README.md
```

## Quick Start

### 1. Backend
```bash
cd backend
npm install
cp .env.example .env
npm run dev
```

Run tests:
```bash
npm test
```

### 2. Mobile App (Flutter)
```bash
cd mobile
flutter pub get
flutter run
```

Run tests & lint:
```bash
flutter analyze
flutter test
```

## Documentation
- [Setup Guide](file:///Users/anaxistech/Desktop/FlutterProject/MOM%20Meeting%20Assistant/mom_meeting_assistant/docs/setup.md)
- [Architecture](file:///Users/anaxistech/Desktop/FlutterProject/MOM%20Meeting%20Assistant/mom_meeting_assistant/docs/architecture.md)
- [API Reference](file:///Users/anaxistech/Desktop/FlutterProject/MOM%20Meeting%20Assistant/mom_meeting_assistant/docs/api.md)
