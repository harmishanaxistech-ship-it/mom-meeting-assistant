# Architecture — MOM Meeting Assistant

## 1. Overview
The MOM Meeting Assistant is designed with a clear separation of concerns between client mobile frontend and secure backend service orchestrator.

```
┌───────────────────────────────────────┐
│     Flutter Mobile App (Mobile)       │
│  - Riverpod State Management          │
│  - Dio + Secure Storage Interceptors   │
│  - Clean Feature-First Architecture   │
└──────────────────┬────────────────────┘
                   │ HTTPS / REST (JWT Auth)
                   ▼
┌───────────────────────────────────────┐
│       Node.js + Express (Backend)      │
│  - Centralized Error Handling         │
│  - JWT Middleware & Model Validation  │
│  - Multer Audio Upload Pipeline       │
└───────┬──────────────────────┬────────┘
        │                      │
        ▼                      ▼
┌────────────────┐   ┌───────────────────────────┐
│ MongoDB Server │   │ Provider Abstraction Layer│
│ - Users        │   │ - SpeechToTextProvider    │
│ - Meetings     │   │ - AIProvider (MOM Schema) │
│ - Transcripts  │   │ - TranslationProvider     │
│ - MOMs         │   └───────────────────────────┘
│ - Documents    │
│ - ProcessingJob│
└────────────────┘
```

## 2. Core Architectural Rules

1. **Provider Abstraction**: Third-party speech recognition, LLM reasoning, and translation are decoupled behind uniform interfaces (`SpeechToTextProvider`, `AIProvider`, `TranslationProvider`).
2. **Backend Security**: All third-party credentials, database credentials, and secret signing keys reside strictly on the backend.
3. **Structured MOM Schema**: MOMs are strictly typed JSON structures (compliant with Section 33).
4. **Draft-First & User Edits**: Documents are only generated from the latest user-approved MOM state.
