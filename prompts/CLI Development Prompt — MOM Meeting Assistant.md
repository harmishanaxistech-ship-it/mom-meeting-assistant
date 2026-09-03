# CLI Development Prompt — MOM Meeting Assistant

## Role

You are a senior full-stack software engineer responsible for developing the **MOM Meeting Assistant** application based on the requirements below.

You must build a production-ready MVP using:

- **Flutter** — Mobile Application
- **Node.js + Express.js** — Backend API
- **MongoDB** — Database
- **Third-party AI / Speech-to-Text API** — Provider TBD

Do not make assumptions that conflict with this specification.

---

# 1. Primary Goal

Build a mobile application that allows a user to:

1. Login.
2. Create a meeting.
3. Record a physical meeting.
4. Stop and upload the meeting recording.
5. Convert the recording into a transcript.
6. Identify speakers where supported.
7. Analyze the transcript using AI.
8. Generate a structured MOM.
9. Review the generated MOM.
10. Edit any MOM content.
11. Select the final MOM language:
    - English
    - Gujarati
    - Hindi
12. Select export format:
    - PDF
    - DOCX
13. Generate the final document.
14. Preview the document.
15. Download/share the document.
16. View previous meetings and generated MOMs.

---

# 2. Important Development Rules

Follow these rules throughout the project.

### Rule 1 — Do Not Hardcode Third-Party API

The final AI/STT provider is not yet decided.

Therefore, do NOT tightly couple the application to a specific provider.

Create provider interfaces/abstractions.

Example:

```text
SpeechToTextProvider
AIProvider
TranslationProvider
```

The actual provider implementation can be added/configured later.

---

### Rule 2 — API Keys Must Stay on Backend

Never place:

```text
AI API Key
STT API Key
MongoDB Credentials
JWT Secret
```

inside Flutter.

All third-party API communication must happen through Node.js.

---

### Rule 3 — Do Not Generate Final Documents Directly From Raw Transcript

Use this pipeline:

```text
Audio
 ↓
Transcript
 ↓
Structured MOM
 ↓
User Edit
 ↓
Final MOM
 ↓
Language Conversion
 ↓
PDF / DOCX
```

The final PDF/DOCX must always be generated from the **latest edited MOM**.

---

### Rule 4 — AI MOM Is a Draft

AI-generated MOM must never be treated as automatically final.

The user must be able to review and edit it before export.

---

### Rule 5 — Language Is Independent

The meeting language and final MOM language can be different.

Example:

```text
Meeting:
Gujarati + English

Final MOM:
English
```

or:

```text
Meeting:
Hindi + English

Final MOM:
Gujarati
```

---

### Rule 6 — Build Incrementally

Do not attempt to implement the entire project in one step.

Work in phases.

After completing each phase:

1. Check the implementation.
2. Run tests/build.
3. Fix errors.
4. Verify functionality.
5. Only then move to the next phase.

---

# 3. Project Structure

Create a clean project structure:

```text
mom-meeting-assistant/

├── mobile/
│   └── Flutter application
│
├── backend/
│   └── Node.js application
│
├── docs/
│   ├── architecture.md
│   ├── api.md
│   └── setup.md
│
├── .gitignore
├── README.md
└── docker-compose.yml
```

The exact folder names can be adjusted if required, but keep frontend and backend clearly separated.

---

# 4. Flutter Requirements

Use Flutter with a clean and scalable architecture.

Recommended structure:

```text
lib/
├── core/
│   ├── constants/
│   ├── network/
│   ├── storage/
│   ├── theme/
│   ├── utils/
│   └── widgets/
│
├── features/
│   ├── auth/
│   ├── dashboard/
│   ├── meetings/
│   ├── recording/
│   ├── transcript/
│   ├── mom/
│   └── documents/
│
└── main.dart
```

Use appropriate state management and keep business logic separate from UI.

---

# 5. Flutter Screens

Implement the following screens.

## Authentication

### Login Screen

Fields:

- Email
- Password

Actions:

- Login

Handle:

- Invalid credentials
- Network error
- Loading state

---

# 6. Dashboard

Dashboard should display:

- User information
- Create Meeting button
- Recent meetings
- Meeting status
- Meeting date
- Meeting duration

Example:

```text
My Meetings

Project Review
02 Sep 2026
01:04:35
Completed

Client Meeting
01 Sep 2026
00:52:00
Processing

+ Create Meeting
```

