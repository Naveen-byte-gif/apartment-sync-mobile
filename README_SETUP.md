# ApartmentSync Flutter App Setup Guide

## Overview
This Flutter app has been fully configured with:
- ✅ Complete folder structure
- ✅ All screens matching the designs (Login, Home, Complaints, Payments, Notices, Profile)
- ✅ Firebase integration for push notifications
- ✅ Socket.IO for real-time updates
- ✅ API service layer
- ✅ State management with Provider

## Setup Instructions

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Firebase Setup
1. Go to Firebase Console (https://console.firebase.google.com/)
2. Add your Flutter app to the project
3. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
4. Place them in:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
5. Run `flutterfire configure` to generate `firebase_options.dart`

### 3. Update API Configuration
Edit `lib/core/constants/api_constants.dart`:
- For Android Emulator: Use `http://10.0.2.2:5000/api`
- For iOS Simulator: Use `http://localhost:5000/api`
- For Physical Device: Use `http://YOUR_IP_ADDRESS:5000/api`

### 4. Run the App
```bash
flutter run
```

## Project Structure

```
lib/
├── core/
│   ├── config/          # App configuration
│   ├── constants/        # API constants, app constants
│   ├── services/        # API, Storage, Socket, Notification services
│   ├── theme/           # App colors and theme
│   └── utils/           # Utility functions
├── data/
│   ├── models/          # Data classes (not models)
│   ├── repositories/    # Data repositories
│   └── datasources/     # Data sources
└── presentation/
    ├── screens/         # All app screens
    ├── widgets/         # Reusable widgets
    ├── providers/       # State management providers
    └── routes/          # Navigation routes
```

## Screens Implemented

1. **Splash Screen** - Initial loading screen
2. **Onboarding Screen** - First-time user introduction
3. **Login Screen** - User authentication
4. **Home Screen** - Dashboard with quick actions
5. **Complaints Screen** - List and manage complaints
6. **Payments Screen** - View invoices and payments
7. **Notices Screen** - View apartment notices
8. **Profile Screen** - User profile and settings

## Features

### Real-time Updates
- Socket.IO integration for real-time notifications
- Automatic reconnection handling
- User-specific room subscriptions

### Push Notifications
- Firebase Cloud Messaging (FCM) integration
- Foreground and background message handling
- Local notifications display

### State Management
- Provider pattern for state management
- AuthProvider for authentication state
- Centralized API service

## Important Notes

1. **No Models**: As requested, we use data classes instead of models
2. **API Service**: All API calls go through `ApiService`
3. **Storage**: User data and tokens stored using `SharedPreferences`
4. **Socket Service**: Real-time updates via Socket.IO
5. **Notification Service**: Handles both FCM and local notifications

## Next Steps

1. Configure Firebase for your project
2. Update API base URL in `api_constants.dart`
3. Test login/registration flows
4. Implement remaining features as needed

