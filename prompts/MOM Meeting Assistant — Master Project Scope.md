# MOM Meeting Assistant — Master Project Scope

**Version:** 1.0  
**Status:** Initial MVP Scope  
**Frontend:** Flutter  
**Backend:** Node.js / Express.js  
**Database:** MongoDB  
**AI / Speech-to-Text:** Third-Party Provider — TBD  
**Authentication:** Static User — MVP

---

# 1. Project Overview

MOM Meeting Assistant is a mobile application designed to automatically create professional **Minutes of Meeting (MOM)** from physical meeting recordings.

During a physical meeting, one team member will open the Flutter application and start audio recording. The complete meeting conversation will be recorded.

After the meeting ends:

```text
Meeting Recording
       ↓
Audio Upload
       ↓
Speech-to-Text
       ↓
Speaker Identification
       ↓
AI Analysis
       ↓
MOM Draft
       ↓
User Review / Edit
       ↓
Language Selection
       ↓
PDF / DOCX Selection
       ↓
Final MOM Document
       ↓
Download / Share
```

The main objective is to minimize manual MOM preparation while still allowing the user to review and correct AI-generated content before exporting.

---

# 2. Project Objectives

The application should:

- Record physical meetings.
- Convert meeting audio into text.
- Support multilingual meetings.
- Identify different speakers where supported.
- Automatically summarize the meeting.
- Extract key discussion points.
- Identify decisions.
- Extract action items.
- Identify action-item owners.
- Extract deadlines.
- Identify risks and blockers.
- Generate a structured MOM.
- Allow the user to edit the generated MOM.
- Allow the user to select MOM output language.
- Generate MOM in English, Gujarati, or Hindi.
- Export MOM as PDF or DOCX.
- Allow the final document to be downloaded/shared.

---

# 3. Technology Stack

## 3.1 Flutter

Flutter will be used for the mobile application.

Responsibilities:

- Login
- Dashboard
- Meeting creation
- Meeting list
- Audio recording
- Recording controls
- Audio upload
- Processing status
- Transcript viewer
- MOM viewer
- MOM editor
- Language selection
- Document format selection
- Document preview
- Download
- Share

---

## 3.2 Node.js

Node.js with Express.js will be used as the backend.

Responsibilities:

- Authentication
- User management
- Meeting APIs
- Audio upload
- Audio processing
- Third-party API integration
- Speech-to-text processing
- AI/MOM generation
- Translation
- Document generation
- File management
- MongoDB communication
- Security

---

## 3.3 MongoDB

MongoDB will store application data.

Initial collections:

```text
users
meetings
transcripts
moms
documents
processing_jobs
```

Audio files should preferably be stored using separate file/object storage rather than directly inside MongoDB.

MongoDB should store:

- File reference
- File URL/path
- File size
- Duration
- MIME type
- Processing information
- Document metadata

---

# 4. Authentication — MVP

The first version will support **one static user**.

Example:

```text
Email:
admin@example.com

Password:
********
```

The credentials must be configured through backend environment variables/configuration and must not be hardcoded in Flutter.

Authentication flow:

```text
Flutter Login
      ↓
POST /api/auth/login
      ↓
Node.js
      ↓
Validate User
      ↓
JWT Token
      ↓
Flutter Dashboard
```

All protected APIs must require authentication.

### Future Authentication

The architecture should allow future support for:

- Multiple users
- Organizations
- Teams
- Admin/user roles
- Role-based permissions
- Google login
- Apple login
- Email verification

---

# 5. Meeting Languages

The meeting system must support multilingual conversations.

## Initial Languages

- English
- Hindi
- Gujarati

The system should support mixed-language conversations.

Example:

> "કાલે client ને update મોકલી દઈશું and Rahul will complete the API by Friday."

The system should process this as one meeting conversation.

---

# 6. MOM Output Languages

The MOM output language is independently selectable.

Supported:

- English
- Gujarati
- Hindi

Meeting language and MOM language do not need to be the same.

Example:

```text
Meeting:
Gujarati + English

MOM:
English
```

