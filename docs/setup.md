# Setup Guide — MOM Meeting Assistant

This guide explains how to set up, configure, and run the **MOM Meeting Assistant** application for both the Backend (Node.js + MongoDB) and Mobile App (Flutter).

---

## Prerequisites

- **Node.js**: v18+ (tested with v26)
- **MongoDB**: v5+ (local instance or MongoDB Atlas)
- **Flutter SDK**: v3.20+ (tested with 3.41)
- **Android Studio / Xcode**: For device emulators and mobile deployment

---

## 1. Backend Setup

### Navigate to backend directory
```bash
cd backend
```

### Install dependencies
```bash
npm install
```

### Configure environment variables
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

Review and adjust settings:
- `PORT`: Default `5001`
- `MONGODB_URI`: `mongodb://localhost:27017/mom_assistant`
- `JWT_SECRET`: Secure random string
- `STATIC_USER_EMAIL`: Default `user@momassistant.com`
- `STATIC_USER_PASSWORD`: Default `Password123!`
- `STT_PROVIDER`: `mock`
- `AI_PROVIDER`: `mock`
- `TRANSLATION_PROVIDER`: `mock`

### Run Backend Tests
```bash
npm test
```

### Start Backend Development Server
```bash
npm run dev
# or
npm start
```
Server will be active at `http://localhost:5001`.
Health check: `http://localhost:5001/api/health`.

---

## 2. Flutter Mobile Setup

### Navigate to mobile directory
```bash
cd mobile
```

### Get dependencies
```bash
flutter pub get
```

### Run Analyzer & Tests
```bash
flutter analyze
flutter test
```

### Run on Device / Simulator
```bash
flutter run
```

> **Note for Android Emulator**: Update `ApiConstants.baseUrl` in `lib/core/constants/api_constants.dart` to `http://10.0.2.2:5001/api` if testing on an Android Emulator.