---

# 7. Create Meeting Screen

Fields:

- Meeting title
- Meeting type
- Date/time
- Location
- Participants
- Agenda/description

Meeting types:

```text
Team Meeting
Project Review
Client Meeting
Planning Meeting
General Meeting
Custom
```

---

# 8. Recording Screen

Implement:

- Microphone permission
- Start recording
- Pause
- Resume
- Stop
- Recording duration
- Recording status

UI example:

```text
Project Review

🔴 Recording

01:24:35

[ Pause ]     [ Stop ]
```

The recording must be stored safely before upload.

Use a reliable Flutter audio-recording package.

Do not implement custom native audio recording unless required.

---

# 9. Recording Completion

After stopping:

```text
Meeting Completed

Duration:
01:24:35

Audio:
Ready

[ Process Meeting ]
```

The user must explicitly start processing.

---

# 10. Audio Upload

Implement:

- Upload progress
- Retry
- Failure handling
- Network timeout
- Large file support
- Upload cancellation if practical

Show:

```text
Uploading Recording

████████████░░░ 82%

82 MB / 100 MB
```

---

# 11. Processing Status

Display processing stages:

```text
✓ Audio uploaded
✓ Speech recognition
⏳ Speaker identification
⏳ AI analysis
⏳ MOM generation
```

Possible backend statuses:

```text
created
recording
uploading
uploaded
transcribing
transcribed
analyzing
mom_generated
completed
failed
```

---

# 12. Transcript Screen

Display transcript with:

- Speaker
- Timestamp
- Text

Example:

```text
00:02:15

Speaker 1:
Today we discussed the new release.

00:04:21

Speaker 2:
The API will be completed by Friday.
```

If speaker identification is unavailable, use:

```text
Speaker 1
Speaker 2
Speaker 3
```

Do not invent speaker names.

---

# 13. MOM Screen

Display:

## Meeting Summary

## Agenda

## Key Discussion Points

## Decisions

## Action Items

Each action item should support:

```text
Task
Owner
Deadline
Priority
```

## Pending Items

## Risks / Blockers

## Next Steps

## Next Meeting

---

# 14. MOM Editing

The MOM must be fully editable.

The user must be able to:

### Meeting Details

- Edit title
- Edit date
- Edit time
- Edit location
- Edit participants
- Edit agenda

### Summary

- Edit summary

### Discussion Points

- Add
- Edit
- Delete
- Reorder

### Decisions

- Add
- Edit
- Delete
- Reorder

### Action Items

- Add
- Edit
- Delete
- Reorder

Editable fields:

```text
Task
Owner
Deadline
Priority
```

### Other Sections

Allow editing of:

- Pending items
- Risks/blockers
- Next steps
- Next meeting
- Conclusion

---

# 15. Rich Text Editing

Implement basic editing support:

- Bold
- Italic
- Headings
- Bullet lists
- Numbered lists
- Alignment

Do not over-engineer the editor for MVP.

---

# 16. Save MOM

Provide:

```text
Save Changes
```

The latest MOM must be persisted in MongoDB.

The application should display appropriate success/error feedback.

---

# 17. MOM Language Selection

Provide:

```text
MOM Language

○ English
○ Gujarati
○ Hindi
```

The selected language should apply to the final MOM.

The language can be different from the original meeting language.

---

# 18. Translation Flow

If the user selects a different output language, translate the **latest edited MOM**.

Correct flow:

```text
AI MOM
 ↓
User Edit
 ↓
Save
 ↓
Select Language
 ↓
Translate Latest MOM
 ↓
Generate Document
```

Never discard user modifications.

---

# 19. Export Format

Provide:

```text
Export Format

○ PDF
○ DOCX
```

---

# 20. Final Export Screen

Example:

```text
Export MOM

Language:
● English
○ Gujarati
○ Hindi

Format:
● PDF
○ DOCX

[ Generate Document ]
```

---

# 21. Document Generation

Backend must generate:

- PDF
- DOCX

Both formats must use the finalized MOM.

Document sections:

```text
MINUTES OF MEETING

Meeting Information

Participants

Agenda

Meeting Summary

Key Discussion Points

Decisions

Action Items

Pending Items

Risks / Blockers

Next Steps

Next Meeting

Conclusion
```

---

# 22. Multilingual Document Support

Generated PDF and DOCX must correctly support:

- English
- Hindi
- Gujarati

