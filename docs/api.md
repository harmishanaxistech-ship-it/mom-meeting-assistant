# MOM Meeting Assistant — API Documentation

This document describes the REST API endpoints provided by the Node.js + Express backend.

## Base URL
```text
http://localhost:5001/api
```

---

## 1. System & Health

### `GET /api/health`
Checks server health, environment mode, and active AI/STT/Translation provider configurations.

**Response:**
```json
{
  "success": true,
  "status": "healthy",
  "timestamp": "2026-09-02T10:15:00.000Z",
  "environment": "development",
  "providers": {
    "stt": "mock",
    "ai": "mock",
    "translation": "mock"
  }
}
```

---

## 2. Authentication

### `POST /api/auth/login`
Authenticate with email and password (static credentials in MVP or database user).

**Request Body:**
```json
{
  "email": "user@momassistant.com",
  "password": "Password123!"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsIn...",
    "user": {
      "id": "66d56...",
      "name": "Demo User",
      "email": "user@momassistant.com"
    }
  }
}
```

### `GET /api/auth/me`
Fetch current user profile using Bearer JWT token.
- **Header:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "66d56...",
      "name": "Demo User",
      "email": "user@momassistant.com"
    }
  }
}
```

### `POST /api/auth/logout`
Logout user and clear session.
- **Header:** `Authorization: Bearer <token>`

---

## 3. Planned Endpoints for Subsequent Phases

### Meetings (`/api/meetings`)
- `POST /api/meetings` — Create new meeting
- `GET /api/meetings` — List user meetings
- `GET /api/meetings/:id` — Get meeting details
- `PUT /api/meetings/:id` — Update meeting details
- `DELETE /api/meetings/:id` — Delete meeting

### Recording & Audio (`/api/meetings/:id/upload`, `/process`)
- `POST /api/meetings/:id/upload` — Multipart audio upload
- `POST /api/meetings/:id/process` — Start AI & STT pipeline
- `GET /api/meetings/:id/processing-status` — Poll processing progress

### MOM & Documents (`/api/meetings/:id/mom`, `/document`)
- `GET /api/meetings/:id/mom` — Get structured MOM
- `PUT /api/meetings/:id/mom` — Update structured MOM
- `POST /api/meetings/:id/mom/regenerate` — Re-run AI MOM generation
- `POST /api/meetings/:id/document` — Generate PDF or DOCX in target language (en, hi, gu)
- `GET /api/meetings/:id/document` — Download generated document