Or:

```text
Meeting:
English + Hindi

MOM:
Gujarati
```

The final MOM must be generated in the language selected by the user.

---

# 7. Third-Party AI / STT Provider

The final provider is **not fixed during the initial development phase**.

Possible providers may include:

- OpenAI
- Google Cloud Speech-to-Text
- Deepgram
- Azure Speech
- Other suitable providers

The final provider will be selected after testing real meeting recordings.

Testing criteria:

- English accuracy
- Hindi accuracy
- Gujarati accuracy
- Mixed-language accuracy
- Speaker identification
- Name recognition
- Date/deadline recognition
- Processing speed
- Reliability
- API cost

---

# 8. Provider Abstraction

The backend must not be tightly coupled to one provider.

Recommended architecture:

```text
Audio Processing Service
        ↓
Provider Interface
        ↓
 ┌───────────────┐
 │               │
Provider A    Provider B
 │               │
STT           STT
```

Similarly for AI:

```text
AI Service
    ↓
AI Provider Interface
    ↓
Provider A / Provider B
```

Example configuration:

```text
STT_PROVIDER=provider_name
AI_PROVIDER=provider_name
```

This allows the provider to be changed without rewriting the Flutter application or core backend logic.

---

# 9. Dashboard

Dashboard should display:

- User information
- Create Meeting button
- Recent meetings
- Meeting date
- Meeting duration
- Meeting status
- Processing status

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

# 10. Create Meeting

User can create a meeting before recording.

Fields:

- Meeting title — required
- Meeting type
- Date/time
- Location — optional
- Description — optional
- Agenda — optional
- Participants — optional

Meeting types:

- Team Meeting
- Project Review
- Client Meeting
- Planning
- General
- Custom

---

# 11. Audio Recording

This is the primary application feature.

User selects:

**Start Recording**

The application should:

- Request microphone permission.
- Start recording.
- Display recording duration.
- Display recording status.
- Support Pause.
- Support Resume.
- Support Stop.
- Handle interruptions appropriately.
- Save recording safely.

Example:

```text
Project Review

🔴 Recording

01:24:35

[ Pause ]     [ Stop ]
```

---

# 12. Recording Completion

After the user stops recording:

```text
Meeting Completed

Duration:
01:24:35

Audio:
Ready

[ Process Meeting ]
```

The user should be able to confirm before processing.

---

# 13. Audio Upload

Flutter uploads the audio to Node.js.

Requirements:

- Upload progress
- Retry support
- Network failure handling
- Large-file support
- Upload status
- Server-side validation

Example:

```text
Uploading Recording

████████████░░░ 82%

82 MB / 100 MB
```

---

# 14. Meeting Processing

After upload:

```text
Processing Meeting

✓ Audio uploaded
✓ Speech recognition
⏳ Speaker identification
⏳ AI analysis
⏳ MOM generation
```

Recommended processing statuses:

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

The Flutter application should poll or receive processing status updates from the backend.

---

# 15. Speech-to-Text

The backend sends the audio to the selected Speech-to-Text provider.

Expected output:

```text
Speaker 1:
Today we discussed the new release.

Speaker 2:
The API will be completed by Friday.

Speaker 1:
After that QA testing can start.
```

The transcript must be stored in MongoDB.

Where supported, transcript segments should include:

- Speaker
- Start timestamp
- End timestamp
- Text
- Language

Example:

```json
{
  "speaker": "Speaker 2",
  "startTime": 2538,
  "endTime": 2551,
  "text": "The API will be completed by Friday."
}
```

---

# 16. Speaker Identification

If supported by the selected provider, the application should identify different speakers.

Initial output:

```text
Speaker 1
Speaker 2
Speaker 3
```

Future enhancement:

```text
Speaker 1 → Rahul
Speaker 2 → Amit
Speaker 3 → Priya
```

The system should not invent speaker names if they cannot be reliably identified.

---

# 17. AI MOM Generation

The transcript will be analyzed by an AI model.

The AI should generate:

## 17.1 Meeting Summary