Use proper Unicode-compatible fonts.

Do not assume default fonts will correctly render Gujarati/Hindi.

Test actual generated files.

---

# 23. Document Preview

After generation:

```text
MOM Generated Successfully

[ Preview ]
[ Download ]
[ Share ]
```

The user must be able to verify the final document.

---

# 24. Re-Generate Document

If the user edits the MOM after document generation:

```text
Edit MOM
 ↓
Save
 ↓
Generate Document Again
```

The newly generated document must use the latest MOM data.

---

# 25. Meeting History

Implement meeting history.

Display:

- Meeting title
- Date
- Duration
- Status

Allow:

- View meeting
- View transcript
- View MOM
- Edit MOM
- Generate document
- Download
- Share

---

# 26. Node.js Backend

Use:

- Node.js
- Express.js
- MongoDB
- Mongoose

Keep backend modular.

Recommended:

```text
backend/
├── src/
│   ├── config/
│   ├── controllers/
│   ├── routes/
│   ├── services/
│   │   ├── speech/
│   │   ├── ai/
│   │   ├── translation/
│   │   └── document/
│   ├── models/
│   ├── middleware/
│   ├── utils/
│   └── app.js
│
├── uploads/
├── tests/
└── package.json
```

---

# 27. Authentication

Implement static-user authentication for MVP.

Credentials should come from environment configuration.

Use secure authentication such as JWT.

APIs must be protected.

Do not store plain-text passwords unnecessarily.

---

# 28. Backend API

Implement:

## Authentication

```text
POST /api/auth/login
POST /api/auth/logout
GET  /api/auth/me
```

## Meetings

```text
POST   /api/meetings
GET    /api/meetings
GET    /api/meetings/:id
PUT    /api/meetings/:id
DELETE /api/meetings/:id
```

## Recording

```text
POST /api/meetings/:id/upload
POST /api/meetings/:id/process
GET  /api/meetings/:id/processing-status
```

## Transcript

```text
GET /api/meetings/:id/transcript
```

## MOM

```text
GET  /api/meetings/:id/mom
PUT  /api/meetings/:id/mom
POST /api/meetings/:id/mom/regenerate
```

## Documents

```text
POST /api/meetings/:id/document
GET  /api/meetings/:id/document
```

---

# 29. MongoDB Models

Create models for:

```text
User
Meeting
Transcript
MOM
Document
ProcessingJob
```

Keep relationships clear.

Example:

```text
User
 ↓
Meeting
 ↓
Transcript
 ↓
MOM
 ↓
Document
```

---

# 30. Third-Party Provider Architecture

Create interfaces/abstractions.

Example:

```text
SpeechToTextProvider
```

Methods may include:

```text
transcribe(audio)
```

AI provider:

```text
AIProvider
```

Methods may include:

```text
generateMOM(transcript)
```

Translation provider:

```text
TranslationProvider
```

Methods may include:

```text
translate(mom, targetLanguage)
```

The implementation should allow different providers to be plugged in later.

---

# 31. Temporary Mock Provider

Since the final third-party provider has not yet been selected, create a mock provider for development.

Example:

```text
MockSpeechToTextProvider
MockAIProvider
MockTranslationProvider
```

This allows the Flutter and backend workflows to be developed and tested before the final provider is selected.

The mock provider must be clearly separated from production implementations.

---

# 32. Provider Configuration

Use environment variables.

Example:

```text
STT_PROVIDER=mock
AI_PROVIDER=mock
TRANSLATION_PROVIDER=mock
```

Later:

```text
STT_PROVIDER=selected_provider
AI_PROVIDER=selected_provider
TRANSLATION_PROVIDER=selected_provider
```

Do not modify core business logic when switching providers.

---

# 33. MOM JSON Structure

Use structured MOM data.

Example:

```json
{
  "meetingSummary": "",
  "agenda": [],
  "keyDiscussionPoints": [],
  "decisions": [],
  "actionItems": [
    {
      "task": "",
      "owner": "",
      "deadline": "",
      "priority": ""
    }
  ],
  "pendingItems": [],
  "risks": [],
  "nextSteps": [],
  "nextMeeting": {
    "date": "",
    "time": ""
  },
  "conclusion": ""
}
```

Validate AI output before storing it.

If AI returns invalid structure, handle the error safely.

---

# 34. AI Prompt Requirements