A concise summary of the complete meeting.

## 17.2 Key Discussion Points

Important topics discussed during the meeting.

## 17.3 Decisions

Decisions that were actually made.

## 17.4 Action Items

Every action item should contain:

```text
Task
Owner
Deadline
Priority
```

Example:

```text
Task:
Complete API integration

Owner:
Rahul

Deadline:
Friday

Priority:
High
```

## 17.5 Pending Items

Items that remain unresolved.

## 17.6 Risks / Blockers

Potential issues discussed during the meeting.

## 17.7 Next Steps

Required follow-up activities.

## 17.8 Next Meeting

If a future meeting date/time is discussed, extract it.

---

# 18. Structured MOM JSON

The AI should return structured data instead of directly creating the final PDF/DOCX.

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
  }
}
```

This structured data becomes the single source for:

- MOM preview
- MOM editing
- Translation
- PDF generation
- DOCX generation

---

# 19. MOM Preview

After AI generation, the application should NOT immediately finalize the document.

First display an editable MOM preview.

Example:

```text
MINUTES OF MEETING

Meeting:
Project Review

Date:
02 September 2026

Participants:
Rahul
Amit
Priya

Meeting Summary:
...

Key Discussion Points:
1. API integration
2. QA testing
3. Release timeline

Decisions:
1. API will be completed by Friday.

Action Items:

1. Complete API Integration
   Owner: Rahul
   Deadline: Friday
   Priority: High
```

Buttons:

```text
[ Edit MOM ]

[ Generate Document ]
```

---

# 20. MOM Editing

The user must be able to modify AI-generated content before export.

Editable sections:

### Meeting Details

- Meeting title
- Date
- Time
- Duration
- Location
- Participants
- Agenda

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

Editable:

- Task
- Owner
- Deadline
- Priority

Also:

- Add action item
- Delete action item
- Reorder action items

### Other Sections

Editable:

- Pending items
- Risks/blockers
- Next steps
- Next meeting
- Conclusion

---

# 21. Rich Text Editing

The MOM editor should support basic formatting:

- Bold
- Italic
- Headings
- Bullet lists
- Numbered lists
- Alignment
- Add/remove sections

Advanced editing can be added later.

---

# 22. Save MOM Changes

User can save modifications.

```text
[ Save Changes ]
```

The latest edited MOM should be stored in MongoDB.

Recommended metadata:

```text
momVersion
createdAt
updatedAt
updatedBy
```

The document must always be generated from the **latest saved MOM data**.

---

# 23. Evidence-Based MOM

To improve trust in AI-generated MOM, transcript information should be linked with important MOM items wherever possible.

Example:

```text
Action Item:
Complete API integration

Owner:
Rahul

Deadline:
Friday

Source:
00:42:18 – 00:42:31
```

When the user taps the source, the application can show the relevant transcript section.

Future enhancement:

- Jump to audio timestamp
- Play relevant audio section
- Highlight transcript

---

# 24. Language Selection

Before final document generation:

```text
Generate MOM

MOM Language

○ English
○ Gujarati
○ Hindi
```

The selected language applies to the final MOM document.

---

# 25. Language Conversion After Editing

Language conversion must use the **latest edited MOM**, not the original AI-generated MOM.

Correct flow:

```text
Transcript
   ↓
AI MOM
   ↓
User Edit
   ↓
Save Changes
   ↓
Language Selection
   ↓
Translation
   ↓
Final Document
```

Example:

```text
AI MOM:
English

User changes:
API deadline → Monday

User selects:
Gujarati

Final Gujarati MOM:
Must contain the updated Monday deadline.
```

---

# 26. Export Format Selection

The user can select:

```text
Export Format

○ PDF
○ DOCX
```

Supported formats:

- PDF
- DOCX

---

# 27. Export Screen

Final export screen:

```text
Export MOM

Language
────────────────
● English
○ Gujarati
○ Hindi

Format
────────────────
● PDF
○ DOCX