When generating MOM from transcript, the AI prompt should instruct the model:

- Do not invent information.
- Only use information available in the transcript.
- Clearly distinguish decisions from discussions.
- Extract actual action items.
- Do not invent owners.
- Do not invent deadlines.
- Preserve names accurately where possible.
- Handle Gujarati.
- Handle Hindi.
- Handle English.
- Handle mixed-language conversations.
- Return structured JSON.
- Keep the summary concise and professional.

If information is unavailable, return empty/null values instead of hallucinating.

---

# 35. Audio and Transcript Evidence

Where possible, store timestamps with transcript segments.

Example:

```json
{
  "speaker": "Speaker 2",
  "startTime": 2538,
  "endTime": 2551,
  "text": "The API will be completed by Friday."
}
```

MOM action items may optionally reference relevant transcript timestamps.

This can be used later for:

- Audio playback
- Transcript highlighting
- Evidence/reference
- Better user trust

---

# 36. File Storage

Do not store large audio files directly inside normal MongoDB documents.

Use a proper file/object storage approach.

For local development, a local uploads directory can be used.

For production, keep storage provider configurable.

Store metadata/reference in MongoDB.

---

# 37. Security Requirements

Implement:

- JWT authentication
- Protected APIs
- Input validation
- File type validation
- File size validation
- Secure API error responses
- Environment variables
- No API keys in Flutter
- No MongoDB credentials in Flutter
- No secrets committed to Git

Add `.env.example`.

Never commit `.env`.

---

# 38. Error Handling

Implement proper error handling for:

### Recording

- Permission denied
- Recording failure
- Storage failure

### Upload

- Network failure
- Timeout
- Invalid file
- Large file
- Server error

### Processing

- STT failure
- AI failure
- Translation failure
- Provider timeout
- Invalid AI response

### Documents

- PDF generation failure
- DOCX generation failure
- Download failure

Use meaningful user-friendly error messages.

---

# 39. Privacy

Before recording:

```text
This meeting will be recorded and processed
to generate Minutes of Meeting.

[ Continue & Start Recording ]
```

Do not expose meeting audio publicly.

Ensure authenticated access to meeting data.

---

# 40. Testing Requirements

Create tests for:

## Backend

- Authentication
- Meeting creation
- Meeting retrieval
- Upload
- Processing status
- MOM retrieval
- MOM editing
- Language conversion
- Document generation

## Flutter

Test:

- Login
- Create meeting
- Recording flow
- Upload flow
- Processing status
- MOM display
- MOM editing
- Language selection
- Format selection
- Document download/share

---

# 41. Multilingual Testing

Before considering MVP complete, test:

### English

```text
English meeting → English MOM
```

### Hindi

```text
Hindi meeting → Hindi MOM
```

### Gujarati

```text
Gujarati meeting → Gujarati MOM
```

### Mixed

```text
Gujarati + English → English MOM
```

```text
Hindi + English → Gujarati MOM
```

```text
Gujarati + Hindi + English → Hindi MOM
```

Test:

- Names
- Dates
- Numbers
- Deadlines
- Action items
- Decisions

---

# 42. Long Meeting Testing

The target meeting duration is approximately:

**1 hour per meeting**

The system must be designed to handle long recordings reliably.

Test with:

- 30-minute recording
- 60-minute recording
- Longer recording where practical

Verify:

- Upload
- Processing
- Transcript
- MOM generation
- Memory usage
- File handling
- Document generation

---

# 43. UI/UX Requirements

The UI should be:

- Clean
- Professional
- Simple
- Easy to understand
- Suitable for business users

Important actions should be clearly visible.

Processing states should always be visible.

Avoid unnecessary complexity in MVP.

---

# 44. Project Documentation

Create:

```text
README.md
docs/setup.md
docs/architecture.md
docs/api.md
docs/provider-integration.md
```

Documentation should explain:

- Project setup
- Flutter setup
- Backend setup
- MongoDB setup
- Environment variables
- Running the application
- Running tests
- Adding an AI/STT provider
- Generating documents

---

# 45. Environment Configuration

Create `.env.example`.

Example:

```text
PORT=
MONGODB_URI=
JWT_SECRET=

STT_PROVIDER=mock
AI_PROVIDER=mock
TRANSLATION_PROVIDER=mock

STT_API_KEY=
AI_API_KEY=
TRANSLATION_API_KEY=
```

Do not place real credentials in source code.

---

# 46. Development Phases

## Phase 1 — Foundation

Build:

- Repository structure
- Flutter project
- Node.js project
- MongoDB connection
- Environment configuration
- Static authentication
- JWT
- Base API structure

Verify:

- Flutter runs
- Backend runs
- MongoDB connects
- Login works

---

## Phase 2 — Meeting Management

Build:

- Dashboard
- Create meeting
- Meeting list
- Meeting details
- Meeting history

Verify all CRUD operations.

---

## Phase 3 — Recording

Build:

- Microphone permission
- Audio recording
- Pause
- Resume
- Stop
- Local recording storage
- Audio upload

Verify with real audio.

---

## Phase 4 — Processing Pipeline

Build:

- Processing job system
- Processing status
- Mock STT provider
- Mock AI provider
- Transcript storage
- MOM generation

Verify complete pipeline without a real provider.

---

## Phase 5 — MOM

Build:

- MOM viewer
- MOM editor
- Add/edit/delete
- Save changes
- Structured MOM

Verify that edits persist.

---

## Phase 6 — Language

Build:

- English
- Gujarati
- Hindi
- Translation abstraction
- Language selection

Verify that edited MOM content is preserved during translation.

---

## Phase 7 — Documents

Build:

- PDF generation
- DOCX generation
- Document preview
- Download
- Share
- Regeneration

Verify English/Hindi/Gujarati rendering.

---

## Phase 8 — Real AI Provider

Only after the complete application workflow is stable:

1. Select the best STT provider.
2. Implement provider adapter.
3. Test real recordings.
4. Select AI provider.
5. Implement AI adapter.
6. Test MOM accuracy.
7. Select translation approach.
8. Test multilingual output.
9. Compare cost and performance.

Do not redesign the application when changing providers.

---

# 47. Final MVP Acceptance Criteria

The project is complete only when the following complete workflow works:

```text
Login
 ↓
Dashboard
 ↓
Create Meeting
 ↓
Start Recording
 ↓
Record ~1 Hour Meeting
 ↓
Stop Recording
 ↓
Upload Audio
 ↓
Process Audio
 ↓
Generate Transcript
 ↓
Generate MOM
 ↓
Review MOM
 ↓
Edit MOM
 ↓
Save Changes
 ↓
Select English / Gujarati / Hindi
 ↓
Select PDF / DOCX
 ↓
Generate Document
 ↓
Preview
 ↓
Download / Share
```

All major steps must work without manually modifying the database.

---

# 48. Important Out-of-Scope Features

Do NOT implement these in MVP unless explicitly requested:

- Multiple users
- Organization management
- Admin panel
- Role-based access
- Google login
- Apple login
- Live transcription
- Automatic face recognition
- Automatic speaker-name recognition
- Calendar integration
- WhatsApp integration
- Email automation
- Task management
- Subscription/payment
- Advanced analytics
- AI chatbot
- Cross-meeting search

Keep the architecture extensible for future versions, but do not spend MVP development time implementing these features.

---

# 49. Code Quality Requirements

Write production-quality code.

Requirements:

- Clean architecture
- Reusable components
- Strong typing where applicable
- Proper validation
- Proper error handling
- No unnecessary duplication
- No hardcoded secrets
- No dead code
- No unnecessary dependencies
- Meaningful naming
- Comments only where useful
- Maintainable folder structure

Do not create placeholder implementations for features that are marked as required.

Mock providers are allowed only where the real third-party provider has not yet been finalized.

---

# 50. Final Instruction to CLI

Start development from **Phase 1**.

Do not skip phases.

For every phase:

1. Inspect the existing project.
2. Implement the required functionality.
3. Run appropriate tests.
4. Run Flutter analysis/build where applicable.
5. Run backend tests.
6. Fix all errors.
7. Verify that previous functionality still works.
8. Update documentation.
9. Provide a short summary of completed work.
10. Continue to the next phase only after the current phase is stable.

Do not ask for the third-party AI/STT provider at the beginning.

Use mock providers until the core application is complete.

The final architecture must allow the real provider to be integrated later with minimal changes.

**Priority order:**

```text
Stability
   ↓
Correct Architecture
   ↓
Core Functionality
   ↓
Multilingual Support
   ↓
MOM Accuracy
   ↓
Document Quality
   ↓
UI Polish
```

Build the application according to this specification and treat this document as the source of truth for the MVP.