[ Generate Document ]
```

---

# 28. PDF Generation

PDF should contain:

- MOM title/header
- Meeting details
- Participants
- Agenda
- Meeting summary
- Key discussion points
- Decisions
- Action items table
- Pending items
- Risks/blockers
- Next steps
- Next meeting
- Conclusion
- Page numbers/footer

PDF must correctly render:

- English
- Hindi
- Gujarati

Proper Unicode fonts must be used.

---

# 29. DOCX Generation

DOCX should contain the same finalized content as PDF.

Requirements:

- English support
- Hindi support
- Gujarati support
- Unicode fonts
- Headings
- Tables
- Bullet lists
- Numbered lists
- Professional spacing
- Page formatting

---

# 30. Document Preview

After document generation:

```text
MOM Generated Successfully

Language:
English

Format:
PDF

[ Preview ]
[ Download ]
[ Share ]
```

The user should be able to preview the generated document before sharing.

---

# 31. Re-Generate Document

If the user edits the MOM after generating a document:

```text
Existing PDF
     ↓
Edit MOM
     ↓
Save Changes
     ↓
Generate New PDF
```

The newly generated document must always use the latest MOM version.

Same behavior applies to DOCX.

---

# 32. Meeting History

The application should maintain previous meetings.

Each meeting should display:

- Meeting title
- Date
- Duration
- Status
- Processing status

Actions:

- Open meeting
- View transcript
- View MOM
- Edit MOM
- Generate document
- Download
- Share

---

# 33. Backend API Scope

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

# 34. MongoDB Data Structure

Recommended relationships:

```text
User
 │
 └── Meetings
       │
       ├── Recording
       │
       ├── Transcript
       │
       ├── MOM
       │
       └── Documents
```

Meeting document should contain references to related data rather than storing everything in a single oversized document.

---

# 35. Error Handling

## Recording

Handle:

- Microphone permission denied
- Recording failure
- Phone interruption
- Storage failure

## Upload

Handle:

- Network failure
- Timeout
- Server error
- Large file
- Retry

## AI Processing

Handle:

- API failure
- Invalid audio
- Unsupported language
- Provider timeout
- Rate limit
- Processing failure

## Document

Handle:

- PDF generation failure
- DOCX generation failure
- File download failure
- File sharing failure

The application must show meaningful error messages.

---

# 36. Security

Even with one static user:

- Password must remain on backend.
- Password should be securely hashed/stored.
- JWT/session authentication should be used.
- Protected APIs must require authentication.
- Third-party API keys must remain on backend.
- MongoDB credentials must remain on backend.
- JWT secret must remain on backend.
- Audio files must not be publicly accessible.
- Environment variables must be used for secrets.

Flutter must never contain:

```text
STT API Key
AI API Key
MongoDB Credentials
JWT Secret
```

---

# 37. Privacy

Because the application records physical meetings, the application should provide a recording disclosure/consent mechanism.

Example:

```text
This meeting will be recorded and processed
to generate Minutes of Meeting.

[ Continue & Start Recording ]
```

The exact legal/privacy requirements should be reviewed according to the countries in which the application will operate.

---

# 38. MVP Exclusions

The following are outside the initial MVP:

- Multiple users
- Organization management
- Role-based permissions
- Google/Apple login
- Live transcription
- Automatic face recognition
- Automatic speaker-name recognition
- Calendar integration
- Email automation
- WhatsApp integration
- Task management
- Meeting analytics
- Subscription/payment system
- Advanced meeting chatbot
- Cross-meeting AI search

These can be added in future versions.

---

# 39. Future Enhancements

## V2

- Multiple users
- Teams/organizations
- Speaker name mapping
- Live transcription
- Meeting search
- Custom MOM templates
- Email sharing
- Better speaker identification

## V3

- Ask questions about meetings
- Cross-meeting search
- Action-item tracking
- Due-date reminders
- Calendar integration
- Automatic MOM distribution
- Meeting analytics
- Admin dashboard
- Multiple AI/STT providers
- Usage/cost analytics

---

# 40. Development Phases

## Phase 1 — Project Foundation

- Flutter project setup
- Node.js/Express setup
- MongoDB setup
- Static user setup
- JWT authentication
- Environment configuration
- API architecture
- Provider abstraction

## Phase 2 — Meeting Management

- Dashboard
- Create meeting
- Meeting details
- Meeting history
- Audio recording
- Recording controls
- Audio upload

## Phase 3 — AI Pipeline

- STT provider abstraction
- Initial STT provider integration
- Transcript storage
- Speaker diarization
- AI provider abstraction
- MOM generation
- Structured MOM JSON

## Phase 4 — MOM Editing

- MOM preview
- MOM editor
- Add/edit/delete sections
- Action-item editing
- Save MOM
- Language conversion

## Phase 5 — Document Generation

- PDF template
- DOCX template
- Gujarati support
- Hindi support
- English support
- Document preview
- Download
- Share
- Re-generation

## Phase 6 — Testing

Test with real:

- English meetings
- Hindi meetings
- Gujarati meetings
- English + Hindi
- English + Gujarati
- Hindi + Gujarati
- Gujarati + Hindi + English
- Multiple speakers
- Background noise
- Long meetings
- Different microphone positions

Test especially:

- Transcript accuracy
- Speaker accuracy
- Names
- Dates
- Deadlines
- Decisions
- Action items
- Translation accuracy
- PDF rendering
- DOCX rendering

---

# 41. MVP Success Criteria

The MVP will be successful when this complete workflow works reliably:

```text
LOGIN
  ↓
DASHBOARD
  ↓
CREATE MEETING
  ↓
START RECORDING
  ↓
1-HOUR PHYSICAL MEETING
  ↓
STOP RECORDING
  ↓
UPLOAD AUDIO
  ↓
PROCESS AUDIO
  ↓
TRANSCRIPT
  ↓
SPEAKER IDENTIFICATION
  ↓
AI MOM GENERATION
  ↓
MOM PREVIEW
  ↓
EDIT MOM
  ↓
SAVE CHANGES
  ↓
SELECT LANGUAGE
  ├── English
  ├── Gujarati
  └── Hindi
  ↓
SELECT FORMAT
  ├── PDF
  └── DOCX
  ↓
GENERATE DOCUMENT
  ↓
PREVIEW
  ↓
DOWNLOAD / SHARE
```

---

# 42. Core Product Principle

The application should follow four important principles:

### 1. AI Creates the First Draft

AI-generated MOM is not automatically considered final.

### 2. User Has Full Control

The user can edit any generated MOM content before export.

### 3. Language Is Independent

Meeting language and MOM output language can be different.

### 4. AI Provider Is Replaceable

The application must not be permanently dependent on one third-party AI/STT provider.

The final provider will be selected based on real-world accuracy, multilingual support, speaker identification, reliability, speed, and cost.

---

# 43. Final MVP Product Flow

```text
                    ┌─────────────────┐
                    │     Flutter     │
                    │   Mobile App    │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │    Node.js      │
                    │    Backend      │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
       ┌─────────────┐               ┌─────────────┐
       │   MongoDB   │               │ Third-Party │
       │             │               │ STT / AI    │
       └─────────────┘               └──────┬──────┘
                                            │
                                            ▼
                                      ┌─────────────┐
                                      │ Transcript  │
                                      └──────┬──────┘
                                             │
                                             ▼
                                      ┌─────────────┐
                                      │  AI MOM     │
                                      └──────┬──────┘
                                             │
                                             ▼
                                      ┌─────────────┐
                                      │ User Edit   │
                                      └──────┬──────┘
                                             │
                                      ┌──────┴──────┐
                                      ▼             ▼
                                  Language       Format
                                EN/GU/HI       PDF/DOCX
                                      │             │
                                      └──────┬──────┘
                                             ▼
                                      Final MOM
                                             │
                                      ┌──────┴──────┐
                                      ▼             ▼
                                   Download       Share
```

**This document represents the complete initial MVP scope. Any feature not mentioned above should be considered outside the MVP unless explicitly added later.**